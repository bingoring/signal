package models

import (
	"time"

	"gorm.io/gorm"
)

type ChatRoomStatus string

const (
	ChatRoomActive    ChatRoomStatus = "active"     // 활성화 - 채팅 진행 중
	ChatRoomMeeting   ChatRoomStatus = "meeting"    // 모임 진행 중 - 시그널 시작 시간 도달
	ChatRoomCompleted ChatRoomStatus = "completed"  // 모임 완료 - 성공적 마무리
	ChatRoomExpired   ChatRoomStatus = "expired"    // 만료됨 - 24시간 후 자동 만료
	ChatRoomClosed    ChatRoomStatus = "closed"     // 강제 종료 - 관리자 또는 주최자가 종료
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
	MessageText        MessageType = "text"         // 텍스트 메시지
	MessageImage       MessageType = "image"        // 이미지
	MessageLocation    MessageType = "location"     // 위치 공유
	MessageQuickReply  MessageType = "quick_reply"  // 빠른 응답 ("도착했어요", "5분 늦을게요" 등)
	MessageSystem      MessageType = "system"       // 시스템 메시지
	MessageJoin        MessageType = "join"         // 참여 알림
	MessageLeave       MessageType = "leave"        // 나가기 알림
	MessageCountdown   MessageType = "countdown"    // 모임 카운트다운
	MessageStatus      MessageType = "status"       // 모임 상태 변경
)

type ChatMessage struct {
	ID         uint        `json:"id" gorm:"primaryKey"`
	ChatRoomID uint        `json:"chat_room_id" gorm:"not null"`
	UserID     *uint       `json:"user_id"` // nil이면 시스템 메시지
	Type       MessageType `json:"type" gorm:"default:'text'"`
	Content    string      `json:"content" gorm:"size:1000;not null"`
	ImageURL   string      `json:"image_url"`
	
	// 위치 정보 (location 타입일 때)
	Latitude  *float64 `json:"latitude,omitempty"`
	Longitude *float64 `json:"longitude,omitempty"`
	Address   string   `json:"address,omitempty" gorm:"size:500"`
	
	// 빠른 응답 타입 (quick_reply 타입일 때)
	QuickReplyType string `json:"quick_reply_type,omitempty" gorm:"size:50"` // "arrived", "late_5min", "late_10min", "cancel" 등
	
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
	Type           MessageType `json:"type" binding:"required,oneof=text image location quick_reply"`
	Content        string      `json:"content" binding:"required,max=1000"`
	ImageURL       string      `json:"image_url"`
	Latitude       *float64    `json:"latitude,omitempty"`
	Longitude      *float64    `json:"longitude,omitempty"`
	Address        string      `json:"address,omitempty"`
	QuickReplyType string      `json:"quick_reply_type,omitempty"`
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
	
	// 위치 정보
	Latitude  *float64 `json:"latitude,omitempty"`
	Longitude *float64 `json:"longitude,omitempty"`
	Address   string   `json:"address,omitempty"`
	
	// 빠른 응답
	QuickReplyType string `json:"quick_reply_type,omitempty"`
	
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