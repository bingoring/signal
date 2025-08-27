package handlers

import (
	"strconv"

	"signal-be/internal/services"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/utils"

	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	userService services.UserServiceInterface
	logger      *logger.Logger
}

func NewUserHandler(userService services.UserServiceInterface, logger *logger.Logger) *UserHandler {
	return &UserHandler{
		userService: userService,
		logger:      logger,
	}
}

func (h *UserHandler) GetProfile(c *gin.Context) {
	userID := c.GetUint("user_id")

	user, err := h.userService.GetUserByID(userID)
	if err != nil {
		utils.NotFoundResponse(c, "사용자를 찾을 수 없습니다")
		return
	}

	utils.SuccessResponse(c, "프로필 조회 완료", user)
}

func (h *UserHandler) UpdateProfile(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req models.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.userService.UpdateProfile(userID, &req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "프로필이 업데이트되었습니다", nil)
}

func (h *UserHandler) UpdateLocation(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req models.UpdateLocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.userService.UpdateLocation(userID, &req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "위치가 업데이트되었습니다", nil)
}

func (h *UserHandler) UpdateInterests(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req struct {
		Interests []models.UserInterest `json:"interests" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.userService.UpdateInterests(userID, req.Interests); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "관심사가 업데이트되었습니다", nil)
}

func (h *UserHandler) RegisterPushToken(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req struct {
		Token    string `json:"token" binding:"required"`
		Platform string `json:"platform" binding:"required,oneof=ios android"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.userService.RegisterPushToken(userID, req.Token, req.Platform); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "푸시 토큰이 등록되었습니다", nil)
}

func (h *UserHandler) RateUser(c *gin.Context) {
	raterID := c.GetUint("user_id")

	var req models.UserRating
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.userService.RateUser(raterID, &req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "사용자 평가가 완료되었습니다", nil)
}

func (h *UserHandler) ReportUser(c *gin.Context) {
	reporterID := c.GetUint("user_id")

	var req models.ReportUser
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.userService.ReportUser(reporterID, &req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "사용자 신고가 접수되었습니다", nil)
}