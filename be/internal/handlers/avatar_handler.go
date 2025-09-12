package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"signal-be/internal/services"
	"signal-module/pkg/models"
)

type AvatarHandler struct {
	avatarService *services.AvatarService
	authService   *services.AuthService
}

func NewAvatarHandler(avatarService *services.AvatarService, authService *services.AuthService) *AvatarHandler {
	return &AvatarHandler{
		avatarService: avatarService,
		authService:   authService,
	}
}

// Method aliases for router compatibility
func (h *AvatarHandler) GetCategories(c *gin.Context) {
	h.GetAvatarCategories(c)
}

func (h *AvatarHandler) GetAvatarsForSelection(c *gin.Context) {
	h.GetUserAvatarSelection(c)
}

func (h *AvatarHandler) ToggleFavorite(c *gin.Context) {
	h.ToggleAvatarFavorite(c)
}

// GetAvatarCategories 아바타 카테고리와 아바타 목록 조회
// @Summary 아바타 카테고리 목록 조회
// @Description 모든 활성 아바타 카테고리와 각 카테고리의 아바타 목록을 반환합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Success 200 {object} models.AvatarSelectionResponse
// @Failure 500 {object} gin.H
// @Router /api/avatars/categories [get]
func (h *AvatarHandler) GetAvatarCategories(c *gin.Context) {
	response, err := h.avatarService.GetAvatarCategories()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get avatar categories",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// GetUserAvatarSelection 사용자 맞춤 아바타 선택 화면
// @Summary 사용자 맞춤 아바타 선택 화면
// @Description 사용자의 즐겨찾기와 최근 사용 아바타를 포함한 선택 화면 데이터를 반환합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} models.AvatarSelectionResponse
// @Failure 401 {object} gin.H
// @Failure 500 {object} gin.H
// @Router /api/avatars/selection [get]
func (h *AvatarHandler) GetUserAvatarSelection(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	response, err := h.avatarService.GetUserAvatarSelection(userID.(uint))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get user avatar selection",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// SearchAvatars 아바타 검색
// @Summary 아바타 검색
// @Description 키워드로 아바타를 검색합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Param query query string true "검색 키워드"
// @Param category_id query int false "카테고리 ID (선택사항)"
// @Param limit query int false "결과 제한 수 (기본: 20, 최대: 50)"
// @Success 200 {object} models.AvatarSearchResponse
// @Failure 400 {object} gin.H
// @Failure 500 {object} gin.H
// @Router /api/avatars/search [get]
func (h *AvatarHandler) SearchAvatars(c *gin.Context) {
	query := c.Query("query")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Query parameter is required"})
		return
	}

	request := models.AvatarSearchRequest{
		Query: query,
		Limit: 20, // 기본값
	}

	// 카테고리 ID 파싱
	if categoryIDStr := c.Query("category_id"); categoryIDStr != "" {
		if categoryID, err := strconv.ParseUint(categoryIDStr, 10, 32); err == nil {
			categoryIDUint := uint(categoryID)
			request.CategoryID = &categoryIDUint
		}
	}

	// 제한 수 파싱
	if limitStr := c.Query("limit"); limitStr != "" {
		if limit, err := strconv.Atoi(limitStr); err == nil && limit > 0 && limit <= 50 {
			request.Limit = limit
		}
	}

	response, err := h.avatarService.SearchAvatars(request)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to search avatars",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// SetUserAvatar 사용자 아바타 설정
// @Summary 사용자 아바타 설정
// @Description 사용자의 현재 아바타를 변경합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param request body models.SetUserAvatarRequest true "아바타 설정 요청"
// @Success 200 {object} gin.H
// @Failure 400 {object} gin.H
// @Failure 401 {object} gin.H
// @Failure 500 {object} gin.H
// @Router /api/avatars/set [post]
func (h *AvatarHandler) SetUserAvatar(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var request models.SetUserAvatarRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid request format",
			"message": err.Error(),
		})
		return
	}

	// 아바타 이모지 유효성 검증
	avatar, err := h.avatarService.ValidateAvatarEmoji(request.Emoji)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Invalid avatar",
			"message": err.Error(),
		})
		return
	}

	// 아바타 설정
	err = h.avatarService.SetUserAvatar(userID.(uint), request)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to set avatar",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Avatar updated successfully",
		"avatar": gin.H{
			"emoji":       avatar.Emoji,
			"name":        avatar.Name,
			"description": avatar.Description,
		},
	})
}

