package handlers

import (
	"signal-be/internal/services"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/utils"
	"strconv"

	"github.com/gin-gonic/gin"
)

type BuddyHandler struct {
	buddyService services.BuddyServiceInterface
	logger       *logger.Logger
}

func NewBuddyHandler(buddyService services.BuddyServiceInterface, logger *logger.Logger) *BuddyHandler {
	return &BuddyHandler{
		buddyService: buddyService,
		logger:       logger,
	}
}

// GetBuddies 단골 목록 조회
func (h *BuddyHandler) GetBuddies(c *gin.Context) {
	userID := c.GetUint("user_id")
	
	var query models.GetBuddiesQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		utils.BadRequestResponse(c, "잘못된 쿼리 파라미터입니다")
		return
	}

	buddies, total, err := h.buddyService.GetUserBuddies(userID, &query)
	if err != nil {
		h.logger.Error("단골 목록 조회 실패", err)
		utils.InternalServerErrorResponse(c, "단골 목록을 조회할 수 없습니다", err)
		return
	}

	pagination := utils.CalculatePagination(query.Page, query.Limit, total)
	utils.PagedSuccessResponse(c, "단골 목록 조회 성공", buddies, pagination)
}

// GetBuddy 특정 단골 관계 조회
func (h *BuddyHandler) GetBuddy(c *gin.Context) {
	userID := c.GetUint("user_id")
	buddyIDStr := c.Param("buddyId")
	
	buddyID, err := strconv.ParseUint(buddyIDStr, 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "잘못된 단골 ID입니다")
		return
	}

	buddy, err := h.buddyService.GetBuddyRelationship(userID, uint(buddyID))
	if err != nil {
		utils.NotFoundResponse(c, "단골 관계를 찾을 수 없습니다")
		return
	}

	utils.SuccessResponse(c, "단골 관계 조회 성공", buddy)
}

// CreateBuddy 단골 관계 생성
func (h *BuddyHandler) CreateBuddy(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req models.CreateBuddyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if userID == req.BuddyID {
		utils.BadRequestResponse(c, "자기 자신을 단골로 추가할 수 없습니다")
		return
	}

	buddy, err := h.buddyService.CreateBuddy(userID, req.BuddyID)
	if err != nil {
		h.logger.Error("단골 관계 생성 실패", err)
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.CreatedResponse(c, "단골 관계가 생성되었습니다", buddy)
}

// UpdateBuddy 단골 관계 수정
func (h *BuddyHandler) UpdateBuddy(c *gin.Context) {
	userID := c.GetUint("user_id")
	buddyIDStr := c.Param("buddyId")
	
	buddyID, err := strconv.ParseUint(buddyIDStr, 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "잘못된 단골 ID입니다")
		return
	}

	var req models.UpdateBuddyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.buddyService.UpdateBuddy(userID, uint(buddyID), &req); err != nil {
		h.logger.Error("단골 관계 수정 실패", err)
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "단골 관계가 수정되었습니다", nil)
}

// DeleteBuddy 단골 관계 삭제
func (h *BuddyHandler) DeleteBuddy(c *gin.Context) {
	userID := c.GetUint("user_id")
	buddyIDStr := c.Param("buddyId")
	
	buddyID, err := strconv.ParseUint(buddyIDStr, 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "잘못된 단골 ID입니다")
		return
	}

	if err := h.buddyService.DeleteBuddy(userID, uint(buddyID)); err != nil {
		h.logger.Error("단골 관계 삭제 실패", err)
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "단골 관계가 삭제되었습니다", nil)
}

// GetPotentialBuddies 단골 후보자 조회
func (h *BuddyHandler) GetPotentialBuddies(c *gin.Context) {
	userID := c.GetUint("user_id")

	minInteractions := 2
	minMannerScore := 4.0

	if mi := c.Query("min_interactions"); mi != "" {
		if parsed, err := strconv.Atoi(mi); err == nil {
			minInteractions = parsed
		}
	}

	if mms := c.Query("min_manner_score"); mms != "" {
		if parsed, err := strconv.ParseFloat(mms, 64); err == nil {
			minMannerScore = parsed
		}
	}

	candidates, err := h.buddyService.GetPotentialBuddies(userID, minInteractions, minMannerScore)
	if err != nil {
		h.logger.Error("단골 후보자 조회 실패", err)
		utils.InternalServerErrorResponse(c, "단골 후보자를 조회할 수 없습니다", err)
		return
	}

	utils.SuccessResponse(c, "단골 후보자 조회 성공", candidates)
}

