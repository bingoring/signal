package workers

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"signal-be/internal/events"
	"signal-module/pkg/logger"
)

// JobQueue 작업 큐 관리자
type JobQueue struct {
	redis   *redis.Client
	logger  *logger.Logger
	workers map[string]*Worker
	ctx     context.Context
	cancel  context.CancelFunc
}

// NewJobQueue 새로운 작업 큐 생성
func NewJobQueue(redis *redis.Client, logger *logger.Logger) *JobQueue {
	ctx, cancel := context.WithCancel(context.Background())
	
	return &JobQueue{
		redis:   redis,
		logger:  logger,
		workers: make(map[string]*Worker),
		ctx:     ctx,
		cancel:  cancel,
	}
}

// Worker 워커 구조체
type Worker struct {
	ID          string
	QueueName   string
	Handler     EventHandler
	Concurrency int
	BatchSize   int
	IsRunning   bool
	ctx         context.Context
	cancel      context.CancelFunc
}

// EventHandler 이벤트 처리 핸들러 인터페이스
type EventHandler interface {
	Handle(event events.Event) error
	GetName() string
	CanHandle(eventType events.EventType) bool
}

// RegisterWorker 워커 등록
func (jq *JobQueue) RegisterWorker(queueName string, handler EventHandler, concurrency int, batchSize int) {
	ctx, cancel := context.WithCancel(jq.ctx)
	
	worker := &Worker{
		ID:          fmt.Sprintf("%s-%d", queueName, time.Now().Unix()),
		QueueName:   queueName,
		Handler:     handler,
		Concurrency: concurrency,
		BatchSize:   batchSize,
		IsRunning:   false,
		ctx:         ctx,
		cancel:      cancel,
	}

	jq.workers[queueName] = worker
	jq.logger.Info(fmt.Sprintf("Registered worker %s for queue %s with concurrency %d", 
		worker.ID, queueName, concurrency))
}

// StartWorkers 모든 워커 시작
func (jq *JobQueue) StartWorkers() {
	for queueName, worker := range jq.workers {
		go jq.startWorker(worker)
		jq.logger.Info(fmt.Sprintf("Started worker %s for queue %s", worker.ID, queueName))
	}
}

// StopWorkers 모든 워커 중지
func (jq *JobQueue) StopWorkers() {
	jq.cancel() // 모든 워커의 컨텍스트 취소
	
	// 워커들이 정상 종료될 때까지 대기
	timeout := time.After(30 * time.Second)
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			jq.logger.Warn("Worker shutdown timeout reached")
			return
		case <-ticker.C:
			allStopped := true
			for _, worker := range jq.workers {
				if worker.IsRunning {
					allStopped = false
					break
				}
			}
			if allStopped {
				jq.logger.Info("All workers stopped successfully")
				return
			}
		}
	}
}

// startWorker 개별 워커 시작
func (jq *JobQueue) startWorker(worker *Worker) {
	worker.IsRunning = true
	defer func() {
		worker.IsRunning = false
		jq.logger.Info(fmt.Sprintf("Worker %s stopped", worker.ID))
	}()

	// 동시성만큼 고루틴 시작
	for i := 0; i < worker.Concurrency; i++ {
		go jq.processJobs(worker, i)
	}

	// 워커 컨텍스트가 취소될 때까지 대기
	<-worker.ctx.Done()
}

// processJobs 작업 처리 루프
func (jq *JobQueue) processJobs(worker *Worker, workerIndex int) {
	workerID := fmt.Sprintf("%s-%d", worker.ID, workerIndex)
	
	for {
		select {
		case <-worker.ctx.Done():
			jq.logger.Info(fmt.Sprintf("Job processor %s stopping", workerID))
			return
		default:
			// Redis에서 작업 가져오기 (블로킹 모드, 5초 타임아웃)
			result, err := jq.redis.BRPop(worker.ctx, 5*time.Second, worker.QueueName).Result()
			if err != nil {
				if err == redis.Nil {
					// 타임아웃 - 정상적인 상황
					continue
				}
				if err == context.Canceled {
					// 컨텍스트 취소됨
					return
				}
				jq.logger.Error(fmt.Sprintf("Failed to fetch job from queue %s: %v", worker.QueueName, err))
				time.Sleep(5 * time.Second) // 에러 시 잠시 대기
				continue
			}

			if len(result) < 2 {
				continue
			}

			// 이벤트 처리
			if err := jq.processEvent(worker, workerID, result[1]); err != nil {
				jq.logger.Error(fmt.Sprintf("Failed to process event in worker %s: %v", workerID, err))
			}
		}
	}
}