// ToggleAvatarFavorite 아바타 즐겨찾기 토글
// @Summary 아바타 즐겨찾기 토글
// @Description 아바타를 즐겨찾기에 추가하거나 제거합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param avatar_id path int true "아바타 ID"
// @Success 200 {object} gin.H
// @Failure 400 {object} gin.H
// @Failure 401 {object} gin.H
// @Failure 500 {object} gin.H
// @Router /api/avatars/{avatar_id}/favorite [post]
func (h *AvatarHandler) ToggleAvatarFavorite(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	avatarIDStr := c.Param("avatar_id")
	avatarID, err := strconv.ParseUint(avatarIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid avatar ID"})
		return
	}

	isFavorite, err := h.avatarService.ToggleAvatarFavorite(userID.(uint), uint(avatarID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to toggle favorite",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":     "Favorite status updated",
		"is_favorite": isFavorite,
	})
}

// GetUserAvatarStats 사용자 아바타 통계
// @Summary 사용자 아바타 통계
// @Description 사용자의 아바타 사용 통계와 개성 분석을 반환합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} models.UserAvatarStatsResponse
// @Failure 401 {object} gin.H
// @Failure 500 {object} gin.H
// @Router /api/avatars/stats [get]
func (h *AvatarHandler) GetUserAvatarStats(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	stats, err := h.avatarService.GetUserAvatarStats(userID.(uint))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get avatar stats",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetPopularAvatars 인기 아바타 목록
// @Summary 인기 아바타 목록
// @Description 전체 사용자가 가장 많이 사용하는 인기 아바타 목록을 반환합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Param limit query int false "결과 제한 수 (기본: 20, 최대: 50)"
// @Success 200 {object} gin.H
// @Failure 500 {object} gin.H
// @Router /api/avatars/popular [get]
func (h *AvatarHandler) GetPopularAvatars(c *gin.Context) {
	limit := 20 // 기본값

	if limitStr := c.Query("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 && parsedLimit <= 50 {
			limit = parsedLimit
		}
	}

	popular, err := h.avatarService.GetPopularAvatars(limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get popular avatars",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"popular_avatars": popular,
		"total":           len(popular),
	})
}

// GetDefaultAvatars 기본 추천 아바타
// @Summary 기본 추천 아바타 목록
// @Description 신규 사용자에게 추천하는 기본 아바타 목록을 반환합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Success 200 {object} gin.H
// @Failure 500 {object} gin.H
// @Router /api/avatars/default [get]
func (h *AvatarHandler) GetDefaultAvatars(c *gin.Context) {
	avatars, err := h.avatarService.GetDefaultAvatars()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to get default avatars",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"default_avatars": avatars,
		"total":           len(avatars),
	})
}

// GetPersonalityAnalysis 아바타 기반 성향 분석
// @Summary 아바타 기반 성향 분석
// @Description 사용자의 아바타 사용 패턴을 분석하여 성향을 진단합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} models.AvatarPersonality
// @Failure 401 {object} gin.H
// @Failure 500 {object} gin.H
// @Router /api/avatars/personality [get]
func (h *AvatarHandler) GetPersonalityAnalysis(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	personality, err := h.avatarService.GetAvatarPersonalityAnalysis(userID.(uint))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to analyze personality",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, personality)
}

// ValidateAvatar 아바타 유효성 검증
// @Summary 아바타 유효성 검증
// @Description 입력된 이모지가 유효한 아바타인지 확인합니다
// @Tags Avatar
// @Accept json
// @Produce json
// @Param emoji query string true "검증할 이모지"
// @Success 200 {object} gin.H
// @Failure 400 {object} gin.H
// @Failure 404 {object} gin.H
// @Router /api/avatars/validate [get]
func (h *AvatarHandler) ValidateAvatar(c *gin.Context) {
	emoji := c.Query("emoji")
	if emoji == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Emoji parameter is required"})
		return
	}

	avatar, err := h.avatarService.ValidateAvatarEmoji(emoji)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error":   "Invalid avatar",
			"message": err.Error(),
			"valid":   false,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"valid":  true,
		"avatar": avatar,
	})
}

// Admin endpoints (if needed)

// BulkUpdateStats 아바타 통계 일괄 업데이트 (관리자 전용)
// @Summary 아바타 통계 일괄 업데이트
// @Description 모든 아바타의 사용 통계를 재계산합니다 (관리자 전용)
// @Tags Avatar,Admin
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} gin.H
// @Failure 401 {object} gin.H
// @Failure 403 {object} gin.H
// @Failure 500 {object} gin.H
// @Router /api/admin/avatars/bulk-update-stats [post]
func (h *AvatarHandler) BulkUpdateStats(c *gin.Context) {
	// 관리자 권한 확인 (실제 구현에서는 적절한 권한 체크 필요)
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// TODO: 실제 관리자 권한 체크
	_ = userID

	err := h.avatarService.BulkUpdateAvatarStats()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to update avatar stats",
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Avatar statistics updated successfully",
	})
}