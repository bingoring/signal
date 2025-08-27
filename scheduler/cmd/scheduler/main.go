package main

import (
	"context"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"signal-scheduler/internal/services"

	"signal-module/pkg/config"
	"signal-module/pkg/database"
	"signal-module/pkg/logger"
	"signal-module/pkg/queue"
	"signal-module/pkg/redis"
)

func main() {
	cfg := config.LoadConfig()

	appLogger := logger.New("signal-scheduler")
	appLogger.Info("⏰ Signal Scheduler 시작 중...")

	// 데이터베이스 연결
	db, err := database.New(&cfg.Database)
	if err != nil {
		appLogger.Error("데이터베이스 연결 실패", err)
		os.Exit(1)
	}
	defer db.Close()

	// Redis 연결
	redisClient, err := redis.New(&cfg.Redis)
	if err != nil {
		appLogger.Error("Redis 연결 실패", err)
		os.Exit(1)
	}
	defer redisClient.Close()

	// 큐 시스템 초기화
	jobQueue := queue.New(redisClient)

	// 서비스 초기화
	signalScheduler := services.NewSignalSchedulerService(db.DB, jobQueue, appLogger)

	// 스케줄러들 시작
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var wg sync.WaitGroup

	// 시그널 만료 처리 스케줄러 (매 1분마다)
	wg.Add(1)
	go func() {
		defer wg.Done()
		runSignalExpirationScheduler(ctx, signalScheduler, appLogger)
	}()

	// 채팅방 생성 및 만료 스케줄러 (매 5분마다)
	wg.Add(1)
	go func() {
		defer wg.Done()
		runChatRoomScheduler(ctx, signalScheduler, appLogger)
	}()

	// 매너 점수 업데이트 스케줄러 (매 1시간마다)
	wg.Add(1)
	go func() {
		defer wg.Done()
		runMannerScoreScheduler(ctx, signalScheduler, appLogger)
	}()

	appLogger.Info("✅ 모든 스케줄러가 시작되었습니다")

	// 종료 신호 대기
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	appLogger.Info("🛑 Scheduler 종료 중...")

	cancel()
	wg.Wait()

	appLogger.Info("✅ Scheduler가 정상적으로 종료되었습니다")
}

func runSignalExpirationScheduler(ctx context.Context, scheduler *services.SignalSchedulerService, appLogger *logger.Logger) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := scheduler.ProcessExpiredSignals(ctx); err != nil {
				appLogger.Error("만료된 시그널 처리 실패", err)
			}
		}
	}
}

func runChatRoomScheduler(ctx context.Context, scheduler *services.SignalSchedulerService, appLogger *logger.Logger) {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// 새로운 채팅방 생성
			if err := scheduler.CreateChatRoomsForFullSignals(ctx); err != nil {
				appLogger.Error("채팅방 생성 실패", err)
			}

			// 만료된 채팅방 스케줄링
			if err := scheduler.ScheduleExpiredChatRooms(ctx); err != nil {
				appLogger.Error("채팅방 만료 스케줄링 실패", err)
			}
		}
	}
}

func runMannerScoreScheduler(ctx context.Context, scheduler *services.SignalSchedulerService, appLogger *logger.Logger) {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := scheduler.UpdateMannerScores(ctx); err != nil {
				appLogger.Error("매너 점수 업데이트 실패", err)
			}
		}
	}
}