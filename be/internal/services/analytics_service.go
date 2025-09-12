package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"time"

	"gorm.io/gorm"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
)

// AnalyticsService 분석 서비스
type AnalyticsService struct {
	db     *gorm.DB
	logger *logger.Logger
}

// NewAnalyticsService 새로운 분석 서비스 생성
func NewAnalyticsService(db *gorm.DB, logger *logger.Logger) *AnalyticsService {
	return &AnalyticsService{
		db:     db,
		logger: logger,
	}
}

// GetUserAnalytics 사용자 분석 데이터 조회
func (s *AnalyticsService) GetUserAnalytics(userID uint, weekStartDate time.Time) (*models.UserAnalytics, error) {
	var analytics models.UserAnalytics
	
	err := s.db.Where("user_id = ? AND week_start_date = ?", userID, weekStartDate).First(&analytics).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 데이터가 없으면 생성
			return s.GenerateUserAnalytics(userID, weekStartDate)
		}
		return nil, fmt.Errorf("failed to get user analytics: %w", err)
	}
	
	return &analytics, nil
}

// GenerateUserAnalytics 사용자 분석 데이터 생성
func (s *AnalyticsService) GenerateUserAnalytics(userID uint, weekStartDate time.Time) (*models.UserAnalytics, error) {
	weekEndDate := weekStartDate.AddDate(0, 0, 7)
	
	// 주간 활동 통계 계산
	weeklyStats, err := s.calculateWeeklyStats(userID, weekStartDate, weekEndDate)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate weekly stats: %w", err)
	}
	
	// 사회적 영향 메트릭 계산
	socialImpact, err := s.calculateSocialImpact(userID, weekStartDate, weekEndDate)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate social impact: %w", err)
	}
	
	// 트렌드 분석
	trendAnalysis, err := s.calculateTrendAnalysis(userID, weekStartDate)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate trend analysis: %w", err)
	}
	
	// 분석 데이터 저장
	analytics := &models.UserAnalytics{
		UserID:        userID,
		WeekStartDate: weekStartDate,
		WeeklyStats:   *weeklyStats,
		SocialImpact:  *socialImpact,
		TrendAnalysis: *trendAnalysis,
	}
	
	if err := s.db.Create(analytics).Error; err != nil {
		return nil, fmt.Errorf("failed to save user analytics: %w", err)
	}
	
	s.logger.Info(fmt.Sprintf("Generated analytics for user %d, week %s", userID, weekStartDate.Format("2006-01-02")))
	
	return analytics, nil
}

// calculateWeeklyStats 주간 활동 통계 계산
func (s *AnalyticsService) calculateWeeklyStats(userID uint, startDate, endDate time.Time) (*models.WeeklyActivityStats, error) {
	var stats models.WeeklyActivityStats
	
	// 시그널 생성 수
	if err := s.db.Model(&models.Signal{}).
		Where("creator_id = ? AND created_at BETWEEN ? AND ?", userID, startDate, endDate).
		Count(&[]int64{int64(stats.SignalsCreated)}[0]).Error; err != nil {
		return nil, err
	}
	
	// 시그널 참여 수
	if err := s.db.Table("signal_participants").
		Where("user_id = ? AND created_at BETWEEN ? AND ?", userID, startDate, endDate).
		Count(&[]int64{int64(stats.SignalsJoined)}[0]).Error; err != nil {
		return nil, err
	}
	
	stats.TotalParticipation = stats.SignalsCreated + stats.SignalsJoined
	
	// 완료율 계산
	var completedCount int64
	s.db.Table("signal_participants").
		Where("user_id = ? AND created_at BETWEEN ? AND ? AND status = 'completed'", userID, startDate, endDate).
		Count(&completedCount)
	
	if stats.TotalParticipation > 0 {
		stats.CompletionRate = float64(completedCount) / float64(stats.TotalParticipation) * 100
	}
	
	// 평균 평점 계산
	var avgRating sql.NullFloat64
	s.db.Model(&models.MannerScoreLog{}).
		Select("AVG(rating)").
		Where("target_user_id = ? AND created_at BETWEEN ? AND ?", userID, startDate, endDate).
		Scan(&avgRating)
	
	if avgRating.Valid {
		stats.AverageRating = avgRating.Float64
	}
	
	// 새로운 단골 수
	s.db.Model(&models.UserBuddy{}).
		Where("(user_id = ? OR buddy_id = ?) AND created_at BETWEEN ? AND ?", userID, userID, startDate, endDate).
		Count(&[]int64{int64(stats.NewBuddiesMade)}[0])
	
	// 메시지 교환 수 (추정)
	var messageCount int64
	s.db.Table("chat_messages").
		Where("sender_id = ? AND created_at BETWEEN ? AND ?", userID, startDate, endDate).
		Count(&messageCount)
	stats.MessagesExchanged = int(messageCount)
	
	// 선호 카테고리 계산
	stats.FavoriteCategories = s.calculateFavoriteCategories(userID, startDate, endDate)
	
	return &stats, nil
}

