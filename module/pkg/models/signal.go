package models

import (
	"time"

	"gorm.io/gorm"
)

type SignalStatus string

const (
	SignalActive    SignalStatus = "active"    // 활성화됨 (참여 가능)
	SignalFull      SignalStatus = "full"      // 정원 마감
	SignalClosed    SignalStatus = "closed"    // 마감됨 (시간 지남)
	SignalCancelled SignalStatus = "cancelled" // 취소됨
	SignalCompleted SignalStatus = "completed" // 완료됨
)

type Signal struct {
	ID          uint         `json:"id" gorm:"primaryKey"`
	CreatorID   uint         `json:"creator_id" gorm:"not null"`
	Title       string       `json:"title" gorm:"size:100;not null"`
	Description string       `json:"description" gorm:"size:500"`
	Category    InterestCategory `json:"category" gorm:"not null"`
	
	// 위치 정보
	Latitude  float64 `json:"latitude" gorm:"not null"`
	Longitude float64 `json:"longitude" gorm:"not null"`
	Address   string  `json:"address" gorm:"size:200"`
	PlaceName string  `json:"place_name" gorm:"size:100"`
	
	// 시간 정보
	ScheduledAt time.Time `json:"scheduled_at" gorm:"not null"`
	ExpiresAt   time.Time `json:"expires_at" gorm:"not null"`
	
	// 인원 정보
	MaxParticipants     int `json:"max_participants" gorm:"not null"`
	CurrentParticipants int `json:"current_participants" gorm:"default:1"`
	MinAge              int `json:"min_age" gorm:"default:0"`
	MaxAge              int `json:"max_age" gorm:"default:100"`
	
	// 상태
	Status SignalStatus `json:"status" gorm:"default:'active'"`
	
	// 추가 설정
	AllowInstantJoin bool   `json:"allow_instant_join" gorm:"default:true"`
	RequireApproval  bool   `json:"require_approval" gorm:"default:false"`
	GenderPreference string `json:"gender_preference" gorm:"size:10"` // any, male, female
	
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	Creator      User                 `json:"creator,omitempty" gorm:"foreignKey:CreatorID"`
	Participants []SignalParticipant  `json:"participants,omitempty" gorm:"foreignKey:SignalID"`
	ChatRoom     *ChatRoom            `json:"chat_room,omitempty" gorm:"foreignKey:SignalID"`
}

type ParticipantStatus string

const (
	ParticipantPending   ParticipantStatus = "pending"   // 승인 대기
	ParticipantApproved  ParticipantStatus = "approved"  // 승인됨
	ParticipantRejected  ParticipantStatus = "rejected"  // 거절됨
	ParticipantLeft      ParticipantStatus = "left"      // 나감
	ParticipantNoShow    ParticipantStatus = "no_show"   // 노쇼
)

type SignalParticipant struct {
	ID       uint              `json:"id" gorm:"primaryKey"`
	SignalID uint              `json:"signal_id" gorm:"not null"`
	UserID   uint              `json:"user_id" gorm:"not null"`
	Status   ParticipantStatus `json:"status" gorm:"default:'pending'"`
	Message  string            `json:"message" gorm:"size:200"`
	JoinedAt *time.Time        `json:"joined_at"`
	LeftAt   *time.Time        `json:"left_at"`
	
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	Signal Signal `json:"-" gorm:"foreignKey:SignalID"`
	User   User   `json:"user,omitempty" gorm:"foreignKey:UserID"`
}

// DTO 구조체들
type CreateSignalRequest struct {
	Title       string           `json:"title" binding:"required,min=5,max=100"`
	Description string           `json:"description" binding:"max=500"`
	Category    InterestCategory `json:"category" binding:"required"`
	
	Latitude  float64 `json:"latitude" binding:"required"`
	Longitude float64 `json:"longitude" binding:"required"`
	Address   string  `json:"address" binding:"max=200"`
	PlaceName string  `json:"place_name" binding:"max=100"`
	
	ScheduledAt time.Time `json:"scheduled_at" binding:"required"`
	
	MaxParticipants     int    `json:"max_participants" binding:"required,min=2,max=20"`
	MinAge              int    `json:"min_age" binding:"min=0,max=100"`
	MaxAge              int    `json:"max_age" binding:"min=0,max=100"`
	AllowInstantJoin    bool   `json:"allow_instant_join"`
	RequireApproval     bool   `json:"require_approval"`
	GenderPreference    string `json:"gender_preference" binding:"oneof=any male female"`
}

type JoinSignalRequest struct {
	Message string `json:"message" binding:"max=200"`
}

type SearchSignalRequest struct {
	Latitude  float64          `json:"latitude"`
	Longitude float64          `json:"longitude"`
	Radius    float64          `json:"radius" binding:"max=50000"` // 최대 50km
	Category  InterestCategory `json:"category"`
	StartTime *time.Time       `json:"start_time"`
	EndTime   *time.Time       `json:"end_time"`
	Page      int              `json:"page" binding:"min=1"`
	Limit     int              `json:"limit" binding:"min=1,max=50"`
}

type SignalWithDistance struct {
	Signal   `json:",inline"`
	Distance float64 `json:"distance"` // 미터 단위
}