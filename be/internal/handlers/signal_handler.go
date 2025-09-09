package handlers

import (
	"fmt"
	"strconv"
	"strings"

	"signal-be/internal/services"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/utils"

	"github.com/gin-gonic/gin"
)

type SignalHandler struct {
	signalService services.SignalServiceInterface
	logger        *logger.Logger
}

func NewSignalHandler(signalService services.SignalServiceInterface, logger *logger.Logger) *SignalHandler {
	return &SignalHandler{
		signalService: signalService,
		logger:        logger,
	}
}

func (h *SignalHandler) CreateSignal(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req models.CreateSignalRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	signal, err := h.signalService.CreateSignal(userID, &req)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.CreatedResponse(c, "시그널이 생성되었습니다", signal)
}

func (h *SignalHandler) GetSignal(c *gin.Context) {
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	signal, err := h.signalService.GetSignal(uint(signalID))
	if err != nil {
		utils.NotFoundResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "시그널 조회 완료", signal)
}

func (h *SignalHandler) SearchSignals(c *gin.Context) {
	var req models.SearchSignalRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 검색 조건입니다")
		return
	}

	signals, pagination, err := h.signalService.SearchSignals(&req)
	if err != nil {
		utils.InternalServerErrorResponse(c, "시그널 검색에 실패했습니다", err)
		return
	}

	utils.PagedSuccessResponse(c, "시그널 검색 완료", signals, *pagination)
}

func (h *SignalHandler) GetMySignals(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	signals, pagination, err := h.signalService.GetMySignals(userID, page, limit)
	if err != nil {
		utils.InternalServerErrorResponse(c, "시그널 조회에 실패했습니다", err)
		return
	}

	utils.PagedSuccessResponse(c, "내 시그널 조회 완료", signals, *pagination)
}

func (h *SignalHandler) JoinSignal(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	var req models.JoinSignalRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.signalService.JoinSignal(uint(signalID), userID, &req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "시그널 참여 요청이 완료되었습니다", nil)
}

func (h *SignalHandler) LeaveSignal(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	if err := h.signalService.LeaveSignal(uint(signalID), userID); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "시그널에서 나갔습니다", nil)
}

func (h *SignalHandler) ApproveParticipant(c *gin.Context) {
	creatorID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	participantID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 사용자 ID입니다")
		return
	}

	if err := h.signalService.ApproveParticipant(uint(signalID), creatorID, uint(participantID)); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "참여자를 승인했습니다", nil)
}

func (h *SignalHandler) RejectParticipant(c *gin.Context) {
	creatorID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	participantID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 사용자 ID입니다")
		return
	}

	if err := h.signalService.RejectParticipant(uint(signalID), creatorID, uint(participantID)); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "참여자를 거절했습니다", nil)
}

// GetNearbySignals 근처 시그널들을 실시간으로 조회
func (h *SignalHandler) GetNearbySignals(c *gin.Context) {
	// 쿼리 파라미터에서 위치 정보 받기
	latStr := c.Query("lat")
	lonStr := c.Query("lon")
	radiusStr := c.DefaultQuery("radius", "5000")
	categoriesStr := c.Query("categories")

	if latStr == "" || lonStr == "" {
		utils.BadRequestResponse(c, "위치 정보(lat, lon)가 필요합니다")
		return
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 위도입니다")
		return
	}

	lon, err := strconv.ParseFloat(lonStr, 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 경도입니다")
		return
	}

	radius, err := strconv.ParseFloat(radiusStr, 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 반경입니다")
		return
	}

	// 카테고리 필터링 (선택사항)
	var categories []models.InterestCategory
	if categoriesStr != "" {
		categoryStrs := strings.Split(categoriesStr, ",")
		for _, catStr := range categoryStrs {
			categories = append(categories, models.InterestCategory(strings.TrimSpace(catStr)))
		}
	}

	// 서비스 호출
	signals, err := h.signalService.GetNearbySignals(lat, lon, radius, categories)
	if err != nil {
		h.logger.Error("근처 시그널 조회 실패", err)
		utils.InternalServerErrorResponse(c, "근처 시그널 조회에 실패했습니다", err)
		return
	}

	h.logger.Info(fmt.Sprintf("근처 시그널 조회 성공: %d개", len(signals)))

	utils.SuccessResponse(c, "근처 시그널 조회 완료", gin.H{
		"signals": signals,
		"count":   len(signals),
		"center": gin.H{
			"latitude":  lat,
			"longitude": lon,
			"radius":    radius,
		},
	})
}