// calculateSocialImpact 사회적 영향 메트릭 계산
func (s *AnalyticsService) calculateSocialImpact(userID uint, startDate, endDate time.Time) (*models.SocialImpactMetrics, error) {
	var impact models.SocialImpactMetrics
	
	// 커뮤니티 점수 (시그널 성공률 + 참여자 만족도)
	var successfulSignals int64
	s.db.Model(&models.Signal{}).
		Where("creator_id = ? AND created_at BETWEEN ? AND ? AND status = 'completed'", userID, startDate, endDate).
		Count(&successfulSignals)
	
	var totalSignals int64
	s.db.Model(&models.Signal{}).
		Where("creator_id = ? AND created_at BETWEEN ? AND ?", userID, startDate, endDate).
		Count(&totalSignals)
	
	if totalSignals > 0 {
		impact.CommunityScore = float64(successfulSignals) / float64(totalSignals) * 100
	}
	
	// 영향력 점수 (다른 사용자들의 평가 기반)
	var avgInfluenceRating sql.NullFloat64
	s.db.Model(&models.MannerScoreLog{}).
		Select("AVG(rating)").
		Where("target_user_id = ? AND created_at BETWEEN ? AND ?", userID, startDate, endDate).
		Scan(&avgInfluenceRating)
	
	if avgInfluenceRating.Valid {
		impact.InfluenceRating = avgInfluenceRating.Float64
	}
	
	// 도움 점수 (긍정적 피드백 비율)
	var positiveRatings int64
	s.db.Model(&models.MannerScoreLog{}).
		Where("target_user_id = ? AND created_at BETWEEN ? AND ? AND rating >= 4.0", userID, startDate, endDate).
		Count(&positiveRatings)
	
	var totalRatings int64
	s.db.Model(&models.MannerScoreLog{}).
		Where("target_user_id = ? AND created_at BETWEEN ? AND ?", userID, startDate, endDate).
		Count(&totalRatings)
	
	if totalRatings > 0 {
		impact.HelpfulnessScore = float64(positiveRatings) / float64(totalRatings) * 100
	}
	
	// 리더십 이벤트 (주최한 성공적인 시그널)
	impact.LeadershipEvents = int(successfulSignals)
	impact.PositiveFeedback = int(positiveRatings)
	
	// 멘토십 활동 (새로운 사용자와의 상호작용)
	impact.MentorshipActivity = s.calculateMentorshipActivity(userID, startDate, endDate)
	
	return &impact, nil
}

// calculateTrendAnalysis 트렌드 분석 계산
func (s *AnalyticsService) calculateTrendAnalysis(userID uint, currentWeekStart time.Time) (*models.TrendData, error) {
	var trend models.TrendData
	
	previousWeekStart := currentWeekStart.AddDate(0, 0, -7)
	
	// 전주 대비 성장률
	currentWeekActivity := s.getWeekActivity(userID, currentWeekStart)
	previousWeekActivity := s.getWeekActivity(userID, previousWeekStart)
	
	if previousWeekActivity > 0 {
		trend.WeekOverWeekGrowth = ((float64(currentWeekActivity) - float64(previousWeekActivity)) / float64(previousWeekActivity)) * 100
	}
	
	// 인기 시간대 분석
	trend.PopularTimeSlots = s.calculatePopularTimeSlots(userID)
	
	// 선호 위치 분석
	trend.PreferredLocations = s.calculatePreferredLocations(userID)
	
	// 소셜 네트워크 성장률
	trend.SocialNetworkGrowth = s.calculateSocialNetworkGrowth(userID, currentWeekStart)
	
	// 참여도 트렌드
	trend.EngagementTrend = s.determineEngagementTrend(userID, currentWeekStart)
	
	return &trend, nil
}

