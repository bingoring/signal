package handlers

import (
	"signal-module/pkg/logger"
	"signal-module/pkg/utils"

	"github.com/gin-gonic/gin"
)

type ChatHandler struct {
	chatService      interface{}
	websocketService interface{}
	logger           *logger.Logger
}

func NewChatHandler(chatService, websocketService interface{}, logger *logger.Logger) *ChatHandler {
	return &ChatHandler{
		chatService:      chatService,
		websocketService: websocketService,
		logger:           logger,
	}
}

func (h *ChatHandler) GetChatRooms(c *gin.Context) {
	utils.SuccessResponse(c, "채팅방 목록 조회 완료", nil)
}

func (h *ChatHandler) GetMessages(c *gin.Context) {
	utils.SuccessResponse(c, "메시지 조회 완료", nil)
}

func (h *ChatHandler) SendMessage(c *gin.Context) {
	utils.SuccessResponse(c, "메시지 전송 완료", nil)
}

func (h *ChatHandler) HandleWebSocket(c *gin.Context) {
	utils.SuccessResponse(c, "WebSocket 연결", nil)
}