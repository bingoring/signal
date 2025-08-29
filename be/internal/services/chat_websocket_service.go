package services

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"sync"
	"time"

	"signal-module/pkg/models"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"gorm.io/gorm"
)

var chatUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins in development
	},
}

type ChatMessage struct {
	ID        uint      `json:"id"`
	RoomID    string    `json:"room_id"`
	UserID    uint      `json:"user_id"`
	Username  string    `json:"username"`
	Content   string    `json:"content"`
	Type      string    `json:"type"` // text, image, location, system
	Timestamp time.Time `json:"timestamp"`
}

type ChatClient struct {
	UserID   uint
	Username string
	Conn     *websocket.Conn
	Send     chan *ChatMessage
	Room     *ChatRoom
}

type ChatRoom struct {
	ID           string                 `json:"id"`
	SignalID     uint                   `json:"signal_id"`
	Participants map[uint]*ChatClient   `json:"-"`
	Messages     chan *ChatMessage      `json:"-"`
	Join         chan *ChatClient       `json:"-"`
	Leave        chan *ChatClient       `json:"-"`
	Created      time.Time              `json:"created"`
	ExpiresAt    time.Time              `json:"expires_at"`
	mutex        sync.RWMutex
}

type ChatWebSocketService struct {
	db        *gorm.DB
	rooms     map[string]*ChatRoom
	roomMutex sync.RWMutex
	logger    *log.Logger
}

func NewChatWebSocketService(db *gorm.DB, logger *log.Logger) *ChatWebSocketService {
	return &ChatWebSocketService{
		db:     db,
		rooms:  make(map[string]*ChatRoom),
		logger: logger,
	}
}

// HandleChatWebSocket upgrades HTTP connection to WebSocket and manages chat
func (cws *ChatWebSocketService) HandleChatWebSocket(c *gin.Context) {
	roomID := c.Param("roomId")
	userIDStr := c.GetString("user_id")
	username := c.GetString("username")

	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil || userID == 0 || username == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Check if user has permission to join this chat room
	if !cws.canUserJoinRoom(uint(userID), roomID) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to join this chat room"})
		return
	}

	// Upgrade connection
	conn, err := chatUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		cws.logger.Printf("Failed to upgrade connection: %v", err)
		return
	}
	defer conn.Close()

	// Get or create room
	room := cws.GetOrCreateChatRoom(roomID)
	if room == nil {
		cws.logger.Printf("Failed to get room: %s", roomID)
		return
	}

	// Create client
	client := &ChatClient{
		UserID:   uint(userID),
		Username: username,
		Conn:     conn,
		Send:     make(chan *ChatMessage, 256),
		Room:     room,
	}

	// Register client
	room.Join <- client

	// Start goroutines for reading and writing
	go client.writePump()
	go client.readPump()

	// Keep connection alive until client disconnects
	select {}
}

// GetOrCreateChatRoom retrieves existing room or creates new one
func (cws *ChatWebSocketService) GetOrCreateChatRoom(roomID string) *ChatRoom {
	cws.roomMutex.RLock()
	room, exists := cws.rooms[roomID]
	cws.roomMutex.RUnlock()

	if exists {
		return room
	}

	// Create new room
	cws.roomMutex.Lock()
	defer cws.roomMutex.Unlock()

	// Double-check after acquiring write lock
	if room, exists := cws.rooms[roomID]; exists {
		return room
	}

	// Parse signal ID from room ID (format: signal_123)
	var signalID uint
	if n, err := fmt.Sscanf(roomID, "signal_%d", &signalID); n != 1 || err != nil {
		cws.logger.Printf("Invalid room ID format: %s", roomID)
		return nil
	}

	// Get signal to determine expiry
	var signal models.Signal
	if err := cws.db.First(&signal, signalID).Error; err != nil {
		cws.logger.Printf("Signal not found: %d", signalID)
		return nil
	}

	// Create room with expiry 24 hours after signal end time
	expiresAt := signal.ScheduledAt.Add(24 * time.Hour)

	room = &ChatRoom{
		ID:           roomID,
		SignalID:     signalID,
		Participants: make(map[uint]*ChatClient),
		Messages:     make(chan *ChatMessage, 256),
		Join:         make(chan *ChatClient),
		Leave:        make(chan *ChatClient),
		Created:      time.Now(),
		ExpiresAt:    expiresAt,
	}

	cws.rooms[roomID] = room

	// Start room in background
	go room.Run(cws)

	// Schedule room destruction
	go cws.scheduleRoomDestruction(roomID, expiresAt)

	cws.logger.Printf("Created chat room: %s, expires: %v", roomID, expiresAt)

	return room
}

