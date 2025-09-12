package events

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"signal-module/pkg/logger"
)

// Publisher 이벤트 발행자
type Publisher struct {
	redis  *redis.Client
	logger *logger.Logger
}

// NewPublisher 새로운 이벤트 발행자 생성
func NewPublisher(redis *redis.Client, logger *logger.Logger) *Publisher {
	return &Publisher{
		redis:  redis,
		logger: logger,
	}
}

// PublishAvatarEvent 아바타 이벤트 발행
func (p *Publisher) PublishAvatarEvent(userID, avatarID uint, action string, prevAvatarID uint) error {
	event := &AvatarEvent{
		BaseEvent: BaseEvent{
			ID:        uuid.New().String(),
			Type:      EventAvatarSet,
			Timestamp: time.Now(),
			UserID:    userID,
			Retry:     0,
			MaxRetry:  3,
		},
		AvatarID:     avatarID,
		Action:       action,
		PrevAvatarID: prevAvatarID,
	}

	// 액션에 따라 이벤트 타입 설정
	switch action {
	case "favorite":
		event.Type = EventAvatarFavorite
	case "unfavorite":
		event.Type = EventAvatarUnfavorite
	default:
		event.Type = EventAvatarSet
	}

	return p.publishEvent(event, "avatar_events")
}

// PublishMannerEvent 매너온도 이벤트 발행
func (p *Publisher) PublishMannerEvent(userID uint, eventType string, signalID uint, rating float64, isNoShow bool) error {
	var evtType EventType
	switch eventType {
	case "signal_complete":
		evtType = EventSignalComplete
	case "no_show":
		evtType = EventUserNoShow
	default:
		evtType = EventMannerUpdate
	}

	event := &MannerEvent{
		BaseEvent: BaseEvent{
			ID:        uuid.New().String(),
			Type:      evtType,
			Timestamp: time.Now(),
			UserID:    userID,
			Retry:     0,
			MaxRetry:  3,
		},
		EventType: eventType,
		SignalID:  signalID,
		Rating:    rating,
		IsNoShow:  isNoShow,
	}

	return p.publishEvent(event, "manner_events")
}

// PublishBuddyEvent 단골 관계 이벤트 발행
func (p *Publisher) PublishBuddyEvent(userID, buddyID uint, action string, signalID uint) error {
	var evtType EventType
	switch action {
	case "created":
		evtType = EventBuddyCreated
	case "blocked":
		evtType = EventBuddyBlocked
	case "unblocked":
		evtType = EventBuddyUnblocked
	default:
		evtType = EventBuddyCreated
	}

	event := &BuddyEvent{
		BaseEvent: BaseEvent{
			ID:        uuid.New().String(),
			Type:      evtType,
			Timestamp: time.Now(),
			UserID:    userID,
			Retry:     0,
			MaxRetry:  3,
		},
		BuddyID:  buddyID,
		Action:   action,
		SignalID: signalID,
	}

	return p.publishEvent(event, "buddy_events")
}

// PublishStatsEvent 통계 이벤트 발행
func (p *Publisher) PublishStatsEvent(userID uint, statsType string, data map[string]interface{}) error {
	event := &StatsEvent{
		BaseEvent: BaseEvent{
			ID:        uuid.New().String(),
			Type:      EventStatsUpdate,
			Timestamp: time.Now(),
			UserID:    userID,
			Retry:     0,
			MaxRetry:  3,
		},
		StatsType: statsType,
		Data:      data,
	}

	return p.publishEvent(event, "stats_events")
}

// publishEvent 내부 이벤트 발행 메서드
func (p *Publisher) publishEvent(event Event, queue string) error {
	// JSON 직렬화
	data, err := event.ToJSON()
	if err != nil {
		p.logger.Error(fmt.Sprintf("Failed to serialize event %s: %v", event.GetID(), err))
		return fmt.Errorf("failed to serialize event: %w", err)
	}

	// Redis 큐에 푸시
	ctx := p.redis.Context()
	if err := p.redis.LPush(ctx, queue, data).Err(); err != nil {
		p.logger.Error(fmt.Sprintf("Failed to publish event %s to queue %s: %v", event.GetID(), queue, err))
		return fmt.Errorf("failed to publish event: %w", err)
	}

	// 메트릭 업데이트 (선택사항)
	p.redis.Incr(ctx, fmt.Sprintf("events:published:%s", event.GetType()))

	p.logger.Info(fmt.Sprintf("Published event %s of type %s to queue %s", 
		event.GetID(), event.GetType(), queue))

	return nil
}

// GetQueueLength 큐 길이 조회
func (p *Publisher) GetQueueLength(queue string) (int64, error) {
	ctx := p.redis.Context()
	return p.redis.LLen(ctx, queue).Result()
}

// GetEventMetrics 이벤트 메트릭 조회
func (p *Publisher) GetEventMetrics() (map[string]int64, error) {
	ctx := p.redis.Context()
	metrics := make(map[string]int64)

	// 모든 이벤트 타입별 발행 수 조회
	eventTypes := []EventType{
		EventAvatarSet, EventAvatarFavorite, EventAvatarUnfavorite,
		EventMannerUpdate, EventSignalComplete, EventUserNoShow,
		EventBuddyCreated, EventBuddyBlocked, EventBuddyUnblocked,
		EventStatsUpdate, EventRankingUpdate,
	}

	for _, eventType := range eventTypes {
		key := fmt.Sprintf("events:published:%s", eventType)
		count, err := p.redis.Get(ctx, key).Int64()
		if err != nil && err != redis.Nil {
			continue
		}
		metrics[string(eventType)] = count
	}

	return metrics, nil
}