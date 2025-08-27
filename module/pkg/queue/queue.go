package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"signal-module/pkg/redis"
	redisClient "github.com/redis/go-redis/v9"
)

type Queue struct {
	client *redis.Client
}

func New(redisClient *redis.Client) *Queue {
	return &Queue{client: redisClient}
}

// 작업 타입 정의
type JobType string

const (
	JobSendPushNotification JobType = "send_push_notification"
	JobExpireSignal        JobType = "expire_signal"
	JobExpireChatRoom      JobType = "expire_chat_room"
	JobSendEmail           JobType = "send_email"
	JobUpdateMannerScore   JobType = "update_manner_score"
	JobCleanupData         JobType = "cleanup_data"
)

// 기본 작업 구조체
type Job struct {
	ID        string                 `json:"id"`
	Type      JobType                `json:"type"`
	Payload   map[string]interface{} `json:"payload"`
	CreatedAt time.Time              `json:"created_at"`
	Attempts  int                    `json:"attempts"`
	MaxRetries int                   `json:"max_retries"`
}

// 푸시 알림 작업 페이로드
type PushNotificationPayload struct {
	UserIDs []uint            `json:"user_ids"`
	Title   string            `json:"title"`
	Body    string            `json:"body"`
	Data    map[string]string `json:"data"`
}

// 시그널 만료 작업 페이로드
type ExpireSignalPayload struct {
	SignalID uint `json:"signal_id"`
}

// 채팅방 만료 작업 페이로드
type ExpireChatRoomPayload struct {
	ChatRoomID uint `json:"chat_room_id"`
}

// 이메일 발송 작업 페이로드
type EmailPayload struct {
	To       string            `json:"to"`
	Subject  string            `json:"subject"`
	Template string            `json:"template"`
	Data     map[string]string `json:"data"`
}

// 작업 큐에 추가
func (q *Queue) Push(ctx context.Context, job *Job) error {
	if job.ID == "" {
		job.ID = fmt.Sprintf("%d-%s", time.Now().UnixNano(), job.Type)
	}
	if job.CreatedAt.IsZero() {
		job.CreatedAt = time.Now()
	}
	if job.MaxRetries == 0 {
		job.MaxRetries = 3
	}

	data, err := json.Marshal(job)
	if err != nil {
		return fmt.Errorf("작업 직렬화 실패: %w", err)
	}

	queueKey := fmt.Sprintf("queue:%s", job.Type)
	return q.client.LPush(ctx, queueKey, data)
}

// 작업 큐에서 가져오기 (블로킹)
func (q *Queue) Pop(ctx context.Context, jobType JobType, timeout time.Duration) (*Job, error) {
	queueKey := fmt.Sprintf("queue:%s", jobType)
	
	result, err := q.client.BRPop(ctx, timeout, queueKey)
	if err != nil {
		return nil, err
	}

	if len(result) != 2 {
		return nil, fmt.Errorf("잘못된 큐 응답")
	}

	var job Job
	if err := json.Unmarshal([]byte(result[1]), &job); err != nil {
		return nil, fmt.Errorf("작업 역직렬화 실패: %w", err)
	}

	return &job, nil
}

// 지연 작업 스케줄링
func (q *Queue) Schedule(ctx context.Context, job *Job, executeAt time.Time) error {
	if job.ID == "" {
		job.ID = fmt.Sprintf("%d-%s", time.Now().UnixNano(), job.Type)
	}
	if job.CreatedAt.IsZero() {
		job.CreatedAt = time.Now()
	}

	data, err := json.Marshal(job)
	if err != nil {
		return fmt.Errorf("작업 직렬화 실패: %w", err)
	}

	delayedKey := "delayed_jobs"
	score := float64(executeAt.Unix())
	
	return q.client.GetClient().ZAdd(ctx, delayedKey, redisClient.Z{
		Score:  score,
		Member: data,
	}).Err()
}