// canUserJoinRoom checks if user has permission to join chat room
func (cws *ChatWebSocketService) canUserJoinRoom(userID uint, roomID string) bool {
	// Parse signal ID from room ID
	var signalID uint
	if n, err := fmt.Sscanf(roomID, "signal_%d", &signalID); n != 1 || err != nil {
		return false
	}

	// Check if user is creator of the signal
	var signal models.Signal
	if err := cws.db.First(&signal, signalID).Error; err != nil {
		return false
	}

	if signal.CreatorID == userID {
		return true
	}

	// Check if user is approved participant
	var participant models.SignalParticipant
	err := cws.db.Where("signal_id = ? AND user_id = ? AND status = ?", 
		signalID, userID, models.ParticipantApproved).First(&participant).Error
	
	return err == nil
}

// Run manages the chat room lifecycle
func (room *ChatRoom) Run(cws *ChatWebSocketService) {
	defer func() {
		close(room.Messages)
		close(room.Join)
		close(room.Leave)
		
		// Close all client connections
		room.mutex.Lock()
		for _, client := range room.Participants {
			close(client.Send)
		}
		room.mutex.Unlock()
	}()

	for {
		select {
		case client := <-room.Join:
			room.mutex.Lock()
			room.Participants[client.UserID] = client
			room.mutex.Unlock()

			// Send system message: user joined
			systemMsg := &ChatMessage{
				RoomID:    room.ID,
				UserID:    0,
				Username:  "시스템",
				Content:   fmt.Sprintf("%s님이 입장했습니다", client.Username),
				Type:      "system",
				Timestamp: time.Now(),
			}
			room.broadcastMessage(systemMsg, cws)

			cws.logger.Printf("User %s joined room %s", client.Username, room.ID)

		case client := <-room.Leave:
			room.mutex.Lock()
			if _, ok := room.Participants[client.UserID]; ok {
				delete(room.Participants, client.UserID)
				close(client.Send)

				// Send system message: user left
				systemMsg := &ChatMessage{
					RoomID:    room.ID,
					UserID:    0,
					Username:  "시스템",
					Content:   fmt.Sprintf("%s님이 나갔습니다", client.Username),
					Type:      "system",
					Timestamp: time.Now(),
				}
				room.mutex.Unlock()

				room.broadcastMessage(systemMsg, cws)
				cws.logger.Printf("User %s left room %s", client.Username, room.ID)
			} else {
				room.mutex.Unlock()
			}

		case message := <-room.Messages:
			// Save message to database
			room.saveMessage(message, cws)

			// Broadcast to all participants
			room.broadcastMessage(message, cws)
		}
	}
}

// broadcastMessage sends message to all participants in the room
func (room *ChatRoom) broadcastMessage(message *ChatMessage, cws *ChatWebSocketService) {
	room.mutex.RLock()
	defer room.mutex.RUnlock()

	for userID, client := range room.Participants {
		select {
		case client.Send <- message:
			// Message sent successfully
		default:
			// Client's send channel is full, remove client
			delete(room.Participants, userID)
			close(client.Send)
			cws.logger.Printf("Removed inactive client %d from room %s", userID, room.ID)
		}
	}
}

// saveMessage persists message to database
func (room *ChatRoom) saveMessage(message *ChatMessage, cws *ChatWebSocketService) {
	// Get chat room ID from database
	var dbRoom models.ChatRoom
	if err := cws.db.Where("signal_id = ?", room.SignalID).First(&dbRoom).Error; err != nil {
		cws.logger.Printf("Failed to find chat room for signal %d: %v", room.SignalID, err)
		return
	}

	var userID *uint
	if message.UserID != 0 {
		userID = &message.UserID
	}

	var msgType models.MessageType
	switch message.Type {
	case "text":
		msgType = models.MessageText
	case "image":
		msgType = models.MessageImage
	case "system":
		msgType = models.MessageSystem
	default:
		msgType = models.MessageText
	}

	dbMessage := &models.ChatMessage{
		ChatRoomID: dbRoom.ID,
		UserID:     userID,
		Content:    message.Content,
		Type:       msgType,
	}

	if err := cws.db.Create(dbMessage).Error; err != nil {
		cws.logger.Printf("Failed to save message: %v", err)
	} else {
		message.ID = dbMessage.ID
	}
}

