package models

import (
	"time"
)

// UserAnalytics 사용자 분석 데이터
type UserAnalytics struct {
	ID              uint                      `gorm:"primaryKey" json:"id"`
	UserID          uint                      `gorm:"not null;index" json:"user_id"`
	WeekStartDate   time.Time                 `gorm:"not null;index" json:"week_start_date"`
	WeeklyStats     WeeklyActivityStats       `gorm:"type:jsonb" json:"weekly_stats"`
	SocialImpact    SocialImpactMetrics       `gorm:"type:jsonb" json:"social_impact"`
	TrendAnalysis   TrendData                 `gorm:"type:jsonb" json:"trend_analysis"`
	CreatedAt       time.Time                 `json:"created_at"`
	UpdatedAt       time.Time                 `json:"updated_at"`
}

// WeeklyActivityStats 주간 활동 통계
type WeeklyActivityStats struct {
	SignalsCreated      int     `json:"signals_created"`
	SignalsJoined       int     `json:"signals_joined"`
	TotalParticipation  int     `json:"total_participation"`
	CompletionRate      float64 `json:"completion_rate"`
	AverageRating       float64 `json:"average_rating"`
	NewBuddiesMade      int     `json:"new_buddies_made"`
	MessagesExchanged   int     `json:"messages_exchanged"`
	FavoriteCategories  []string `json:"favorite_categories"`
}

// SocialImpactMetrics 사회적 영향 메트릭
type SocialImpactMetrics struct {
	CommunityScore      float64 `json:"community_score"`
	InfluenceRating     float64 `json:"influence_rating"`
	HelpfulnessScore    float64 `json:"helpfulness_score"`
	LeadershipEvents    int     `json:"leadership_events"`
	PositiveFeedback    int     `json:"positive_feedback"`
	MentorshipActivity  int     `json:"mentorship_activity"`
}

// TrendData 트렌드 분석 데이터
type TrendData struct {
	WeekOverWeekGrowth    float64           `json:"week_over_week_growth"`
	PopularTimeSlots      []TimeSlot        `json:"popular_time_slots"`
	PreferredLocations    []LocationTrend   `json:"preferred_locations"`
	SocialNetworkGrowth   float64           `json:"social_network_growth"`
	EngagementTrend       string            `json:"engagement_trend"` // "increasing", "stable", "decreasing"
}

// TimeSlot 시간대별 활동 패턴
type TimeSlot struct {
	Hour          int     `json:"hour"`
	DayOfWeek     int     `json:"day_of_week"`
	ActivityCount int     `json:"activity_count"`
	Probability   float64 `json:"probability"`
}

// LocationTrend 위치별 선호도 트렌드
type LocationTrend struct {
	District        string  `json:"district"`
	VisitFrequency  int     `json:"visit_frequency"`
	PreferenceScore float64 `json:"preference_score"`
	Category        string  `json:"category"`
}

