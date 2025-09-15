package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"signal-module/pkg/models"
	"signal-module/pkg/redis"

	"github.com/go-redis/redis/v8"
	"github.com/gorilla/websocket"
)

// ChatPerformanceOptimizer provides enhanced performance features for chat system
type ChatPerformanceOptimizer struct {
	// Connection management
	globalConnections map[string]*OptimizedClient // userId -> Client
	roomSubscriptions map[string][]string         // roomId -> []userId
	connectionMutex   sync.RWMutex

	// Message batching
	messageBatchQueue chan *MessageBatch
	batchSize        int
	batchInterval    time.Duration

	// Redis caching
	redisClient *redis.Client
	
	// Metrics
	metrics *ChatMetrics

	// Background workers
	ctx    context.Context
	cancel context.CancelFunc
}

type OptimizedClient struct {
	UserID    uint
	Username  string
	Conn      *websocket.Conn
	Send      chan []byte
	LastSeen  time.Time
	RoomIDs   map[string]bool // rooms this client is subscribed to
	IsActive  bool
}

type MessageBatch struct {
	RoomID    string
	Messages  []*ChatMessage
	Timestamp time.Time
}

type ChatMetrics struct {
	mu                   sync.RWMutex
	TotalConnections     int64     `json:"total_connections"`
	ActiveRooms         int64     `json:"active_rooms"`
	MessagesPerMinute   int64     `json:"messages_per_minute"`
	AverageLatency      float64   `json:"average_latency_ms"`
	MemoryUsageMB       int64     `json:"memory_usage_mb"`
	LastUpdate          time.Time `json:"last_update"`
}

type BroadcastMessage struct {
	RoomID  string
	Data    []byte
	UserIDs []string // specific users to send to (empty = all in room)
}

// NewChatPerformanceOptimizer creates a new performance optimizer
func NewChatPerformanceOptimizer(redisClient *redis.Client) *ChatPerformanceOptimizer {
	ctx, cancel := context.WithCancel(context.Background())
	
	optimizer := &ChatPerformanceOptimizer{
		globalConnections: make(map[string]*OptimizedClient),
		roomSubscriptions: make(map[string][]string),
		messageBatchQueue: make(chan *MessageBatch, 1000),
		batchSize:        10,
		batchInterval:    100 * time.Millisecond,
		redisClient:      redisClient,
		metrics:          &ChatMetrics{LastUpdate: time.Now()},
		ctx:              ctx,
		cancel:           cancel,
	}

	// Start background workers
	go optimizer.batchProcessor()
	go optimizer.metricsCollector()
	go optimizer.connectionHealthChecker()

	return optimizer
}

// RegisterConnection registers a new WebSocket connection
func (cpo *ChatPerformanceOptimizer) RegisterConnection(userID uint, username string, conn *websocket.Conn) *OptimizedClient {
	cpo.connectionMutex.Lock()
	defer cpo.connectionMutex.Unlock()

	userKey := fmt.Sprintf("user_%d", userID)

	// Close existing connection if any
	if existingClient, exists := cpo.globalConnections[userKey]; exists {
		existingClient.IsActive = false
		existingClient.Conn.Close()
		log.Printf("Closed existing connection for user %d", userID)
	}

	client := &OptimizedClient{
		UserID:   userID,
		Username: username,
		Conn:     conn,
		Send:     make(chan []byte, 256),
		LastSeen: time.Now(),
		RoomIDs:  make(map[string]bool),
		IsActive: true,
	}

	cpo.globalConnections[userKey] = client
	cpo.metrics.mu.Lock()
	cpo.metrics.TotalConnections++
	cpo.metrics.mu.Unlock()

	log.Printf("Registered optimized connection for user %d (%s)", userID, username)
	return client
}

