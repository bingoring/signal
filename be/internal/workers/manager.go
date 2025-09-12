package workers

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
	"signal-be/internal/events"
	"signal-module/pkg/logger"
)

// Manager 워커 시스템 매니저
type Manager struct {
	db        *gorm.DB
	redis     *redis.Client
	logger    *logger.Logger
	
	// 구성 요소들
	jobQueue  *JobQueue
	scheduler *Scheduler
	publisher *events.Publisher
	
	// 워커들
	mannerWorker *MannerWorker
	avatarWorker *AvatarWorker
	
	// 상태 관리
	isRunning bool
	mu        sync.RWMutex
	ctx       context.Context
	cancel    context.CancelFunc
}

// ManagerConfig 매니저 설정
type ManagerConfig struct {
	// 워커 동시성 설정
	MannerWorkerConcurrency int
	AvatarWorkerConcurrency int
	
	// 배치 크기 설정
	MannerWorkerBatchSize int
	AvatarWorkerBatchSize int
	
	// 스케줄러 활성화
	EnableScheduler bool
}

// DefaultManagerConfig 기본 설정
func DefaultManagerConfig() *ManagerConfig {
	return &ManagerConfig{
		MannerWorkerConcurrency: 3,
		AvatarWorkerConcurrency: 2,
		MannerWorkerBatchSize:   10,
		AvatarWorkerBatchSize:   20,
		EnableScheduler:         true,
	}
}

// NewManager 새로운 워커 매니저 생성
func NewManager(db *gorm.DB, redis *redis.Client, logger *logger.Logger, config *ManagerConfig) *Manager {
	if config == nil {
		config = DefaultManagerConfig()
	}

	ctx, cancel := context.WithCancel(context.Background())

	// 워커 생성
	mannerWorker := NewMannerWorker(db, logger)
	avatarWorker := NewAvatarWorker(db, logger)

	// 구성 요소 생성
	jobQueue := NewJobQueue(redis, logger)
	scheduler := NewScheduler(db, logger)
	publisher := events.NewPublisher(redis, logger)

	manager := &Manager{
		db:           db,
		redis:        redis,
		logger:       logger,
		jobQueue:     jobQueue,
		scheduler:    scheduler,
		publisher:    publisher,
		mannerWorker: mannerWorker,
		avatarWorker: avatarWorker,
		ctx:          ctx,
		cancel:       cancel,
	}

	// 워커 등록
	manager.registerWorkers(config)

	return manager
}

// registerWorkers 워커들을 작업 큐에 등록
func (m *Manager) registerWorkers(config *ManagerConfig) {
	// 매너온도 워커 등록
	m.jobQueue.RegisterWorker(
		"manner_events",
		m.mannerWorker,
		config.MannerWorkerConcurrency,
		config.MannerWorkerBatchSize,
	)

	// 아바타 워커 등록
	m.jobQueue.RegisterWorker(
		"avatar_events",
		m.avatarWorker,
		config.AvatarWorkerConcurrency,
		config.AvatarWorkerBatchSize,
	)

	m.logger.Info("All workers registered successfully")
}

// Start 워커 시스템 시작
func (m *Manager) Start() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.isRunning {
		return fmt.Errorf("worker manager is already running")
	}

	m.logger.Info("Starting worker system...")

	// 1. 작업 큐 워커들 시작
	m.jobQueue.StartWorkers()
	
	// 2. 스케줄러 시작
	if err := m.scheduler.Start(); err != nil {
		m.logger.Error(fmt.Sprintf("Failed to start scheduler: %v", err))
		return fmt.Errorf("failed to start scheduler: %w", err)
	}

	// 3. 상태 모니터링 시작
	go m.startMonitoring()

	// 4. 헬스체크 시작
	go m.startHealthCheck()

	m.isRunning = true
	m.logger.Info("Worker system started successfully")

	return nil
}

// Stop 워커 시스템 중지
func (m *Manager) Stop() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if !m.isRunning {
		return fmt.Errorf("worker manager is not running")
	}

	m.logger.Info("Stopping worker system...")

	// 1. 컨텍스트 취소 (모니터링 중지)
	m.cancel()

	// 2. 스케줄러 중지
	if err := m.scheduler.Stop(); err != nil {
		m.logger.Warn(fmt.Sprintf("Error stopping scheduler: %v", err))
	}

	// 3. 작업 큐 워커들 중지
	m.jobQueue.StopWorkers()

	// 4. 진행 중인 작업들이 완료될 때까지 대기
	m.waitForCompletion()

	m.isRunning = false
	m.logger.Info("Worker system stopped successfully")

	return nil
}

// waitForCompletion 진행 중인 작업 완료 대기
func (m *Manager) waitForCompletion() {
	timeout := time.After(60 * time.Second)
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			m.logger.Warn("Worker shutdown timeout reached")
			return
		case <-ticker.C:
			status := m.jobQueue.GetWorkerStatus()
			allStopped := true

			for queueName, workerInfo := range status {
				if workerStatus, ok := workerInfo.(map[string]interface{}); ok {
					if isRunning, exists := workerStatus["is_running"]; exists && isRunning.(bool) {
						allStopped = false
						m.logger.Info(fmt.Sprintf("Waiting for worker %s to stop", queueName))
						break
					}
				}
			}

			if allStopped {
				m.logger.Info("All workers stopped")
				return
			}
		}
	}
}

