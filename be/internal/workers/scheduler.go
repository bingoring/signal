package workers

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/robfig/cron/v3"
	"gorm.io/gorm"
	"signal-module/pkg/logger"
)

// Scheduler 스케줄러 구조체
type Scheduler struct {
	cron   *cron.Cron
	db     *gorm.DB
	logger *logger.Logger
	
	// 워커들
	mannerWorker *MannerWorker
	avatarWorker *AvatarWorker
	
	// 실행 상태 추적
	isRunning bool
	mu        sync.RWMutex
	jobs      map[string]cron.EntryID
}

// NewScheduler 새로운 스케줄러 생성
func NewScheduler(db *gorm.DB, logger *logger.Logger) *Scheduler {
	// 시간대 설정 (KST)
	location, err := time.LoadLocation("Asia/Seoul")
	if err != nil {
		location = time.UTC
		logger.Warn("Failed to load Asia/Seoul timezone, using UTC")
	}

	return &Scheduler{
		cron:         cron.New(cron.WithLocation(location), cron.WithSeconds()),
		db:           db,
		logger:       logger,
		mannerWorker: NewMannerWorker(db, logger),
		avatarWorker: NewAvatarWorker(db, logger),
		jobs:         make(map[string]cron.EntryID),
	}
}

// Start 스케줄러 시작
func (s *Scheduler) Start() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.isRunning {
		return fmt.Errorf("scheduler is already running")
	}

	// 배치 작업 스케줄링
	if err := s.scheduleJobs(); err != nil {
		return fmt.Errorf("failed to schedule jobs: %w", err)
	}

	s.cron.Start()
	s.isRunning = true

	s.logger.Info("Scheduler started successfully")
	return nil
}

// Stop 스케줄러 중지
func (s *Scheduler) Stop() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if !s.isRunning {
		return fmt.Errorf("scheduler is not running")
	}

	// 모든 작업 완료까지 최대 30초 대기
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	stopCtx := s.cron.Stop()
	
	select {
	case <-stopCtx.Done():
		s.isRunning = false
		s.logger.Info("Scheduler stopped gracefully")
		return nil
	case <-ctx.Done():
		s.isRunning = false
		s.logger.Warn("Scheduler stopped with timeout")
		return fmt.Errorf("scheduler stop timeout")
	}
}

// scheduleJobs 배치 작업들을 스케줄링
func (s *Scheduler) scheduleJobs() error {
	jobs := []struct {
		name     string
		schedule string
		job      func()
	}{
		{
			name:     "manner_temperature_batch_recalculation",
			schedule: "0 0 2 * * *", // 매일 오전 2시
			job:      s.runMannerTemperatureBatch,
		},
		{
			name:     "avatar_popularity_ranking_update",
			schedule: "0 30 3 * * *", // 매일 오전 3시 30분
			job:      s.runAvatarPopularityUpdate,
		},
		{
			name:     "weekly_stats_calculation",
			schedule: "0 0 4 * * 1", // 매주 월요일 오전 4시
			job:      s.runWeeklyStatsCalculation,
		},
		{
			name:     "monthly_cleanup",
			schedule: "0 0 5 1 * *", // 매월 1일 오전 5시
			job:      s.runMonthlyCleanup,
		},
		{
			name:     "hourly_trending_update",
			schedule: "0 0 * * * *", // 매시간
			job:      s.runTrendingUpdate,
		},
	}

	for _, jobConfig := range jobs {
		entryID, err := s.cron.AddFunc(jobConfig.schedule, s.wrapJob(jobConfig.name, jobConfig.job))
		if err != nil {
			return fmt.Errorf("failed to schedule job %s: %w", jobConfig.name, err)
		}
		
		s.jobs[jobConfig.name] = entryID
		s.logger.Info(fmt.Sprintf("Scheduled job: %s with ID: %d", jobConfig.name, entryID))
	}

	return nil
}

// wrapJob 작업 래퍼 (로깅, 에러 처리, 실행 시간 측정)
func (s *Scheduler) wrapJob(jobName string, job func()) func() {
	return func() {
		startTime := time.Now()
		s.logger.Info(fmt.Sprintf("Starting scheduled job: %s", jobName))

		defer func() {
			if r := recover(); r != nil {
				s.logger.Error(fmt.Sprintf("Job %s panicked: %v", jobName, r))
			}
			
			duration := time.Since(startTime)
			s.logger.Info(fmt.Sprintf("Completed job: %s in %v", jobName, duration))
		}()

		job()
	}
}

// runMannerTemperatureBatch 매너온도 배치 재계산
func (s *Scheduler) runMannerTemperatureBatch() {
	s.logger.Info("Running manner temperature batch recalculation")
	
	if err := s.mannerWorker.BatchRecalculateAll(); err != nil {
		s.logger.Error(fmt.Sprintf("Manner temperature batch failed: %v", err))
		return
	}
	
	s.logger.Info("Manner temperature batch completed successfully")
}

// runAvatarPopularityUpdate 아바타 인기도 순위 업데이트
func (s *Scheduler) runAvatarPopularityUpdate() {
	s.logger.Info("Running avatar popularity ranking update")
	
	if err := s.avatarWorker.BatchUpdatePopularityRankings(); err != nil {
		s.logger.Error(fmt.Sprintf("Avatar popularity update failed: %v", err))
		return
	}
	
	s.logger.Info("Avatar popularity ranking update completed successfully")
}