// Helper functions

func (s *AnalyticsService) calculateFavoriteCategories(userID uint, startDate, endDate time.Time) []string {
	var results []struct {
		Category string
		Count    int64
	}
	
	s.db.Table("signals s").
		Select("s.category, COUNT(*) as count").
		Joins("LEFT JOIN signal_participants sp ON s.id = sp.signal_id").
		Where("(s.creator_id = ? OR sp.user_id = ?) AND s.created_at BETWEEN ? AND ?", userID, userID, startDate, endDate).
		Group("s.category").
		Order("count DESC").
		Limit(3).
		Scan(&results)
	
	categories := make([]string, len(results))
	for i, result := range results {
		categories[i] = result.Category
	}
	
	return categories
}

func (s *AnalyticsService) calculateMentorshipActivity(userID uint, startDate, endDate time.Time) int {
	// 새로운 사용자(가입 30일 이내)와의 상호작용 수
	var mentorshipCount int64
	
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)
	
	s.db.Table("signal_participants sp").
		Joins("JOIN users u ON sp.user_id = u.id").
		Joins("JOIN signals s ON sp.signal_id = s.id").
		Where("s.creator_id = ? AND u.created_at > ? AND sp.created_at BETWEEN ? AND ?", 
			userID, thirtyDaysAgo, startDate, endDate).
		Count(&mentorshipCount)
	
	return int(mentorshipCount)
}

func (s *AnalyticsService) getWeekActivity(userID uint, weekStart time.Time) int {
	weekEnd := weekStart.AddDate(0, 0, 7)
	
	var signalsCreated int64
	s.db.Model(&models.Signal{}).
		Where("creator_id = ? AND created_at BETWEEN ? AND ?", userID, weekStart, weekEnd).
		Count(&signalsCreated)
	
	var signalsJoined int64
	s.db.Table("signal_participants").
		Where("user_id = ? AND created_at BETWEEN ? AND ?", userID, weekStart, weekEnd).
		Count(&signalsJoined)
	
	return int(signalsCreated + signalsJoined)
}

func (s *AnalyticsService) calculatePopularTimeSlots(userID uint) []models.TimeSlot {
	var results []struct {
		Hour     int
		DayOfWeek int
		Count    int64
	}
	
	// 최근 30일간의 활동 패턴 분석
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)
	
	s.db.Raw(`
		SELECT 
			EXTRACT(hour FROM created_at) as hour,
			EXTRACT(dow FROM created_at) as day_of_week,
			COUNT(*) as count
		FROM (
			SELECT created_at FROM signals WHERE creator_id = ? AND created_at > ?
			UNION ALL
			SELECT sp.created_at FROM signal_participants sp 
			JOIN signals s ON sp.signal_id = s.id 
			WHERE sp.user_id = ? AND sp.created_at > ?
		) activities
		GROUP BY hour, day_of_week
		ORDER BY count DESC
		LIMIT 10
	`, userID, thirtyDaysAgo, userID, thirtyDaysAgo).Scan(&results)
	
	totalActivity := int64(0)
	for _, result := range results {
		totalActivity += result.Count
	}
	
	timeSlots := make([]models.TimeSlot, len(results))
	for i, result := range results {
		timeSlots[i] = models.TimeSlot{
			Hour:          result.Hour,
			DayOfWeek:     result.DayOfWeek,
			ActivityCount: int(result.Count),
			Probability:   float64(result.Count) / float64(totalActivity),
		}
	}
	
	return timeSlots
}

