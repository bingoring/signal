package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"signal-be/internal/services"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
)

// AnalyticsHandler 분석 핸들러
type AnalyticsHandler struct {
	analyticsService *services.AnalyticsService
	logger           *logger.Logger
}

// NewAnalyticsHandler 새로운 분석 핸들러 생성
func NewAnalyticsHandler(analyticsService *services.AnalyticsService, logger *logger.Logger) *AnalyticsHandler {
	return &AnalyticsHandler{
		analyticsService: analyticsService,
		logger:           logger,
	}
}

// GetUserAnalytics 사용자 분석 데이터 조회
// GET /api/analytics/user/:user_id
func (h *AnalyticsHandler) GetUserAnalytics(c *gin.Context) {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// 주차 파라미터 (선택사항, 기본값: 현재 주)
	weekParam := c.Query("week")
	var weekStartDate time.Time
	
	if weekParam != "" {
		weekStartDate, err = time.Parse("2006-01-02", weekParam)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid week format (YYYY-MM-DD)"})
			return
		}
	} else {
		// 현재 주의 월요일 계산
		now := time.Now()
		weekday := int(now.Weekday())
		if weekday == 0 { // 일요일을 7로 변환
			weekday = 7
		}
		weekStartDate = now.AddDate(0, 0, -(weekday-1)).Truncate(24 * time.Hour)
	}

	analytics, err := h.analyticsService.GetUserAnalytics(uint(userID), weekStartDate)
	if err != nil {
		h.logger.Error("Failed to get user analytics: " + err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get analytics data"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    analytics,
	})
}

// GetUserAnalyticsHistory 사용자 분석 이력 조회
// GET /api/analytics/user/:user_id/history
func (h *AnalyticsHandler) GetUserAnalyticsHistory(c *gin.Context) {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// 조회할 주의 수 (기본값: 4주)
	weeksParam := c.DefaultQuery("weeks", "4")
	weeks, err := strconv.Atoi(weeksParam)
	if err != nil || weeks <= 0 || weeks > 12 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid weeks parameter (1-12)"})
		return
	}

	// 현재 주부터 역순으로 주차 계산
	now := time.Now()
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	currentWeekStart := now.AddDate(0, 0, -(weekday-1)).Truncate(24 * time.Hour)

	var analyticsHistory []models.UserAnalytics
	
	for i := 0; i < weeks; i++ {
		weekStart := currentWeekStart.AddDate(0, 0, -7*i)
		analytics, err := h.analyticsService.GetUserAnalytics(uint(userID), weekStart)
		if err != nil {
			h.logger.Warn("Failed to get analytics for week " + weekStart.Format("2006-01-02") + ": " + err.Error())
			continue
		}
		analyticsHistory = append(analyticsHistory, *analytics)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"history":     analyticsHistory,
			"total_weeks": len(analyticsHistory),
		},
	})
}

// GetUserAchievements 사용자 업적 조회
// GET /api/analytics/user/:user_id/achievements
func (h *AnalyticsHandler) GetUserAchievements(c *gin.Context) {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	achievements, err := h.analyticsService.GetUserAchievements(uint(userID))
	if err != nil {
		h.logger.Error("Failed to get user achievements: " + err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get achievements"})
		return
	}

	// 업적을 카테고리별로 그룹화
	achievementMap := make(map[string][]models.Achievement)
	for _, achievement := range achievements {
		achievementMap[achievement.Category] = append(achievementMap[achievement.Category], achievement)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"achievements":    achievements,
			"by_category":     achievementMap,
			"total_unlocked":  countUnlockedAchievements(achievements),
			"total_available": len(achievements),
		},
	})
}