// runTrendingUpdate 트렌딩 아바타 업데이트
func (s *Scheduler) runTrendingUpdate() {
	s.logger.Debug("Running trending avatars update")
	
	if err := s.avatarWorker.updateTrendingAvatars(); err != nil {
		s.logger.Error(fmt.Sprintf("Trending avatars update failed: %v", err))
		return
	}
	
	s.logger.Debug("Trending avatars update completed successfully")
}

// runWeeklyStatsCalculation 주간 통계 계산
func (s *Scheduler) runWeeklyStatsCalculation() {
	s.logger.Info("Running weekly statistics calculation")
	
	// 주간 아바타 사용 통계
	stats, err := s.avatarWorker.GetAvatarStatistics()
	if err != nil {
		s.logger.Error(fmt.Sprintf("Weekly stats calculation failed: %v", err))
		return
	}
	
	s.logger.Info(fmt.Sprintf("Weekly stats: %+v", stats))
	
	// 주간 보고서 생성 (향후 확장)
	s.generateWeeklyReport(stats)
}

// runMonthlyCleanup 월간 정리 작업
func (s *Scheduler) runMonthlyCleanup() {
	s.logger.Info("Running monthly cleanup")
	
	// 30일 이상 된 로그 정리
	if err := s.cleanupOldLogs(); err != nil {
		s.logger.Error(fmt.Sprintf("Log cleanup failed: %v", err))
	}
	
	// 비활성 사용자 데이터 정리 (30일 이상 미접속)
	if err := s.cleanupInactiveUsers(); err != nil {
		s.logger.Error(fmt.Sprintf("Inactive users cleanup failed: %v", err))
	}
	
	s.logger.Info("Monthly cleanup completed")
}

// generateWeeklyReport 주간 보고서 생성
func (s *Scheduler) generateWeeklyReport(stats map[string]interface{}) {
	// 향후 확장: 실제 보고서 생성 로직
	s.logger.Info("Weekly report generated")
}

// cleanupOldLogs 오래된 로그 정리
func (s *Scheduler) cleanupOldLogs() error {
	// 30일 이상 된 로그 삭제
	cutoffDate := time.Now().AddDate(0, 0, -30)
	
	result := s.db.Where("created_at < ?", cutoffDate).Delete(&struct {
		ID        uint      `gorm:"primaryKey"`
		CreatedAt time.Time `gorm:"index"`
	}{})
	
	if result.Error != nil {
		return result.Error
	}
	
	s.logger.Info(fmt.Sprintf("Cleaned up %d old log entries", result.RowsAffected))
	return nil
}

// cleanupInactiveUsers 비활성 사용자 데이터 정리
func (s *Scheduler) cleanupInactiveUsers() error {
	// 30일 이상 미접속 사용자의 임시 데이터 정리
	cutoffDate := time.Now().AddDate(0, 0, -30)
	
	// 실제 사용자는 삭제하지 않고, 임시 데이터만 정리
	query := `
		UPDATE user_profiles 
		SET last_activity_at = ? 
		WHERE last_activity_at < ? AND last_activity_at IS NOT NULL
	`
	
	result := s.db.Exec(query, nil, cutoffDate)
	if result.Error != nil {
		return result.Error
	}
	
	s.logger.Info(fmt.Sprintf("Cleaned up %d inactive user records", result.RowsAffected))
	return nil
}

// GetJobStatus 작업 상태 조회
func (s *Scheduler) GetJobStatus() map[string]interface{} {
	s.mu.RLock()
	defer s.mu.RUnlock()

	status := make(map[string]interface{})
	status["is_running"] = s.isRunning
	status["total_jobs"] = len(s.jobs)
	
	jobDetails := make(map[string]interface{})
	for jobName, entryID := range s.jobs {
		entry := s.cron.Entry(entryID)
		jobDetails[jobName] = map[string]interface{}{
			"id":        entryID,
			"next_run":  entry.Next,
			"prev_run":  entry.Prev,
			"valid":     entry.Valid(),
		}
	}
	status["jobs"] = jobDetails
	
	return status
}

// RemoveJob 특정 작업 제거
func (s *Scheduler) RemoveJob(jobName string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	entryID, exists := s.jobs[jobName]
	if !exists {
		return fmt.Errorf("job %s not found", jobName)
	}

	s.cron.Remove(entryID)
	delete(s.jobs, jobName)
	
	s.logger.Info(fmt.Sprintf("Removed job: %s", jobName))
	return nil
}

// AddJob 새로운 작업 추가
func (s *Scheduler) AddJob(jobName, schedule string, job func()) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.jobs[jobName]; exists {
		return fmt.Errorf("job %s already exists", jobName)
	}

	entryID, err := s.cron.AddFunc(schedule, s.wrapJob(jobName, job))
	if err != nil {
		return fmt.Errorf("failed to add job %s: %w", jobName, err)
	}

	s.jobs[jobName] = entryID
	s.logger.Info(fmt.Sprintf("Added job: %s with ID: %d", jobName, entryID))
	
	return nil
}