// SubscribeToRoom subscribes a user to a chat room
func (cpo *ChatPerformanceOptimizer) SubscribeToRoom(userID uint, roomID string) {
	cpo.connectionMutex.Lock()
	defer cpo.connectionMutex.Unlock()

	userKey := fmt.Sprintf("user_%d", userID)
	client, exists := cpo.globalConnections[userKey]
	if !exists {
		return
	}

	// Add room to client's subscriptions
	client.RoomIDs[roomID] = true

	// Add user to room's subscription list
	if _, exists := cpo.roomSubscriptions[roomID]; !exists {
		cpo.roomSubscriptions[roomID] = make([]string, 0)
		cpo.metrics.mu.Lock()
		cpo.metrics.ActiveRooms++
		cpo.metrics.mu.Unlock()
	}

	// Check if user already in room
	for _, existingUserKey := range cpo.roomSubscriptions[roomID] {
		if existingUserKey == userKey {
			return // already subscribed
		}
	}

	cpo.roomSubscriptions[roomID] = append(cpo.roomSubscriptions[roomID], userKey)
	log.Printf("User %d subscribed to room %s", userID, roomID)
}

// UnsubscribeFromRoom unsubscribes a user from a chat room
func (cpo *ChatPerformanceOptimizer) UnsubscribeFromRoom(userID uint, roomID string) {
	cpo.connectionMutex.Lock()
	defer cpo.connectionMutex.Unlock()

	userKey := fmt.Sprintf("user_%d", userID)
	client, exists := cpo.globalConnections[userKey]
	if exists {
		delete(client.RoomIDs, roomID)
	}

	// Remove user from room subscription list
	if users, exists := cpo.roomSubscriptions[roomID]; exists {
		for i, existingUserKey := range users {
			if existingUserKey == userKey {
				cpo.roomSubscriptions[roomID] = append(users[:i], users[i+1:]...)
				break
			}
		}

		// Clean up empty room
		if len(cpo.roomSubscriptions[roomID]) == 0 {
			delete(cpo.roomSubscriptions, roomID)
			cpo.metrics.mu.Lock()
			cpo.metrics.ActiveRooms--
			cpo.metrics.mu.Unlock()
		}
	}

	log.Printf("User %d unsubscribed from room %s", userID, roomID)
}

// DisconnectUser removes a user connection
func (cpo *ChatPerformanceOptimizer) DisconnectUser(userID uint) {
	cpo.connectionMutex.Lock()
	defer cpo.connectionMutex.Unlock()

	userKey := fmt.Sprintf("user_%d", userID)
	client, exists := cpo.globalConnections[userKey]
	if !exists {
		return
	}

	client.IsActive = false
	close(client.Send)

	// Remove from all room subscriptions
	for roomID := range client.RoomIDs {
		cpo.removeUserFromRoomSubscription(userKey, roomID)
	}

	delete(cpo.globalConnections, userKey)
	cpo.metrics.mu.Lock()
	cpo.metrics.TotalConnections--
	cpo.metrics.mu.Unlock()

	log.Printf("Disconnected user %d", userID)
}

// BroadcastToRoom sends message to all users in a room (optimized)
func (cpo *ChatPerformanceOptimizer) BroadcastToRoom(roomID string, message *ChatMessage) {
	// Convert to JSON once
	data, err := json.Marshal(message)
	if err != nil {
		log.Printf("Failed to marshal message: %v", err)
		return
	}

	cpo.connectionMutex.RLock()
	userKeys, exists := cpo.roomSubscriptions[roomID]
	cpo.connectionMutex.RUnlock()

	if !exists {
		return
	}

	// Create broadcast message
	broadcastMsg := &BroadcastMessage{
		RoomID: roomID,
		Data:   data,
	}

	// Send to all room participants
	successCount := 0
	for _, userKey := range userKeys {
		if cpo.sendToUser(userKey, broadcastMsg.Data) {
			successCount++
		}
	}

	// Update metrics
	cpo.metrics.mu.Lock()
	cpo.metrics.MessagesPerMinute++
	cpo.metrics.mu.Unlock()

	log.Printf("Broadcasted message to %d/%d users in room %s", successCount, len(userKeys), roomID)
}