// 실행 예정인 지연 작업들을 가져와서 일반 큐로 이동
func (q *Queue) ProcessDelayedJobs(ctx context.Context) error {
	delayedKey := "delayed_jobs"
	now := float64(time.Now().Unix())

	// 현재 시간보다 이른 작업들을 가져옴
	results, err := q.client.GetClient().ZRangeByScore(ctx, delayedKey, &redisClient.ZRangeBy{
		Min: "-inf",
		Max: fmt.Sprintf("%f", now),
	}).Result()

	if err != nil {
		return fmt.Errorf("지연 작업 조회 실패: %w", err)
	}

	for _, jobData := range results {
		var job Job
		if err := json.Unmarshal([]byte(jobData), &job); err != nil {
			log.Printf("지연 작업 역직렬화 실패: %v", err)
			continue
		}

		// 일반 큐로 이동
		if err := q.Push(ctx, &job); err != nil {
			log.Printf("지연 작업을 일반 큐로 이동 실패: %v", err)
			continue
		}

		// 지연 큐에서 제거
		if err := q.client.GetClient().ZRem(ctx, delayedKey, jobData).Err(); err != nil {
			log.Printf("지연 큐에서 작업 제거 실패: %v", err)
		}
	}

	return nil
}

// 실패한 작업을 재시도 큐로 이동
func (q *Queue) Retry(ctx context.Context, job *Job, retryAfter time.Duration) error {
	job.Attempts++
	
	if job.Attempts >= job.MaxRetries {
		return q.moveToFailedQueue(ctx, job)
	}

	retryAt := time.Now().Add(retryAfter)
	return q.Schedule(ctx, job, retryAt)
}

// 실패한 작업을 실패 큐로 이동
func (q *Queue) moveToFailedQueue(ctx context.Context, job *Job) error {
	data, err := json.Marshal(job)
	if err != nil {
		return fmt.Errorf("실패 작업 직렬화 실패: %w", err)
	}

	failedKey := "failed_jobs"
	return q.client.LPush(ctx, failedKey, data)
}

// 큐 상태 조회
func (q *Queue) GetQueueStats(ctx context.Context, jobType JobType) (map[string]int64, error) {
	stats := make(map[string]int64)
	
	queueKey := fmt.Sprintf("queue:%s", jobType)
	queueLen, err := q.client.LLen(ctx, queueKey)
	if err != nil {
		return nil, err
	}
	stats["pending"] = queueLen

	delayedLen, err := q.client.GetClient().ZCard(ctx, "delayed_jobs").Result()
	if err != nil {
		return nil, err
	}
	stats["delayed"] = delayedLen

	failedLen, err := q.client.LLen(ctx, "failed_jobs")
	if err != nil {
		return nil, err
	}
	stats["failed"] = failedLen

	return stats, nil
}

// 편의 메서드들

// 푸시 알림 작업 추가
func (q *Queue) PushNotification(ctx context.Context, userIDs []uint, title, body string, data map[string]string) error {
	payload := map[string]interface{}{
		"user_ids": userIDs,
		"title":    title,
		"body":     body,
		"data":     data,
	}

	job := &Job{
		Type:    JobSendPushNotification,
		Payload: payload,
	}

	return q.Push(ctx, job)
}

// 시그널 만료 작업 스케줄링
func (q *Queue) ScheduleSignalExpiration(ctx context.Context, signalID uint, expiresAt time.Time) error {
	payload := map[string]interface{}{
		"signal_id": signalID,
	}

	job := &Job{
		Type:    JobExpireSignal,
		Payload: payload,
	}

	return q.Schedule(ctx, job, expiresAt)
}

// 채팅방 만료 작업 스케줄링
func (q *Queue) ScheduleChatRoomExpiration(ctx context.Context, chatRoomID uint, expiresAt time.Time) error {
	payload := map[string]interface{}{
		"chat_room_id": chatRoomID,
	}

	job := &Job{
		Type:    JobExpireChatRoom,
		Payload: payload,
	}

	return q.Schedule(ctx, job, expiresAt)
}