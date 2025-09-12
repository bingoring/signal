package handlers

import (
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

// Phase 1: 최소주의 프로필 조회 (핵심 정보만 반환)
func (h *UserHandler) GetProfile(c *gin.Context) {
	userID := c.GetUint("user_id")

	user, err := h.userService.GetUserByID(userID)
	if err != nil {
		utils.NotFoundResponse(c, "사용자를 찾을 수 없습니다")
		return
	}

	// 최소주의 프로필 정보만 반환 (민감한 정보 제외)
	profileData := gin.H{
		"id":                     user.ID,
		"username":               user.Username,
		"display_name":           user.Profile.DisplayName,
		"manner_temperature":     user.Profile.MannerTemperature,
		"trust_level":           user.Profile.GetTrustLevel(),
		"completion_rate":        user.Profile.CompletionRate,
		"total_activities":       user.Profile.SignalCount + user.Profile.JoinCount,
		"is_recently_active":     user.Profile.IsRecentlyActive(),
		"avatar":                user.Profile.Avatar,
		"one_line":              user.Profile.OneLine,
		"notifications_enabled":  user.Profile.NotificationsEnabled,
		"created_at":            user.CreatedAt,
	}

	utils.SuccessResponse(c, "프로필 조회 완료", profileData)
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

// Phase 1: 새로운 최소주의 프로필 API 엔드포인트들

// GetMinimalProfile - 다른 사용자의 최소 프로필 조회 (Signal에서 표시될 정보)
func (h *UserHandler) GetMinimalProfile(c *gin.Context) {
	targetUserID := c.Param("user_id")
	
	user, err := h.userService.GetUserByUsername(targetUserID) // username 또는 ID로 조회
	if err != nil {
		utils.NotFoundResponse(c, "사용자를 찾을 수 없습니다")
		return
	}

	// 다른 사용자에게 보여줄 최소한의 정보만 반환
	minimalProfile := gin.H{
		"username":           user.Username,
		"display_name":       user.Profile.DisplayName,
		"manner_temperature": user.Profile.MannerTemperature,
		"trust_level":       user.Profile.GetTrustLevel(),
		"total_activities":   user.Profile.SignalCount + user.Profile.JoinCount,
		"completion_rate":    user.Profile.CompletionRate,
		"avatar":            user.Profile.Avatar,
		"one_line":          user.Profile.OneLine,
		"is_recently_active": user.Profile.IsRecentlyActive(),
	}

	utils.SuccessResponse(c, "최소 프로필 조회 완료", minimalProfile)
}

// UpdateMannerTemperature - Signal 완료/노쇼 시 매너온도 업데이트
func (h *UserHandler) UpdateMannerTemperature(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req struct {
		Action string `json:"action" binding:"required,oneof=signal_created signal_joined signal_completed no_show rating_received"`
		SignalID *uint `json:"signal_id,omitempty"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	if err := h.userService.UpdateUserActivity(userID, req.Action, req.SignalID); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	// 업데이트된 매너온도 반환
	user, _ := h.userService.GetUserByID(userID)
	responseData := gin.H{
		"manner_temperature": user.Profile.MannerTemperature,
		"trust_level":       user.Profile.GetTrustLevel(),
		"completion_rate":    user.Profile.CompletionRate,
		"total_activities":   user.Profile.SignalCount + user.Profile.JoinCount,
	}

	utils.SuccessResponse(c, "매너온도가 업데이트되었습니다", responseData)
}

// GetTrustStats - 사용자의 신뢰 통계 조회
func (h *UserHandler) GetTrustStats(c *gin.Context) {
	userID := c.GetUint("user_id")

	user, err := h.userService.GetUserByID(userID)
	if err != nil {
		utils.NotFoundResponse(c, "사용자를 찾을 수 없습니다")
		return
	}

	stats := gin.H{
		"manner_temperature": user.Profile.MannerTemperature,
		"trust_level":       user.Profile.GetTrustLevel(),
		"completion_rate":    user.Profile.CompletionRate,
		"signal_count":      user.Profile.SignalCount,
		"join_count":        user.Profile.JoinCount,
		"total_activities":   user.Profile.SignalCount + user.Profile.JoinCount,
		"no_show_count":     user.Profile.NoShowCount,
		"total_ratings":     user.Profile.TotalRatings,
		"last_activity_at":  user.Profile.LastActivityAt,
		"is_recently_active": user.Profile.IsRecentlyActive(),
	}

	utils.SuccessResponse(c, "신뢰 통계 조회 완료", stats)
}

// QuickSetup - 새 사용자를 위한 빠른 프로필 설정 (30초 이내 완료)
func (h *UserHandler) QuickSetup(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req struct {
		DisplayName string  `json:"display_name" binding:"required,min=2,max=30"`
		Avatar      *string `json:"avatar,omitempty"`     // 이모지 아바타 선택사항
		OneLine     *string `json:"one_line,omitempty" binding:"max=50"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	// 빠른 설정으로 프로필 업데이트
	updateReq := models.UpdateProfileRequest{
		DisplayName: req.DisplayName,
		Avatar:      req.Avatar,
		OneLine:     req.OneLine,
	}

	if err := h.userService.UpdateProfile(userID, &updateReq); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	// 설정 완료된 프로필 정보 반환
	user, _ := h.userService.GetUserByID(userID)
	setupData := gin.H{
		"display_name":       user.Profile.DisplayName,
		"manner_temperature": user.Profile.MannerTemperature,
		"trust_level":       user.Profile.GetTrustLevel(),
		"avatar":            user.Profile.Avatar,
		"one_line":          user.Profile.OneLine,
		"setup_completed":    true,
	}

	utils.SuccessResponse(c, "프로필 빠른 설정이 완료되었습니다", setupData)
}