// sendToUser sends data to a specific user (internal method)
func (cpo *ChatPerformanceOptimizer) sendToUser(userKey string, data []byte) bool {
	cpo.connectionMutex.RLock()
	client, exists := cpo.globalConnections[userKey]
	cpo.connectionMutex.RUnlock()

	if !exists || !client.IsActive {
		return false
	}

	client.LastSeen = time.Now()

	select {
	case client.Send <- data:
		return true
	default:
		// Channel is full, mark as inactive
		log.Printf("Client %s send channel full, marking inactive", userKey)
		client.IsActive = false
		return false
	}
}

// AddMessageToBatch adds message to batch queue for processing
func (cpo *ChatPerformanceOptimizer) AddMessageToBatch(roomID string, message *ChatMessage) {
	// Try to add to existing batch or create new one
	select {
	case cpo.messageBatchQueue <- &MessageBatch{
		RoomID:    roomID,
		Messages:  []*ChatMessage{message},
		Timestamp: time.Now(),
	}:
	default:
		log.Printf("Message batch queue full, dropping message for room %s", roomID)
	}
}

// batchProcessor processes messages in batches for better performance
func (cpo *ChatPerformanceOptimizer) batchProcessor() {
	ticker := time.NewTicker(cpo.batchInterval)
	defer ticker.Stop()

	batches := make(map[string]*MessageBatch)

	for {
		select {
		case <-cpo.ctx.Done():
			return

		case batch := <-cpo.messageBatchQueue:
			// Accumulate messages by room
			if existingBatch, exists := batches[batch.RoomID]; exists {
				existingBatch.Messages = append(existingBatch.Messages, batch.Messages...)
			} else {
				batches[batch.RoomID] = batch
			}

			// Check if batch is ready for processing
			if len(batches[batch.RoomID].Messages) >= cpo.batchSize {
				cpo.processBatch(batches[batch.RoomID])
				delete(batches, batch.RoomID)
			}

		case <-ticker.C:
			// Process all accumulated batches
			for roomID, batch := range batches {
				cpo.processBatch(batch)
				delete(batches, roomID)
			}
		}
	}
}

// processBatch processes a batch of messages
func (cpo *ChatPerformanceOptimizer) processBatch(batch *MessageBatch) {
	for _, message := range batch.Messages {
		cpo.BroadcastToRoom(batch.RoomID, message)
	}
	log.Printf("Processed batch of %d messages for room %s", len(batch.Messages), batch.RoomID)
}

// metricsCollector collects performance metrics
func (cpo *ChatPerformanceOptimizer) metricsCollector() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-cpo.ctx.Done():
			return
		case <-ticker.C:
			cpo.collectMetrics()
		}
	}
}

// collectMetrics updates performance metrics
func (cpo *ChatPerformanceOptimizer) collectMetrics() {
	cpo.metrics.mu.Lock()
	defer cpo.metrics.mu.Unlock()

	cpo.connectionMutex.RLock()
	activeConnections := int64(len(cpo.globalConnections))
	activeRooms := int64(len(cpo.roomSubscriptions))
	cpo.connectionMutex.RUnlock()

	cpo.metrics.TotalConnections = activeConnections
	cpo.metrics.ActiveRooms = activeRooms
	cpo.metrics.LastUpdate = time.Now()

	// Reset per-minute counters
	cpo.metrics.MessagesPerMinute = 0

	log.Printf("Metrics - Connections: %d, Rooms: %d", activeConnections, activeRooms)
}

// connectionHealthChecker removes inactive connections
func (cpo *ChatPerformanceOptimizer) connectionHealthChecker() {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-cpo.ctx.Done():
			return
		case <-ticker.C:
			cpo.cleanupInactiveConnections()
		}
	}
}

// cleanupInactiveConnections removes connections that haven't been seen recently
func (cpo *ChatPerformanceOptimizer) cleanupInactiveConnections() {
	cpo.connectionMutex.Lock()
	defer cpo.connectionMutex.Unlock()

	cutoff := time.Now().Add(-5 * time.Minute)
	inactiveUsers := make([]string, 0)

	for userKey, client := range cpo.globalConnections {
		if !client.IsActive || client.LastSeen.Before(cutoff) {
			inactiveUsers = append(inactiveUsers, userKey)
		}
	}

	for _, userKey := range inactiveUsers {
		client := cpo.globalConnections[userKey]
		
		// Remove from room subscriptions
		for roomID := range client.RoomIDs {
			cpo.removeUserFromRoomSubscription(userKey, roomID)
		}

		// Close connection and cleanup
		if client.IsActive {
			close(client.Send)
		}
		delete(cpo.globalConnections, userKey)
	}

	if len(inactiveUsers) > 0 {
		log.Printf("Cleaned up %d inactive connections", len(inactiveUsers))
	}
}

