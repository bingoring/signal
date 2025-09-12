package events

import (
	"encoding/json"
	"time"
)

// EventType 이벤트 타입 정의
type EventType string

const (
	// 아바타 관련 이벤트
	EventAvatarSet       EventType = "avatar.set"
	EventAvatarFavorite  EventType = "avatar.favorite"
	EventAvatarUnfavorite EventType = "avatar.unfavorite"
	
	// 매너온도 관련 이벤트
	EventMannerUpdate    EventType = "manner.update"
	EventSignalComplete  EventType = "signal.complete"
	EventUserNoShow      EventType = "user.noshow"
	
	// 단골 관련 이벤트
	EventBuddyCreated    EventType = "buddy.created"
	EventBuddyBlocked    EventType = "buddy.blocked"
	EventBuddyUnblocked  EventType = "buddy.unblocked"
	
	// 통계 관련 이벤트
	EventStatsUpdate     EventType = "stats.update"
	EventRankingUpdate   EventType = "ranking.update"
)

// BaseEvent 모든 이벤트의 기본 구조
type BaseEvent struct {
	ID        string    `json:"id"`
	Type      EventType `json:"type"`
	Timestamp time.Time `json:"timestamp"`
	UserID    uint      `json:"user_id,omitempty"`
	Retry     int       `json:"retry"`
	MaxRetry  int       `json:"max_retry"`
}

// AvatarEvent 아바타 관련 이벤트
type AvatarEvent struct {
	BaseEvent
	AvatarID uint   `json:"avatar_id"`
	Action   string `json:"action"` // "set", "favorite", "unfavorite"
	PrevAvatarID uint `json:"prev_avatar_id,omitempty"`
}

// MannerEvent 매너온도 관련 이벤트
type MannerEvent struct {
	BaseEvent
	EventType string  `json:"event_type"` // "signal_complete", "no_show", "rating_received"
	SignalID  uint    `json:"signal_id,omitempty"`
	Rating    float64 `json:"rating,omitempty"`
	IsNoShow  bool    `json:"is_no_show,omitempty"`
}

// BuddyEvent 단골 관계 관련 이벤트
type BuddyEvent struct {
	BaseEvent
	BuddyID  uint   `json:"buddy_id"`
	Action   string `json:"action"` // "created", "blocked", "unblocked"
	SignalID uint   `json:"signal_id,omitempty"`
}

// StatsEvent 통계 관련 이벤트
type StatsEvent struct {
	BaseEvent
	StatsType string                 `json:"stats_type"` // "avatar_popularity", "user_activity", "category_trends"
	Data      map[string]interface{} `json:"data"`
}

// Event 통합 이벤트 인터페이스
type Event interface {
	GetID() string
	GetType() EventType
	GetTimestamp() time.Time
	GetUserID() uint
	GetRetry() int
	GetMaxRetry() int
	IncRetry()
	ToJSON() ([]byte, error)
}

// BaseEvent 메서드 구현
func (e *BaseEvent) GetID() string        { return e.ID }
func (e *BaseEvent) GetType() EventType   { return e.Type }
func (e *BaseEvent) GetTimestamp() time.Time { return e.Timestamp }
func (e *BaseEvent) GetUserID() uint      { return e.UserID }
func (e *BaseEvent) GetRetry() int        { return e.Retry }
func (e *BaseEvent) GetMaxRetry() int     { return e.MaxRetry }
func (e *BaseEvent) IncRetry()            { e.Retry++ }

// AvatarEvent 메서드
func (e *AvatarEvent) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}

// MannerEvent 메서드
func (e *MannerEvent) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}

// BuddyEvent 메서드
func (e *BuddyEvent) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}

// StatsEvent 메서드
func (e *StatsEvent) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}

// EventFromJSON JSON에서 이벤트 복원
func EventFromJSON(data []byte) (Event, error) {
	var baseEvent BaseEvent
	if err := json.Unmarshal(data, &baseEvent); err != nil {
		return nil, err
	}

	switch baseEvent.Type {
	case EventAvatarSet, EventAvatarFavorite, EventAvatarUnfavorite:
		var event AvatarEvent
		err := json.Unmarshal(data, &event)
		return &event, err
		
	case EventMannerUpdate, EventSignalComplete, EventUserNoShow:
		var event MannerEvent
		err := json.Unmarshal(data, &event)
		return &event, err
		
	case EventBuddyCreated, EventBuddyBlocked, EventBuddyUnblocked:
		var event BuddyEvent
		err := json.Unmarshal(data, &event)
		return &event, err
		
	case EventStatsUpdate, EventRankingUpdate:
		var event StatsEvent
		err := json.Unmarshal(data, &event)
		return &event, err
		
	default:
		return &baseEvent, nil
	}
}