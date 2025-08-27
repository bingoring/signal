package models

import (
	"time"

	"gorm.io/gorm"
)

type ChatRoomStatus string

const (
	ChatRoomActive  ChatRoomStatus = "active"  // 활성화
	ChatRoomExpired ChatRoomStatus = "expired" // 만료됨 (24시간 후)
	ChatRoomClosed  ChatRoomStatus = "closed"  // 강제 종료
)

type ChatRoom struct {
	ID       uint           `json:"id" gorm:"primaryKey"`
	SignalID uint           `json:"signal_id" gorm:"uniqueIndex;not null"`
	Name     string         `json:"name" gorm:"size:100"`
	Status   ChatRoomStatus `json:"status" gorm:"default:'active'"`
	
	// 자동 소멸 시간 (시그널 시작 24시간 후)
	ExpiresAt *time.Time `json:"expires_at"`
	
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	Signal   Signal        `json:"signal,omitempty" gorm:"foreignKey:SignalID"`
	Messages []ChatMessage `json:"messages,omitempty" gorm:"foreignKey:ChatRoomID"`
}

type MessageType string

const (
	MessageText   MessageType = "text"   // 텍스트 메시지
	MessageImage  MessageType = "image"  // 이미지
	MessageSystem MessageType = "system" // 시스템 메시지
	MessageJoin   MessageType = "join"   // 참여 알림
	MessageLeave  MessageType = "leave"  // 나가기 알림
)

type ChatMessage struct {
	ID         uint        `json:"id" gorm:"primaryKey"`
	ChatRoomID uint        `json:"chat_room_id" gorm:"not null"`
	UserID     *uint       `json:"user_id"` // nil이면 시스템 메시지
	Type       MessageType `json:"type" gorm:"default:'text'"`
	Content    string      `json:"content" gorm:"size:1000;not null"`
	ImageURL   string      `json:"image_url"`
	
	// 메시지 상태
	IsEdited bool       `json:"is_edited" gorm:"default:false"`
	EditedAt *time.Time `json:"edited_at"`
	
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	ChatRoom ChatRoom `json:"-" gorm:"foreignKey:ChatRoomID"`
	User     *User    `json:"user,omitempty" gorm:"foreignKey:UserID"`
}

// DTO 구조체들
type SendMessageRequest struct {
	Type     MessageType `json:"type" binding:"required,oneof=text image"`
	Content  string      `json:"content" binding:"required,max=1000"`
	ImageURL string      `json:"image_url"`
}

type ChatRoomInfo struct {
	ID            uint                `json:"id"`
	SignalID      uint                `json:"signal_id"`
	Name          string              `json:"name"`
	Status        ChatRoomStatus      `json:"status"`
	ExpiresAt     *time.Time          `json:"expires_at"`
	ParticipantCount int              `json:"participant_count"`
	LastMessage   *ChatMessage        `json:"last_message,omitempty"`
	CreatedAt     time.Time           `json:"created_at"`
	UpdatedAt     time.Time           `json:"updated_at"`
}

type MessageWithUser struct {
	ID         uint        `json:"id"`
	ChatRoomID uint        `json:"chat_room_id"`
	Type       MessageType `json:"type"`
	Content    string      `json:"content"`
	ImageURL   string      `json:"image_url"`
	IsEdited   bool        `json:"is_edited"`
	EditedAt   *time.Time  `json:"edited_at"`
	CreatedAt  time.Time   `json:"created_at"`
	
	// 사용자 정보 (시스템 메시지가 아닐 때만)
	User *struct {
		ID          uint   `json:"id"`
		Username    string `json:"username"`
		DisplayName string `json:"display_name"`
		Avatar      string `json:"avatar"`
	} `json:"user,omitempty"`
}