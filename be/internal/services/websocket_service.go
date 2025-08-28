package services

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/redis"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

type WebSocketService struct {
	logger      *logger.Logger
	redisClient *redis.Client
	
	// 연결된 클라이언트들을 위치별로 관리
	locationClients map[string][]*SignalClient
	mutex          sync.RWMutex
	
	upgrader websocket.Upgrader
}

type SignalClient struct {
	ID       string
	UserID   uint
	Conn     *websocket.Conn
	Location LocationBounds
	Send     chan []byte
}

type LocationBounds struct {
	MinLat float64
	MaxLat float64
	MinLon float64
	MaxLon float64
}

type SignalUpdate struct {
	Type    string                   `json:"type"`
	Signal  *models.SignalWithDistance `json:"signal,omitempty"`
	Message string                   `json:"message,omitempty"`
}

func NewWebSocketService(logger *logger.Logger, redisClient *redis.Client) *WebSocketService {
	return &WebSocketService{
		logger:          logger,
		redisClient:     redisClient,
		locationClients: make(map[string][]*SignalClient),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
	}
}

// HandleSignalWebSocket handles WebSocket connections for real-time signal updates
func (ws *WebSocketService) HandleSignalWebSocket(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	conn, err := ws.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		ws.logger.Error("WebSocket 업그레이드 실패", err)
		return
	}

	client := &SignalClient{
		ID:     fmt.Sprintf("user_%d_%d", userID, time.Now().UnixNano()),
		UserID: userID,
		Conn:   conn,
		Send:   make(chan []byte, 256),
	}

	ws.logger.Info(fmt.Sprintf("WebSocket 연결: 사용자 %d", userID))

	// 클라이언트 핸들러 시작
	go ws.handleClient(client)
	go ws.writeHandler(client)
}

// handleClient handles incoming messages from client
func (ws *WebSocketService) handleClient(client *SignalClient) {
	defer func() {
		ws.removeClient(client)
		client.Conn.Close()
	}()

	client.Conn.SetReadLimit(512)
	client.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	client.Conn.SetPongHandler(func(string) error {
		client.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		var msg map[string]interface{}
		err := client.Conn.ReadJSON(&msg)
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				ws.logger.Error("WebSocket 읽기 오류", err)
			}
			break
		}

		// 위치 업데이트 처리
		if msgType, ok := msg["type"].(string); ok && msgType == "location_update" {
			ws.handleLocationUpdate(client, msg)
		}
	}
}

// writeHandler handles outgoing messages to client
func (ws *WebSocketService) writeHandler(client *SignalClient) {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		client.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-client.Send:
			client.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				client.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := client.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			client.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := client.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// handleLocationUpdate handles location updates from client
func (ws *WebSocketService) handleLocationUpdate(client *SignalClient, msg map[string]interface{}) {
	lat, latOK := msg["latitude"].(float64)
	lon, lonOK := msg["longitude"].(float64)
	radius, radiusOK := msg["radius"].(float64)

	if !latOK || !lonOK || !radiusOK {
		ws.logger.Error("잘못된 위치 업데이트 메시지", nil)
		return
	}

	// 위치 경계 계산 (대략적인 lat/lon 변환)
	latDelta := radius / 111320.0 // 1도 = 약 111.32km
	lonDelta := radius / (111320.0 * 0.866) // 보정 계수

	client.Location = LocationBounds{
		MinLat: lat - latDelta,
		MaxLat: lat + latDelta,
		MinLon: lon - lonDelta,
		MaxLon: lon + lonDelta,
	}

	// 위치별 클라이언트 그룹에 추가
	locationKey := ws.getLocationKey(lat, lon)
	ws.addClientToLocation(client, locationKey)

	ws.logger.Info(fmt.Sprintf("사용자 %d 위치 업데이트: %.6f, %.6f (반경: %.0fm)", client.UserID, lat, lon, radius))
}

// BroadcastSignalUpdate broadcasts signal updates to relevant clients
func (ws *WebSocketService) BroadcastSignalUpdate(signal *models.SignalWithDistance, updateType string) {
	update := SignalUpdate{
		Type:   updateType,
		Signal: signal,
	}

	data, err := json.Marshal(update)
	if err != nil {
		ws.logger.Error("SignalUpdate JSON 마샬링 실패", err)
		return
	}

	ws.mutex.RLock()
	defer ws.mutex.RUnlock()

	// 모든 위치 그룹에서 해당 시그널과 관련된 클라이언트들에게 브로드캐스트
	for _, clients := range ws.locationClients {
		for _, client := range clients {
			if ws.isSignalInBounds(signal.Signal, client.Location) {
				select {
				case client.Send <- data:
				default:
					// 채널이 막혀있으면 클라이언트 제거
					ws.removeClient(client)
				}
			}
		}
	}

	ws.logger.Info(fmt.Sprintf("시그널 업데이트 브로드캐스트: %s (ID: %d)", updateType, signal.Signal.ID))
}

// Helper methods
func (ws *WebSocketService) getLocationKey(lat, lon float64) string {
	// 위치를 그리드로 반올림하여 키 생성 (1km 그리드)
	gridLat := int(lat * 100) // 0.01도 = 약 1km
	gridLon := int(lon * 100)
	return fmt.Sprintf("grid_%d_%d", gridLat, gridLon)
}

func (ws *WebSocketService) addClientToLocation(client *SignalClient, locationKey string) {
	ws.mutex.Lock()
	defer ws.mutex.Unlock()

	// 기존 위치에서 제거
	ws.removeClientFromAllLocations(client)

	// 새 위치에 추가
	ws.locationClients[locationKey] = append(ws.locationClients[locationKey], client)
}

func (ws *WebSocketService) removeClient(client *SignalClient) {
	ws.mutex.Lock()
	defer ws.mutex.Unlock()

	ws.removeClientFromAllLocations(client)
	close(client.Send)
}

func (ws *WebSocketService) removeClientFromAllLocations(client *SignalClient) {
	for locationKey, clients := range ws.locationClients {
		for i, c := range clients {
			if c.ID == client.ID {
				ws.locationClients[locationKey] = append(clients[:i], clients[i+1:]...)
				break
			}
		}
		// 빈 위치 그룹 정리
		if len(ws.locationClients[locationKey]) == 0 {
			delete(ws.locationClients, locationKey)
		}
	}
}

func (ws *WebSocketService) isSignalInBounds(signal models.Signal, bounds LocationBounds) bool {
	return signal.Latitude >= bounds.MinLat && signal.Latitude <= bounds.MaxLat &&
		   signal.Longitude >= bounds.MinLon && signal.Longitude <= bounds.MaxLon
}