// removeUserFromRoomSubscription helper method
func (cpo *ChatPerformanceOptimizer) removeUserFromRoomSubscription(userKey, roomID string) {
	if users, exists := cpo.roomSubscriptions[roomID]; exists {
		for i, existingUserKey := range users {
			if existingUserKey == userKey {
				cpo.roomSubscriptions[roomID] = append(users[:i], users[i+1:]...)
				break
			}
		}

		// Clean up empty room
		if len(cpo.roomSubscriptions[roomID]) == 0 {
			delete(cpo.roomSubscriptions, roomID)
		}
	}
}

// GetMetrics returns current performance metrics
func (cpo *ChatPerformanceOptimizer) GetMetrics() *ChatMetrics {
	cpo.metrics.mu.RLock()
	defer cpo.metrics.mu.RUnlock()

	// Return a copy to avoid race conditions
	return &ChatMetrics{
		TotalConnections:  cpo.metrics.TotalConnections,
		ActiveRooms:      cpo.metrics.ActiveRooms,
		MessagesPerMinute: cpo.metrics.MessagesPerMinute,
		AverageLatency:   cpo.metrics.AverageLatency,
		MemoryUsageMB:    cpo.metrics.MemoryUsageMB,
		LastUpdate:       cpo.metrics.LastUpdate,
	}
}

// GetActiveConnections returns the count of active connections
func (cpo *ChatPerformanceOptimizer) GetActiveConnections() int {
	cpo.connectionMutex.RLock()
	defer cpo.connectionMutex.RUnlock()
	return len(cpo.globalConnections)
}

// GetActiveRoomsCount returns the count of active rooms
func (cpo *ChatPerformanceOptimizer) GetActiveRoomsCount() int {
	cpo.connectionMutex.RLock()
	defer cpo.connectionMutex.RUnlock()
	return len(cpo.roomSubscriptions)
}

// CacheMessage caches message in Redis for history
func (cpo *ChatPerformanceOptimizer) CacheMessage(roomID string, message *ChatMessage) error {
	key := fmt.Sprintf("chat:room:%s:messages", roomID)
	
	data, err := json.Marshal(message)
	if err != nil {
		return err
	}

	// Use Redis for simple caching instead of streams for now
	return cpo.redisClient.Set(context.Background(), key, string(data), 24*time.Hour).Err()
}

// GetCachedMessages retrieves cached messages from Redis
func (cpo *ChatPerformanceOptimizer) GetCachedMessages(roomID string, count int64) ([]*ChatMessage, error) {
	key := fmt.Sprintf("chat:room:%s:messages", roomID)
	
	result := cpo.redisClient.Get(context.Background(), key)
	if result.Err() != nil {
		return nil, result.Err()
	}

	var message ChatMessage
	if err := json.Unmarshal([]byte(result.Val()), &message); err != nil {
		return nil, err
	}

	// For simplicity, return single cached message
	// In production, you'd implement proper message history with Redis Lists or Streams
	return []*ChatMessage{&message}, nil
}

// Shutdown gracefully shuts down the optimizer
func (cpo *ChatPerformanceOptimizer) Shutdown() {
	log.Println("Shutting down ChatPerformanceOptimizer...")
	
	cpo.cancel()
	
	// Close all connections
	cpo.connectionMutex.Lock()
	for userKey, client := range cpo.globalConnections {
		if client.IsActive {
			close(client.Send)
			client.Conn.Close()
		}
		delete(cpo.globalConnections, userKey)
	}
	cpo.connectionMutex.Unlock()

	log.Println("ChatPerformanceOptimizer shutdown complete")
}