// processEvent 개별 이벤트 처리
func (jq *JobQueue) processEvent(worker *Worker, workerID string, eventData string) error {
	// 이벤트 파싱
	event, err := events.EventFromJSON([]byte(eventData))
	if err != nil {
		jq.logger.Error(fmt.Sprintf("Failed to parse event in worker %s: %v", workerID, err))
		return err
	}

	// 핸들러 확인
	if !worker.Handler.CanHandle(event.GetType()) {
		jq.logger.Warn(fmt.Sprintf("Worker %s cannot handle event type %s", workerID, event.GetType()))
		return nil
	}

	// 이벤트 처리 시작
	startTime := time.Now()
	jq.logger.Info(fmt.Sprintf("Worker %s processing event %s of type %s", 
		workerID, event.GetID(), event.GetType()))

	// 실제 처리
	if err := worker.Handler.Handle(event); err != nil {
		// 재시도 로직
		if event.GetRetry() < event.GetMaxRetry() {
			event.IncRetry()
			return jq.requeueEvent(worker.QueueName, event)
		}
		
		// 최대 재시도 초과 시 DLQ로 이동
		return jq.moveToDeadLetterQueue(event, err)
	}

	// 성공 메트릭 업데이트
	processingTime := time.Since(startTime)
	jq.updateMetrics(worker.QueueName, event.GetType(), "success", processingTime)
	
	jq.logger.Info(fmt.Sprintf("Worker %s completed event %s in %v", 
		workerID, event.GetID(), processingTime))

	return nil
}

// requeueEvent 이벤트 재큐잉
func (jq *JobQueue) requeueEvent(queueName string, event events.Event) error {
	data, err := event.ToJSON()
	if err != nil {
		return err
	}

	// 지연 시간 계산 (지수 백오프)
	delay := time.Duration(event.GetRetry()*event.GetRetry()) * time.Second
	
	// 지연 큐에 추가 (단순화: 즉시 재큐잉)
	ctx := context.Background()
	return jq.redis.LPush(ctx, queueName, data).Err()
}

// moveToDeadLetterQueue Dead Letter Queue로 이동
func (jq *JobQueue) moveToDeadLetterQueue(event events.Event, processingError error) error {
	dlqKey := fmt.Sprintf("dlq:%s", event.GetType())
	
	dlqData := map[string]interface{}{
		"event":            event,
		"processing_error": processingError.Error(),
		"failed_at":        time.Now(),
		"retry_count":      event.GetRetry(),
	}

	data, err := events.StatsEvent{Data: dlqData}.ToJSON()
	if err != nil {
		return err
	}

	ctx := context.Background()
	if err := jq.redis.LPush(ctx, dlqKey, data).Err(); err != nil {
		return err
	}

	jq.logger.Error(fmt.Sprintf("Moved event %s to DLQ after %d retries: %v", 
		event.GetID(), event.GetRetry(), processingError))

	return nil
}

// updateMetrics 메트릭 업데이트
func (jq *JobQueue) updateMetrics(queueName string, eventType events.EventType, status string, processingTime time.Duration) {
	ctx := context.Background()
	
	// 처리 수 증가
	jq.redis.Incr(ctx, fmt.Sprintf("metrics:%s:%s:%s", queueName, eventType, status))
	
	// 처리 시간 기록 (간단한 평균)
	timeKey := fmt.Sprintf("metrics:%s:%s:processing_time", queueName, eventType)
	jq.redis.LPush(ctx, timeKey, processingTime.Milliseconds())
	jq.redis.LTrim(ctx, timeKey, 0, 99) // 최근 100개만 유지
}

// GetWorkerStatus 워커 상태 조회
func (jq *JobQueue) GetWorkerStatus() map[string]interface{} {
	status := make(map[string]interface{})
	
	for queueName, worker := range jq.workers {
		queueLength, _ := jq.redis.LLen(context.Background(), queueName).Result()
		
		status[queueName] = map[string]interface{}{
			"worker_id":   worker.ID,
			"is_running":  worker.IsRunning,
			"concurrency": worker.Concurrency,
			"queue_length": queueLength,
			"handler_name": worker.Handler.GetName(),
		}
	}
	
	return status
}