// writePump handles sending messages to client
func (c *ChatClient) writePump() {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.Conn.WriteJSON(message); err != nil {
				return
			}

		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// readPump handles receiving messages from client
func (c *ChatClient) readPump() {
	defer func() {
		c.Room.Leave <- c
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(512)
	c.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		var msgData map[string]interface{}
		if err := c.Conn.ReadJSON(&msgData); err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		// Validate message data
		content, contentOk := msgData["content"].(string)
		msgType, typeOk := msgData["type"].(string)

		if !contentOk || !typeOk || content == "" {
			continue
		}

		// Create message
		message := &ChatMessage{
			RoomID:    c.Room.ID,
			UserID:    c.UserID,
			Username:  c.Username,
			Content:   content,
			Type:      msgType,
			Timestamp: time.Now(),
		}

		// Send to room
		select {
		case c.Room.Messages <- message:
		default:
			// Room message channel is full, skip message
		}
	}
}

// scheduleRoomDestruction schedules automatic room cleanup
func (cws *ChatWebSocketService) scheduleRoomDestruction(roomID string, expiresAt time.Time) {
	duration := time.Until(expiresAt)
	timer := time.NewTimer(duration)

	<-timer.C

	// Remove room
	cws.roomMutex.Lock()
	if room, exists := cws.rooms[roomID]; exists {
		// Close all client connections
		room.mutex.Lock()
		for _, client := range room.Participants {
			close(client.Send)
			client.Conn.Close()
		}
		room.mutex.Unlock()

		// Close room channels
		close(room.Messages)
		close(room.Join)
		close(room.Leave)

		// Delete old room data
		cws.deleteChatRoomData(roomID)
		delete(cws.rooms, roomID)

		cws.logger.Printf("Auto-destroyed chat room: %s", roomID)
	}
	cws.roomMutex.Unlock()
}

// deleteChatRoomData removes old messages from database
func (cws *ChatWebSocketService) deleteChatRoomData(roomID string) {
	cutoff := time.Now().Add(-24 * time.Hour)
	result := cws.db.Where("room_id = ? AND created_at < ?", roomID, cutoff).Delete(&models.ChatMessage{})
	
	if result.Error != nil {
		cws.logger.Printf("Failed to cleanup messages for room %s: %v", roomID, result.Error)
	} else {
		cws.logger.Printf("Cleaned up %d old messages for room %s", result.RowsAffected, roomID)
	}
}

// GetRoomMessages retrieves message history for a room
func (cws *ChatWebSocketService) GetRoomMessages(roomID string, limit int, offset int) ([]models.ChatMessage, error) {
	var messages []models.ChatMessage

	err := cws.db.Where("room_id = ?", roomID).
		Order("created_at ASC").
		Limit(limit).
		Offset(offset).
		Find(&messages).Error

	return messages, err
}

// GetActiveRooms returns list of currently active chat rooms
func (cws *ChatWebSocketService) GetActiveRooms() map[string]*ChatRoom {
	cws.roomMutex.RLock()
	defer cws.roomMutex.RUnlock()

	rooms := make(map[string]*ChatRoom)
	for id, room := range cws.rooms {
		rooms[id] = room
	}

	return rooms
}

// GetRoomParticipants returns current participants in a room
func (cws *ChatWebSocketService) GetRoomParticipants(roomID string) []uint {
	cws.roomMutex.RLock()
	room, exists := cws.rooms[roomID]
	cws.roomMutex.RUnlock()

	if !exists {
		return []uint{}
	}

	room.mutex.RLock()
	defer room.mutex.RUnlock()

	participants := make([]uint, 0, len(room.Participants))
	for userID := range room.Participants {
		participants = append(participants, userID)
	}

	return participants
}

// CleanupExpiredMessages removes old messages from database
func (cws *ChatWebSocketService) CleanupExpiredMessages() error {
	cutoff := time.Now().Add(-24 * time.Hour)
	
	result := cws.db.Where("created_at < ?", cutoff).Delete(&models.ChatMessage{})
	
	if result.Error != nil {
		cws.logger.Printf("Failed to cleanup expired messages: %v", result.Error)
		return result.Error
	}
	
	cws.logger.Printf("Cleaned up %d expired messages", result.RowsAffected)
	return nil
}