// ============================================================================
// ENHANCED JOIN REQUEST SYSTEM HANDLERS - Sprint 2
// ============================================================================

// CreateJoinRequest handles POST /api/v1/signals/:id/join-requests
func (h *SignalHandler) CreateJoinRequest(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	var req models.CreateJoinRequestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	// Extract user context for rate limiting
	userIP := c.ClientIP()
	userAgent := c.GetHeader("User-Agent")

	joinRequest, err := h.signalService.CreateJoinRequest(uint(signalID), userID, &req, userIP, userAgent)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.CreatedResponse(c, "참여 요청이 생성되었습니다", joinRequest)
}

// ApproveJoinRequest handles PUT /api/v1/signals/:id/join-requests/:user_id/approve
func (h *SignalHandler) ApproveJoinRequest(c *gin.Context) {
	creatorID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	participantID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 사용자 ID입니다")
		return
	}

	var req models.ApproveJoinRequestRequest
	req.UserID = uint(participantID) // Set from URL parameter
	if err := c.ShouldBindJSON(&req); err != nil {
		// Allow empty body, just set default message
		req.Message = "참여가 승인되었습니다"
	}

	if err := h.signalService.ApproveJoinRequest(uint(signalID), creatorID, uint(participantID), &req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "참여 요청을 승인했습니다", nil)
}

// RejectJoinRequest handles PUT /api/v1/signals/:id/join-requests/:user_id/reject
func (h *SignalHandler) RejectJoinRequest(c *gin.Context) {
	creatorID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	participantID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 사용자 ID입니다")
		return
	}

	var req models.RejectJoinRequestRequest
	req.UserID = uint(participantID) // Set from URL parameter
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "거절 사유가 필요합니다")
		return
	}

	if err := h.signalService.RejectJoinRequest(uint(signalID), creatorID, uint(participantID), &req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "참여 요청을 거절했습니다", nil)
}

// GetPendingJoinRequests handles GET /api/v1/signals/:id/join-requests
func (h *SignalHandler) GetPendingJoinRequests(c *gin.Context) {
	creatorID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	requests, err := h.signalService.GetPendingJoinRequests(uint(signalID), creatorID)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "대기중인 참여 요청 조회 완료", gin.H{
		"requests": requests,
		"count":    len(requests),
	})
}

// GetMyJoinRequests handles GET /api/v1/my/join-requests
func (h *SignalHandler) GetMyJoinRequests(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	requests, pagination, err := h.signalService.GetMyJoinRequests(userID, page, limit)
	if err != nil {
		utils.InternalServerErrorResponse(c, "참여 요청 조회에 실패했습니다", err)
		return
	}

	utils.PagedSuccessResponse(c, "내 참여 요청 조회 완료", requests, *pagination)
}

// ============================================================================
// ENHANCED SIGNAL MANAGEMENT HANDLERS
// ============================================================================

// UpdateSignalStatus handles PUT /api/v1/signals/:id/status
func (h *SignalHandler) UpdateSignalStatus(c *gin.Context) {
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	var req struct {
		Status models.SignalStatus `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "유효한 상태값이 필요합니다")
		return
	}

	if err := h.signalService.UpdateSignalStatus(uint(signalID), req.Status); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "시그널 상태가 업데이트되었습니다", nil)
}

// CancelSignal handles POST /api/v1/signals/:id/cancel
func (h *SignalHandler) CancelSignal(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	var req struct {
		Reason string `json:"reason" binding:"required,max=300"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "취소 사유가 필요합니다")
		return
	}

	if err := h.signalService.CancelSignal(uint(signalID), userID, req.Reason); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "시그널이 취소되었습니다", nil)
}

// CompleteSignal handles POST /api/v1/signals/:id/complete
func (h *SignalHandler) CompleteSignal(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	signalID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 시그널 ID입니다")
		return
	}

	if err := h.signalService.CompleteSignal(uint(signalID), userID); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "시그널이 완료되었습니다", nil)
}