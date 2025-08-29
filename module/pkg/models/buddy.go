package models

import (
	"database/sql/driver"
	"encoding/json"
	"time"
)

// UserBuddy 단골 관계 모델
type UserBuddy struct {
	ID                  uint      `json:"id" gorm:"primaryKey"`
	User1ID             uint      `json:"user1_id" gorm:"not null;index"`
	User2ID             uint      `json:"user2_id" gorm:"not null;index"`
	CreatedAt           time.Time `json:"created_at" gorm:"default:NOW()"`
	LastInteraction     time.Time `json:"last_interaction" gorm:"default:NOW()"`
	InteractionCount    int       `json:"interaction_count" gorm:"default:1"`
	TotalSignals        int       `json:"total_signals" gorm:"default:1"`
	CompatibilityScore  float64   `json:"compatibility_score" gorm:"type:decimal(3,1);default:5.0"`
	Status              string    `json:"status" gorm:"size:20;default:active;index"` // active, paused, blocked
	Notes               string    `json:"notes,omitempty" gorm:"type:text"`

	// Relations
	User1 User `json:"user1,omitempty" gorm:"foreignKey:User1ID"`
	User2 User `json:"user2,omitempty" gorm:"foreignKey:User2ID"`
}

// BuddyStatus 단골 관계 상태
type BuddyStatus string

const (
	BuddyStatusActive  BuddyStatus = "active"
	BuddyStatusPaused  BuddyStatus = "paused"
	BuddyStatusBlocked BuddyStatus = "blocked"
)

// MannerScoreLog 매너 점수 이력
type MannerScoreLog struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	SignalID    *uint     `json:"signal_id,omitempty" gorm:"index"`
	RaterID     uint      `json:"rater_id" gorm:"not null;index"`
	RateeID     uint      `json:"ratee_id" gorm:"not null;index"`
	ScoreChange float64   `json:"score_change" gorm:"type:decimal(3,1);not null"`
	Category    string    `json:"category" gorm:"size:50;not null;index"`
	Reason      string    `json:"reason,omitempty" gorm:"type:text"`
	IsPositive  bool      `json:"is_positive" gorm:"<-:false"` // computed field
	CreatedAt   time.Time `json:"created_at" gorm:"default:NOW();index"`

	// Relations
	Signal *Signal `json:"signal,omitempty" gorm:"foreignKey:SignalID"`
	Rater  User    `json:"rater,omitempty" gorm:"foreignKey:RaterID"`
	Ratee  User    `json:"ratee,omitempty" gorm:"foreignKey:RateeID"`
}

// MannerCategory 매너 평가 카테고리
type MannerCategory string

const (
	MannerCategoryPunctuality   MannerCategory = "punctuality"   // 시간 약속
	MannerCategoryCommunication MannerCategory = "communication" // 소통
	MannerCategoryKindness      MannerCategory = "kindness"      // 친절함
	MannerCategoryParticipation MannerCategory = "participation" // 참여도
)

// SignalInteraction 시그널 참여 상호작용
type SignalInteraction struct {
	ID              uint      `json:"id" gorm:"primaryKey"`
	SignalID        uint      `json:"signal_id" gorm:"not null;index"`
	User1ID         uint      `json:"user1_id" gorm:"not null"`
	User2ID         uint      `json:"user2_id" gorm:"not null"`
	InteractionType string    `json:"interaction_type" gorm:"size:20;default:participated;index"`
	CreatedAt       time.Time `json:"created_at" gorm:"default:NOW()"`

	// Relations
	Signal Signal `json:"signal,omitempty" gorm:"foreignKey:SignalID"`
	User1  User   `json:"user1,omitempty" gorm:"foreignKey:User1ID"`
	User2  User   `json:"user2,omitempty" gorm:"foreignKey:User2ID"`
}

// InteractionType 상호작용 타입
type InteractionType string

const (
	InteractionTypeParticipated InteractionType = "participated"
	InteractionTypeCompleted    InteractionType = "completed"
	InteractionTypeNoShow       InteractionType = "no_show"
)

// BuddyInvitation 단골 초대
type BuddyInvitation struct {
	ID          uint       `json:"id" gorm:"primaryKey"`
	SignalID    uint       `json:"signal_id" gorm:"not null;index"`
	InviterID   uint       `json:"inviter_id" gorm:"not null;index"`
	InviteeID   uint       `json:"invitee_id" gorm:"not null;index"`
	Status      string     `json:"status" gorm:"size:20;default:pending;index"`
	Message     string     `json:"message,omitempty" gorm:"type:text"`
	ExpiresAt   time.Time  `json:"expires_at" gorm:"default:NOW() + INTERVAL '24 hours';index"`
	CreatedAt   time.Time  `json:"created_at" gorm:"default:NOW()"`
	RespondedAt *time.Time `json:"responded_at,omitempty"`

	// Relations
	Signal   Signal `json:"signal,omitempty" gorm:"foreignKey:SignalID"`
	Inviter  User   `json:"inviter,omitempty" gorm:"foreignKey:InviterID"`
	Invitee  User   `json:"invitee,omitempty" gorm:"foreignKey:InviteeID"`
}

// InvitationStatus 초대 상태
type InvitationStatus string

const (
	InvitationStatusPending  InvitationStatus = "pending"
	InvitationStatusAccepted InvitationStatus = "accepted"
	InvitationStatusDeclined InvitationStatus = "declined"
	InvitationStatusExpired  InvitationStatus = "expired"
)