// GetAnalyticsSummary 분석 요약 정보 조회
// GET /api/analytics/user/:user_id/summary
func (h *AnalyticsHandler) GetAnalyticsSummary(c *gin.Context) {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// 현재 주 분석 데이터
	now := time.Now()
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	currentWeekStart := now.AddDate(0, 0, -(weekday-1)).Truncate(24 * time.Hour)

	currentWeekAnalytics, err := h.analyticsService.GetUserAnalytics(uint(userID), currentWeekStart)
	if err != nil {
		h.logger.Error("Failed to get current week analytics: " + err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get analytics data"})
		return
	}

	// 업적 조회
	achievements, err := h.analyticsService.GetUserAchievements(uint(userID))
	if err != nil {
		h.logger.Error("Failed to get achievements: " + err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get achievements"})
		return
	}

	unlockedCount := countUnlockedAchievements(achievements)
	
	// 최근 언락된 업적 (최대 3개)
	recentAchievements := getRecentUnlockedAchievements(achievements, 3)

	summary := gin.H{
		"current_week": gin.H{
			"week_start_date":      currentWeekStart.Format("2006-01-02"),
			"total_participation":  currentWeekAnalytics.WeeklyStats.TotalParticipation,
			"completion_rate":      currentWeekAnalytics.WeeklyStats.CompletionRate,
			"community_score":      currentWeekAnalytics.SocialImpact.CommunityScore,
			"week_over_week_growth": currentWeekAnalytics.TrendAnalysis.WeekOverWeekGrowth,
			"engagement_trend":     currentWeekAnalytics.TrendAnalysis.EngagementTrend,
		},
		"achievements": gin.H{
			"total_unlocked":      unlockedCount,
			"total_available":     len(achievements),
			"completion_rate":     float64(unlockedCount) / float64(len(achievements)) * 100,
			"recent_achievements": recentAchievements,
		},
		"social_impact": gin.H{
			"influence_rating":   currentWeekAnalytics.SocialImpact.InfluenceRating,
			"helpfulness_score":  currentWeekAnalytics.SocialImpact.HelpfulnessScore,
			"leadership_events":  currentWeekAnalytics.SocialImpact.LeadershipEvents,
			"new_buddies_made":   currentWeekAnalytics.WeeklyStats.NewBuddiesMade,
		},
		"personal_insights": gin.H{
			"favorite_categories": currentWeekAnalytics.WeeklyStats.FavoriteCategories,
			"popular_time_slots":  currentWeekAnalytics.TrendAnalysis.PopularTimeSlots,
			"preferred_locations": currentWeekAnalytics.TrendAnalysis.PreferredLocations,
		},
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    summary,
	})
}

// RegenerateAnalytics 분석 데이터 재생성
// POST /api/analytics/user/:user_id/regenerate
func (h *AnalyticsHandler) RegenerateAnalytics(c *gin.Context) {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// 주차 파라미터
	weekParam := c.Query("week")
	var weekStartDate time.Time
	
	if weekParam != "" {
		weekStartDate, err = time.Parse("2006-01-02", weekParam)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid week format (YYYY-MM-DD)"})
			return
		}
	} else {
		// 현재 주
		now := time.Now()
		weekday := int(now.Weekday())
		if weekday == 0 {
			weekday = 7
		}
		weekStartDate = now.AddDate(0, 0, -(weekday-1)).Truncate(24 * time.Hour)
	}

	// 기존 데이터 삭제 후 재생성
	// TODO: 트랜잭션으로 안전하게 처리
	analytics, err := h.analyticsService.GenerateUserAnalytics(uint(userID), weekStartDate)
	if err != nil {
		h.logger.Error("Failed to regenerate analytics: " + err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to regenerate analytics"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    analytics,
		"message": "Analytics regenerated successfully",
	})
}

// Helper functions

func countUnlockedAchievements(achievements []models.Achievement) int {
	count := 0
	for _, achievement := range achievements {
		if achievement.IsUnlocked {
			count++
		}
	}
	return count
}

func getRecentUnlockedAchievements(achievements []models.Achievement, limit int) []models.Achievement {
	var unlocked []models.Achievement
	
	for _, achievement := range achievements {
		if achievement.IsUnlocked {
			unlocked = append(unlocked, achievement)
		}
	}

	// 언락 시간 기준 정렬 (최신순)
	for i := 0; i < len(unlocked)-1; i++ {
		for j := i + 1; j < len(unlocked); j++ {
			if unlocked[i].UnlockedAt.Before(*unlocked[j].UnlockedAt) {
				unlocked[i], unlocked[j] = unlocked[j], unlocked[i]
			}
		}
	}

	// 제한 수만큼 반환
	if len(unlocked) > limit {
		unlocked = unlocked[:limit]
	}

	return unlocked
}