// Achievement 업적 시스템
type Achievement struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	UserID      uint      `gorm:"not null;index" json:"user_id"`
	Type        string    `gorm:"not null" json:"type"`
	Title       string    `gorm:"not null" json:"title"`
	Description string    `json:"description"`
	IconURL     string    `json:"icon_url"`
	Category    string    `gorm:"not null" json:"category"`
	Difficulty  string    `gorm:"not null" json:"difficulty"` // "bronze", "silver", "gold", "platinum"
	Progress    int       `gorm:"default:0" json:"progress"`
	MaxProgress int       `gorm:"not null" json:"max_progress"`
	IsUnlocked  bool      `gorm:"default:false" json:"is_unlocked"`
	UnlockedAt  *time.Time `json:"unlocked_at"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// RecommendationCache 추천 시스템 캐시
type RecommendationCache struct {
	ID              uint                  `gorm:"primaryKey" json:"id"`
	UserID          uint                  `gorm:"not null;uniqueIndex:idx_user_type" json:"user_id"`
	Type            string                `gorm:"not null;uniqueIndex:idx_user_type" json:"type"` // "signals", "buddies", "locations"
	Recommendations RecommendationData    `gorm:"type:jsonb" json:"recommendations"`
	Score           float64               `gorm:"index" json:"score"`
	GeneratedAt     time.Time             `gorm:"not null" json:"generated_at"`
	ExpiresAt       time.Time             `gorm:"not null;index" json:"expires_at"`
	CreatedAt       time.Time             `json:"created_at"`
	UpdatedAt       time.Time             `json:"updated_at"`
}

// RecommendationData 추천 데이터
type RecommendationData struct {
	Items           []RecommendationItem  `json:"items"`
	Reasoning       string                `json:"reasoning"`
	ConfidenceScore float64               `json:"confidence_score"`
	Metadata        map[string]interface{} `json:"metadata"`
}

// RecommendationItem 개별 추천 항목
type RecommendationItem struct {
	ID          uint                   `json:"id"`
	Type        string                 `json:"type"`
	Title       string                 `json:"title"`
	Description string                 `json:"description"`
	Score       float64                `json:"score"`
	Reasoning   string                 `json:"reasoning"`
	Metadata    map[string]interface{} `json:"metadata"`
}

// UserInteractionLog 사용자 상호작용 로그 (ML 학습용)
type UserInteractionLog struct {
	ID            uint                   `gorm:"primaryKey" json:"id"`
	UserID        uint                   `gorm:"not null;index" json:"user_id"`
	InteractionType string               `gorm:"not null;index" json:"interaction_type"`
	TargetID      uint                   `json:"target_id"`
	TargetType    string                 `json:"target_type"`
	Action        string                 `gorm:"not null" json:"action"`
	Context       map[string]interface{} `gorm:"type:jsonb" json:"context"`
	Duration      int                    `json:"duration"` // seconds
	Success       bool                   `gorm:"default:true" json:"success"`
	Timestamp     time.Time              `gorm:"not null;index" json:"timestamp"`
	CreatedAt     time.Time              `json:"created_at"`
}

// PersonalityInsight 개성 분석 인사이트
type PersonalityInsight struct {
	ID                uint                   `gorm:"primaryKey" json:"id"`
	UserID            uint                   `gorm:"not null;index" json:"user_id"`
	PersonalityType   string                 `gorm:"not null" json:"personality_type"`
	Traits            PersonalityTraits      `gorm:"type:jsonb" json:"traits"`
	Strengths         []string               `json:"strengths"`
	ImprovementAreas  []string               `json:"improvement_areas"`
	CompatibilityMap  map[string]float64     `gorm:"type:jsonb" json:"compatibility_map"`
	LastAnalysis      time.Time              `gorm:"not null" json:"last_analysis"`
	AnalysisVersion   string                 `gorm:"not null" json:"analysis_version"`
	Metadata          map[string]interface{} `gorm:"type:jsonb" json:"metadata"`
	CreatedAt         time.Time              `json:"created_at"`
	UpdatedAt         time.Time              `json:"updated_at"`
}

// PersonalityTraits 성격 특성
type PersonalityTraits struct {
	Extroversion    float64 `json:"extroversion"`     // 외향성
	Agreeableness   float64 `json:"agreeableness"`    // 친화성
	Conscientiousness float64 `json:"conscientiousness"` // 성실성
	Neuroticism     float64 `json:"neuroticism"`      // 신경성
	Openness        float64 `json:"openness"`         // 개방성
	Leadership      float64 `json:"leadership"`       // 리더십
	Creativity      float64 `json:"creativity"`       // 창의성
	Reliability     float64 `json:"reliability"`      // 신뢰성
}

// CommunityEngagement 커뮤니티 참여도
type CommunityEngagement struct {
	ID                uint                   `gorm:"primaryKey" json:"id"`
	UserID            uint                   `gorm:"not null;index" json:"user_id"`
	CommunityType     string                 `gorm:"not null" json:"community_type"`
	EngagementLevel   string                 `gorm:"not null" json:"engagement_level"` // "newcomer", "regular", "leader", "veteran"
	ContributionScore float64                `json:"contribution_score"`
	EventsHosted      int                    `gorm:"default:0" json:"events_hosted"`
	EventsAttended    int                    `gorm:"default:0" json:"events_attended"`
	MentorshipCount   int                    `gorm:"default:0" json:"mentorship_count"`
	CommunityFeedback CommunityFeedbackData  `gorm:"type:jsonb" json:"community_feedback"`
	BadgesEarned      []string               `json:"badges_earned"`
	LastActive        time.Time              `json:"last_active"`
	CreatedAt         time.Time              `json:"created_at"`
	UpdatedAt         time.Time              `json:"updated_at"`
}

// CommunityFeedbackData 커뮤니티 피드백 데이터
type CommunityFeedbackData struct {
	PositiveCount   int                    `json:"positive_count"`
	NeutralCount    int                    `json:"neutral_count"`
	NegativeCount   int                    `json:"negative_count"`
	AverageRating   float64                `json:"average_rating"`
	RecentComments  []string               `json:"recent_comments"`
	TrendDirection  string                 `json:"trend_direction"`
	Metadata        map[string]interface{} `json:"metadata"`
}