func (s *AnalyticsService) calculatePreferredLocations(userID uint) []models.LocationTrend {
	var results []struct {
		District  string
		Count     int64
		Category  string
	}
	
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)
	
	s.db.Raw(`
		SELECT 
			s.district,
			COUNT(*) as count,
			s.category
		FROM signals s
		LEFT JOIN signal_participants sp ON s.id = sp.signal_id
		WHERE (s.creator_id = ? OR sp.user_id = ?) AND s.created_at > ?
		GROUP BY s.district, s.category
		ORDER BY count DESC
		LIMIT 5
	`, userID, userID, thirtyDaysAgo).Scan(&results)
	
	totalVisits := int64(0)
	for _, result := range results {
		totalVisits += result.Count
	}
	
	locations := make([]models.LocationTrend, len(results))
	for i, result := range results {
		locations[i] = models.LocationTrend{
			District:        result.District,
			VisitFrequency:  int(result.Count),
			PreferenceScore: float64(result.Count) / float64(totalVisits) * 100,
			Category:        result.Category,
		}
	}
	
	return locations
}

func (s *AnalyticsService) calculateSocialNetworkGrowth(userID uint, currentWeekStart time.Time) float64 {
	previousWeekStart := currentWeekStart.AddDate(0, 0, -7)
	
	var currentWeekBuddies int64
	s.db.Model(&models.UserBuddy{}).
		Where("(user_id = ? OR buddy_id = ?) AND created_at BETWEEN ? AND ?", 
			userID, userID, currentWeekStart, currentWeekStart.AddDate(0, 0, 7)).
		Count(&currentWeekBuddies)
	
	var previousWeekBuddies int64
	s.db.Model(&models.UserBuddy{}).
		Where("(user_id = ? OR buddy_id = ?) AND created_at BETWEEN ? AND ?", 
			userID, userID, previousWeekStart, previousWeekStart.AddDate(0, 0, 7)).
		Count(&previousWeekBuddies)
	
	if previousWeekBuddies > 0 {
		return ((float64(currentWeekBuddies) - float64(previousWeekBuddies)) / float64(previousWeekBuddies)) * 100
	}
	
	return 0
}

func (s *AnalyticsService) determineEngagementTrend(userID uint, currentWeekStart time.Time) string {
	// 최근 3주간의 활동 데이터를 분석하여 트렌드 결정
	weeks := []time.Time{
		currentWeekStart.AddDate(0, 0, -14),  // 2주 전
		currentWeekStart.AddDate(0, 0, -7),   // 1주 전
		currentWeekStart,                      // 현재 주
	}
	
	activities := make([]int, 3)
	for i, week := range weeks {
		activities[i] = s.getWeekActivity(userID, week)
	}
	
	// 트렌드 판단
	if activities[2] > activities[1] && activities[1] >= activities[0] {
		return "increasing"
	} else if activities[2] < activities[1] && activities[1] <= activities[0] {
		return "decreasing"
	} else {
		return "stable"
	}
}

// GetUserAchievements 사용자 업적 조회
func (s *AnalyticsService) GetUserAchievements(userID uint) ([]models.Achievement, error) {
	var achievements []models.Achievement
	
	err := s.db.Where("user_id = ?", userID).Order("unlocked_at DESC, created_at DESC").Find(&achievements).Error
	if err != nil {
		return nil, fmt.Errorf("failed to get user achievements: %w", err)
	}
	
	return achievements, nil
}

// UpdateAchievementProgress 업적 진행도 업데이트
func (s *AnalyticsService) UpdateAchievementProgress(userID uint, achievementType string, increment int) error {
	var achievement models.Achievement
	
	err := s.db.Where("user_id = ? AND type = ? AND is_unlocked = false", userID, achievementType).First(&achievement).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 업적이 없으면 생성하지 않음 (미리 정의된 업적만 사용)
			return nil
		}
		return fmt.Errorf("failed to find achievement: %w", err)
	}
	
	// 진행도 업데이트
	achievement.Progress += increment
	
	// 목표 달성 시 언락
	if achievement.Progress >= achievement.MaxProgress && !achievement.IsUnlocked {
		achievement.IsUnlocked = true
		now := time.Now()
		achievement.UnlockedAt = &now
		
		s.logger.Info(fmt.Sprintf("Achievement unlocked for user %d: %s", userID, achievement.Title))
	}
	
	return s.db.Save(&achievement).Error
}