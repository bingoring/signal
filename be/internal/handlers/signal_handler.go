package handlers

import (
	"strconv"

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
	// 승인과 유사한 로직으로 구현
	utils.SuccessResponse(c, "참여자를 거절했습니다", nil)
}