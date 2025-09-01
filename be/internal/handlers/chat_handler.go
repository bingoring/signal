package handlers

import (
	"net/http"
	"strconv"

	"signal-be/internal/services"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/utils"

	"github.com/gin-gonic/gin"
)

type ChatHandler struct {
	chatService         *services.ChatService
	chatWebSocketService *services.ChatWebSocketService
	logger              *logger.Logger
}

func NewChatHandler(chatService *services.ChatService, chatWebSocketService *services.ChatWebSocketService, logger *logger.Logger) *ChatHandler {
	return &ChatHandler{
		chatService:         chatService,
		chatWebSocketService: chatWebSocketService,
		logger:              logger,
	}
}

// GetChatRooms retrieves all chat rooms for the authenticated user
func (h *ChatHandler) GetChatRooms(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		utils.ErrorResponse(c, http.StatusUnauthorized, "인증이 필요합니다", nil)
		return
	}

	rooms, err := h.chatService.GetUserChatRooms(userID)
	if err != nil {
		h.logger.Error("채팅방 목록 조회 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "채팅방 목록 조회에 실패했습니다", nil)
		return
	}

	utils.SuccessResponse(c, "채팅방 목록 조회 완료", gin.H{
		"rooms": rooms,
		"count": len(rooms),
	})
}

// GetMessages retrieves message history for a specific chat room with pagination
func (h *ChatHandler) GetMessages(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		utils.ErrorResponse(c, http.StatusUnauthorized, "인증이 필요합니다", nil)
		return
	}

	roomID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "잘못된 채팅방 ID입니다", nil)
		return
	}

	// Check if user has access to this chat room
	hasAccess, err := h.chatService.CheckRoomAccess(userID, uint(roomID))
	if err != nil {
		h.logger.Error("채팅방 접근 권한 확인 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "채팅방 접근 권한 확인에 실패했습니다", nil)
		return
	}

	if !hasAccess {
		utils.ErrorResponse(c, http.StatusForbidden, "채팅방에 접근할 권한이 없습니다", nil)
		return
	}

	// Parse pagination parameters
	page := utils.ParseIntQuery(c, "page", 1)
	limit := utils.ParseIntQuery(c, "limit", 50)
	
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 50
	}

	messages, total, err := h.chatService.GetMessages(uint(roomID), page, limit)
	if err != nil {
		h.logger.Error("메시지 조회 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "메시지 조회에 실패했습니다", nil)
		return
	}

	utils.SuccessResponse(c, "메시지 조회 완료", gin.H{
		"messages": messages,
		"pagination": gin.H{
			"page":       page,
			"limit":      limit,
			"total":      total,
			"has_more":   int64(page*limit) < total,
		},
	})
}

// SendMessage sends a new message to a chat room
func (h *ChatHandler) SendMessage(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		utils.ErrorResponse(c, http.StatusUnauthorized, "인증이 필요합니다", nil)
		return
	}

	roomID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "잘못된 채팅방 ID입니다", nil)
		return
	}

	var req models.SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "잘못된 요청 형식입니다", err)
		return
	}

	// Check if user has access to this chat room
	hasAccess, err := h.chatService.CheckRoomAccess(userID, uint(roomID))
	if err != nil {
		h.logger.Error("채팅방 접근 권한 확인 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "채팅방 접근 권한 확인에 실패했습니다", nil)
		return
	}

	if !hasAccess {
		utils.ErrorResponse(c, http.StatusForbidden, "채팅방에 접근할 권한이 없습니다", nil)
		return
	}

	message, err := h.chatService.SendMessage(uint(roomID), userID, req)
	if err != nil {
		h.logger.Error("메시지 전송 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "메시지 전송에 실패했습니다", nil)
		return
	}

	utils.SuccessResponse(c, "메시지 전송 완료", gin.H{
		"message": message,
	})
}

// CreateChatRoom creates a chat room for a signal
func (h *ChatHandler) CreateChatRoom(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		utils.ErrorResponse(c, http.StatusUnauthorized, "인증이 필요합니다", nil)
		return
	}

	signalID, err := strconv.ParseUint(c.Param("signal_id"), 10, 32)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "잘못된 시그널 ID입니다", nil)
		return
	}

	// Check if user has permission to create chat room for this signal
	canCreate, err := h.chatService.CanCreateChatRoom(userID, uint(signalID))
	if err != nil {
		h.logger.Error("채팅방 생성 권한 확인 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "채팅방 생성 권한 확인에 실패했습니다", nil)
		return
	}

	if !canCreate {
		utils.ErrorResponse(c, http.StatusForbidden, "채팅방을 생성할 권한이 없습니다", nil)
		return
	}

	room, err := h.chatService.CreateChatRoom(uint(signalID))
	if err != nil {
		h.logger.Error("채팅방 생성 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "채팅방 생성에 실패했습니다", nil)
		return
	}

	utils.SuccessResponse(c, "채팅방 생성 완료", gin.H{
		"room": room,
	})
}

// JoinChatRoom allows user to join an existing chat room
func (h *ChatHandler) JoinChatRoom(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		utils.ErrorResponse(c, http.StatusUnauthorized, "인증이 필요합니다", nil)
		return
	}

	roomID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "잘못된 채팅방 ID입니다", nil)
		return
	}

	err = h.chatService.JoinChatRoom(userID, uint(roomID))
	if err != nil {
		h.logger.Error("채팅방 참여 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "채팅방 참여에 실패했습니다", nil)
		return
	}

	utils.SuccessResponse(c, "채팅방 참여 완료", nil)
}

// HandleWebSocket upgrades HTTP connection to WebSocket for real-time chat
func (h *ChatHandler) HandleWebSocket(c *gin.Context) {
	// Delegate to ChatWebSocketService
	h.chatWebSocketService.HandleChatWebSocket(c)
}

// GetChatRoom retrieves information about a specific chat room
func (h *ChatHandler) GetChatRoom(c *gin.Context) {
	userID := c.GetUint("user_id")
	if userID == 0 {
		utils.ErrorResponse(c, http.StatusUnauthorized, "인증이 필요합니다", nil)
		return
	}

	roomID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "잘못된 채팅방 ID입니다", nil)
		return
	}

	// Check if user has access to this chat room
	hasAccess, err := h.chatService.CheckRoomAccess(userID, uint(roomID))
	if err != nil {
		h.logger.Error("채팅방 접근 권한 확인 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "채팅방 접근 권한 확인에 실패했습니다", nil)
		return
	}

	if !hasAccess {
		utils.ErrorResponse(c, http.StatusForbidden, "채팅방에 접근할 권한이 없습니다", nil)
		return
	}

	room, err := h.chatService.GetChatRoom(uint(roomID))
	if err != nil {
		h.logger.Error("채팅방 조회 실패", err)
		utils.ErrorResponse(c, http.StatusInternalServerError, "채팅방 조회에 실패했습니다", nil)
		return
	}

	// Get current participants
	participants := h.chatWebSocketService.GetRoomParticipants(room.Name)

	utils.SuccessResponse(c, "채팅방 조회 완료", gin.H{
		"room": room,
		"participants": gin.H{
			"online_count": len(participants),
			"online_users": participants,
		},
	})
}