// startMonitoring 시스템 모니터링 시작
func (m *Manager) startMonitoring() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-m.ctx.Done():
			m.logger.Info("Stopping system monitoring")
			return
		case <-ticker.C:
			m.logSystemStatus()
		}
	}
}

// startHealthCheck 헬스체크 시작
func (m *Manager) startHealthCheck() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-m.ctx.Done():
			m.logger.Info("Stopping health check")
			return
		case <-ticker.C:
			if err := m.performHealthCheck(); err != nil {
				m.logger.Error(fmt.Sprintf("Health check failed: %v", err))
			}
		}
	}
}

// logSystemStatus 시스템 상태 로깅
func (m *Manager) logSystemStatus() {
	// 워커 상태
	workerStatus := m.jobQueue.GetWorkerStatus()
	
	// 스케줄러 상태
	schedulerStatus := m.scheduler.GetJobStatus()
	
	// Redis 큐 길이
	queueLengths := make(map[string]int64)
	queues := []string{"manner_events", "avatar_events"}
	
	for _, queue := range queues {
		length, err := m.publisher.GetQueueLength(queue)
		if err != nil {
			length = -1
		}
		queueLengths[queue] = length
	}

	m.logger.Info(fmt.Sprintf("System Status - Workers: %d, Scheduler Jobs: %d, Queue Lengths: %+v",
		len(workerStatus), 
		schedulerStatus["total_jobs"], 
		queueLengths))
}

// performHealthCheck 헬스체크 수행
func (m *Manager) performHealthCheck() error {
	// Redis 연결 확인
	ctx := context.Background()
	if err := m.redis.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("redis health check failed: %w", err)
	}

	// 데이터베이스 연결 확인
	sqlDB, err := m.db.DB()
	if err != nil {
		return fmt.Errorf("failed to get database connection: %w", err)
	}
	
	if err := sqlDB.Ping(); err != nil {
		return fmt.Errorf("database health check failed: %w", err)
	}

	return nil
}

// GetSystemStatus 시스템 상태 조회
func (m *Manager) GetSystemStatus() map[string]interface{} {
	m.mu.RLock()
	defer m.mu.RUnlock()

	status := make(map[string]interface{})
	status["is_running"] = m.isRunning
	status["workers"] = m.jobQueue.GetWorkerStatus()
	status["scheduler"] = m.scheduler.GetJobStatus()

	// 이벤트 메트릭
	if metrics, err := m.publisher.GetEventMetrics(); err == nil {
		status["event_metrics"] = metrics
	}

	// 큐 길이
	queueLengths := make(map[string]int64)
	queues := []string{"manner_events", "avatar_events"}
	
	for _, queue := range queues {
		if length, err := m.publisher.GetQueueLength(queue); err == nil {
			queueLengths[queue] = length
		}
	}
	status["queue_lengths"] = queueLengths

	return status
}

// PublishAvatarEvent 아바타 이벤트 발행
func (m *Manager) PublishAvatarEvent(userID, avatarID uint, action string, prevAvatarID uint) error {
	return m.publisher.PublishAvatarEvent(userID, avatarID, action, prevAvatarID)
}

// PublishMannerEvent 매너온도 이벤트 발행
func (m *Manager) PublishMannerEvent(userID uint, eventType string, signalID uint, rating float64, isNoShow bool) error {
	return m.publisher.PublishMannerEvent(userID, eventType, signalID, rating, isNoShow)
}

// PublishBuddyEvent 단골 관계 이벤트 발행
func (m *Manager) PublishBuddyEvent(userID, buddyID uint, action string, signalID uint) error {
	return m.publisher.PublishBuddyEvent(userID, buddyID, action, signalID)
}

// PublishStatsEvent 통계 이벤트 발행
func (m *Manager) PublishStatsEvent(userID uint, statsType string, data map[string]interface{}) error {
	return m.publisher.PublishStatsEvent(userID, statsType, data)
}

// TriggerMannerBatchRecalculation 매너온도 배치 재계산 트리거
func (m *Manager) TriggerMannerBatchRecalculation() error {
	m.logger.Info("Triggering manual manner temperature batch recalculation")
	
	go func() {
		if err := m.mannerWorker.BatchRecalculateAll(); err != nil {
			m.logger.Error(fmt.Sprintf("Manual manner batch recalculation failed: %v", err))
		} else {
			m.logger.Info("Manual manner batch recalculation completed")
		}
	}()
	
	return nil
}

// TriggerAvatarPopularityUpdate 아바타 인기도 업데이트 트리거
func (m *Manager) TriggerAvatarPopularityUpdate() error {
	m.logger.Info("Triggering manual avatar popularity update")
	
	go func() {
		if err := m.avatarWorker.BatchUpdatePopularityRankings(); err != nil {
			m.logger.Error(fmt.Sprintf("Manual avatar popularity update failed: %v", err))
		} else {
			m.logger.Info("Manual avatar popularity update completed")
		}
	}()
	
	return nil
}