// ActivityTypes 선호 활동 타입 배열 (PostgreSQL array support)
type ActivityTypes []string

// Scan implements the Scanner interface
func (at *ActivityTypes) Scan(value interface{}) error {
	if value == nil {
		*at = ActivityTypes{}
		return nil
	}

	switch v := value.(type) {
	case []byte:
		return json.Unmarshal(v, at)
	case string:
		return json.Unmarshal([]byte(v), at)
	}
	return nil
}

// Value implements the driver Valuer interface
func (at ActivityTypes) Value() (driver.Value, error) {
	return json.Marshal(at)
}

// BuddyRelationship 단골 관계 뷰 (조회용)
type BuddyRelationship struct {
	ID                  uint      `json:"id"`
	UserID              uint      `json:"user_id"`
	BuddyID             uint      `json:"buddy_id"`
	CreatedAt           time.Time `json:"created_at"`
	LastInteraction     time.Time `json:"last_interaction"`
	InteractionCount    int       `json:"interaction_count"`
	TotalSignals        int       `json:"total_signals"`
	CompatibilityScore  float64   `json:"compatibility_score"`
	Status              string    `json:"status"`
	UserName            string    `json:"user_name"`
	BuddyName           string    `json:"buddy_name"`
	UserDisplayName     *string   `json:"user_display_name"`
	BuddyDisplayName    *string   `json:"buddy_display_name"`
	UserMannerScore     float64   `json:"user_manner_score"`
	BuddyMannerScore    float64   `json:"buddy_manner_score"`
}

// PotentialBuddy 단골 후보자
type PotentialBuddy struct {
	UserID             uint     `json:"user_id"`
	Username           string   `json:"username"`
	DisplayName        *string  `json:"display_name"`
	MannerScore        float64  `json:"manner_score"`
	InteractionCount   int      `json:"interaction_count"`
	CommonCategories   []string `json:"common_categories"`
	CompatibilityScore float64  `json:"compatibility_score,omitempty"` // 계산된 궁합 점수
}

// CreateBuddyRequest 단골 관계 생성 요청
type CreateBuddyRequest struct {
	BuddyID uint   `json:"buddy_id" binding:"required"`
	Message string `json:"message,omitempty"`
}

// UpdateBuddyRequest 단골 관계 수정 요청
type UpdateBuddyRequest struct {
	Status             *BuddyStatus `json:"status,omitempty"`
	CompatibilityScore *float64     `json:"compatibility_score,omitempty"`
	Notes              *string      `json:"notes,omitempty"`
}

// CreateMannerLogRequest 매너 점수 평가 요청
type CreateMannerLogRequest struct {
	RateeID     uint           `json:"ratee_id" binding:"required"`
	SignalID    *uint          `json:"signal_id,omitempty"`
	ScoreChange float64        `json:"score_change" binding:"required,min=-5,max=5"`
	Category    MannerCategory `json:"category" binding:"required"`
	Reason      string         `json:"reason,omitempty"`
}

// CreateBuddyInvitationRequest 단골 초대 요청
type CreateBuddyInvitationRequest struct {
	SignalID  uint   `json:"signal_id" binding:"required"`
	InviteeID uint   `json:"invitee_id" binding:"required"`
	Message   string `json:"message,omitempty"`
}

// RespondBuddyInvitationRequest 단골 초대 응답
type RespondBuddyInvitationRequest struct {
	Status InvitationStatus `json:"status" binding:"required,oneof=accepted declined"`
}

// BuddyStats 단골 통계
type BuddyStats struct {
	TotalBuddies         int                            `json:"total_buddies"`
	ActiveBuddies        int                            `json:"active_buddies"`
	TotalInteractions    int                            `json:"total_interactions"`
	AverageCompatibility float64                        `json:"average_compatibility"`
	TopCategories        []string                       `json:"top_categories"`
	MannerScoreHistory   []MannerScoreHistoryPoint      `json:"manner_score_history"`
	RecentBuddies        []BuddyRelationship            `json:"recent_buddies"`
	CategoryBreakdown    map[MannerCategory]float64     `json:"category_breakdown"`
}

// MannerScoreHistoryPoint 매너 점수 히스토리 포인트
type MannerScoreHistoryPoint struct {
	Date  time.Time `json:"date"`
	Score float64   `json:"score"`
}

// GetBuddiesQuery 단골 목록 조회 쿼리
type GetBuddiesQuery struct {
	Status             *BuddyStatus `form:"status"`
	SortBy             string       `form:"sort_by" binding:"omitempty,oneof=created_at last_interaction compatibility_score interaction_count"`
	SortOrder          string       `form:"sort_order" binding:"omitempty,oneof=asc desc"`
	MinCompatibility   *float64     `form:"min_compatibility" binding:"omitempty,min=0,max=10"`
	MinInteractions    *int         `form:"min_interactions" binding:"omitempty,min=1"`
	Page               int          `form:"page" binding:"min=1"`
	Limit              int          `form:"limit" binding:"min=1,max=100"`
}

// Default values for GetBuddiesQuery
func (q *GetBuddiesQuery) SetDefaults() {
	if q.SortBy == "" {
		q.SortBy = "last_interaction"
	}
	if q.SortOrder == "" {
		q.SortOrder = "desc"
	}
	if q.Page == 0 {
		q.Page = 1
	}
	if q.Limit == 0 {
		q.Limit = 20
	}
}