// GetBuddyStats 단골 통계 조회
func (h *BuddyHandler) GetBuddyStats(c *gin.Context) {
	userID := c.GetUint("user_id")

	stats, err := h.buddyService.GetBuddyStats(userID)
	if err != nil {
		h.logger.Error("단골 통계 조회 실패", err)
		utils.InternalServerErrorResponse(c, "단골 통계를 조회할 수 없습니다", err)
		return
	}

	utils.SuccessResponse(c, "단골 통계 조회 성공", stats)
}

// CreateMannerLog 매너 점수 평가
func (h *BuddyHandler) CreateMannerLog(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req models.CreateMannerLogRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if userID == req.RateeID {
		utils.BadRequestResponse(c, "자기 자신을 평가할 수 없습니다")
		return
	}

	log, err := h.buddyService.CreateMannerLog(userID, &req)
	if err != nil {
		h.logger.Error("매너 점수 평가 실패", err)
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.CreatedResponse(c, "매너 점수가 평가되었습니다", log)
}

// GetMannerLogs 매너 점수 이력 조회
func (h *BuddyHandler) GetMannerLogs(c *gin.Context) {
	userID := c.GetUint("user_id")

	page := 1
	limit := 20

	if p := c.Query("page"); p != "" {
		if parsed, err := strconv.Atoi(p); err == nil && parsed > 0 {
			page = parsed
		}
	}

	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	logs, total, err := h.buddyService.GetMannerLogs(userID, page, limit)
	if err != nil {
		h.logger.Error("매너 점수 이력 조회 실패", err)
		utils.InternalServerErrorResponse(c, "매너 점수 이력을 조회할 수 없습니다", err)
		return
	}

	pagination := utils.CalculatePagination(page, limit, total)
	utils.PagedSuccessResponse(c, "매너 점수 이력 조회 성공", logs, pagination)
}

// CreateBuddyInvitation 단골 초대 생성
func (h *BuddyHandler) CreateBuddyInvitation(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req models.CreateBuddyInvitationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if userID == req.InviteeID {
		utils.BadRequestResponse(c, "자기 자신을 초대할 수 없습니다")
		return
	}

	invitation, err := h.buddyService.CreateBuddyInvitation(userID, &req)
	if err != nil {
		h.logger.Error("단골 초대 생성 실패", err)
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.CreatedResponse(c, "단골 초대가 생성되었습니다", invitation)
}

// GetBuddyInvitations 단골 초대 목록 조회
func (h *BuddyHandler) GetBuddyInvitations(c *gin.Context) {
	userID := c.GetUint("user_id")

	page := 1
	limit := 20
	var status []models.InvitationStatus

	if p := c.Query("page"); p != "" {
		if parsed, err := strconv.Atoi(p); err == nil && parsed > 0 {
			page = parsed
		}
	}

	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	if s := c.Query("status"); s != "" {
		status = append(status, models.InvitationStatus(s))
	}

	invitations, total, err := h.buddyService.GetUserInvitations(userID, status, page, limit)
	if err != nil {
		h.logger.Error("단골 초대 목록 조회 실패", err)
		utils.InternalServerErrorResponse(c, "단골 초대 목록을 조회할 수 없습니다", err)
		return
	}

	pagination := utils.CalculatePagination(page, limit, total)
	utils.PagedSuccessResponse(c, "단골 초대 목록 조회 성공", invitations, pagination)
}

// RespondBuddyInvitation 단골 초대 응답
func (h *BuddyHandler) RespondBuddyInvitation(c *gin.Context) {
	userID := c.GetUint("user_id")
	invitationIDStr := c.Param("invitationId")
	
	invitationID, err := strconv.ParseUint(invitationIDStr, 10, 32)
	if err != nil {
		utils.BadRequestResponse(c, "잘못된 초대 ID입니다")
		return
	}

	var req models.RespondBuddyInvitationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.buddyService.RespondBuddyInvitation(userID, uint(invitationID), req.Status); err != nil {
		h.logger.Error("단골 초대 응답 실패", err)
		utils.BadRequestResponse(c, err.Error())
		return
	}

	var message string
	switch req.Status {
	case models.InvitationStatusAccepted:
		message = "단골 초대를 수락했습니다"
	case models.InvitationStatusDeclined:
		message = "단골 초대를 거절했습니다"
	}

	utils.SuccessResponse(c, message, nil)
}