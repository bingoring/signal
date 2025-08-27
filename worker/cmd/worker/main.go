package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"signal-worker/internal/services"

	"signal-module/pkg/config"
	"signal-module/pkg/database"
	"signal-module/pkg/logger"
	"signal-module/pkg/queue"
	"signal-module/pkg/redis"
)

func main() {
	cfg := config.LoadConfig()

	appLogger := logger.New("signal-worker")
	appLogger.Info("🔄 Signal Worker 시작 중...")

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
	pushService := services.NewPushNotificationService(cfg, appLogger)
	emailService := services.NewEmailService(appLogger)
	chatService := services.NewChatCleanupService(db.DB, appLogger)

	// Worker들 시작
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var wg sync.WaitGroup

	// 푸시 알림 워커
	wg.Add(1)
	go func() {
		defer wg.Done()
		runPushNotificationWorker(ctx, jobQueue, pushService, appLogger)
	}()

	// 이메일 워커
	wg.Add(1)
	go func() {
		defer wg.Done()
		runEmailWorker(ctx, jobQueue, emailService, appLogger)
	}()

	// 채팅방 정리 워커
	wg.Add(1)
	go func() {
		defer wg.Done()
		runChatCleanupWorker(ctx, jobQueue, chatService, appLogger)
	}()

	// 지연 작업 처리 워커
	wg.Add(1)
	go func() {
		defer wg.Done()
		runDelayedJobProcessor(ctx, jobQueue, appLogger)
	}()

	appLogger.Info("✅ 모든 워커가 시작되었습니다")

	// 종료 신호 대기
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	appLogger.Info("🛑 Worker 종료 중...")

	cancel()
	wg.Wait()

	appLogger.Info("✅ Worker가 정상적으로 종료되었습니다")
}

func runPushNotificationWorker(ctx context.Context, jobQueue *queue.Queue, pushService *services.PushNotificationService, appLogger *logger.Logger) {
	for {
		select {
		case <-ctx.Done():
			return
		default:
			job, err := jobQueue.Pop(ctx, queue.JobSendPushNotification, 5*time.Second)
			if err != nil {
				continue
			}

			if err := pushService.ProcessPushNotificationJob(ctx, job); err != nil {
				appLogger.Error("푸시 알림 처리 실패", err)
				if err := jobQueue.Retry(ctx, job, 30*time.Second); err != nil {
					appLogger.Error("푸시 알림 재시도 실패", err)
				}
			}
		}
	}
}

func runEmailWorker(ctx context.Context, jobQueue *queue.Queue, emailService *services.EmailService, appLogger *logger.Logger) {
	for {
		select {
		case <-ctx.Done():
			return
		default:
			job, err := jobQueue.Pop(ctx, queue.JobSendEmail, 5*time.Second)
			if err != nil {
				continue
			}

			if err := emailService.ProcessEmailJob(ctx, job); err != nil {
				appLogger.Error("이메일 처리 실패", err)
				if err := jobQueue.Retry(ctx, job, 1*time.Minute); err != nil {
					appLogger.Error("이메일 재시도 실패", err)
				}
			}
		}
	}
}

func runChatCleanupWorker(ctx context.Context, jobQueue *queue.Queue, chatService *services.ChatCleanupService, appLogger *logger.Logger) {
	for {
		select {
		case <-ctx.Done():
			return
		default:
			job, err := jobQueue.Pop(ctx, queue.JobExpireChatRoom, 5*time.Second)
			if err != nil {
				continue
			}

			if err := chatService.ProcessChatRoomExpirationJob(ctx, job); err != nil {
				appLogger.Error("채팅방 정리 실패", err)
				if err := jobQueue.Retry(ctx, job, 5*time.Minute); err != nil {
					appLogger.Error("채팅방 정리 재시도 실패", err)
				}
			}
		}
	}
}

func runDelayedJobProcessor(ctx context.Context, jobQueue *queue.Queue, appLogger *logger.Logger) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := jobQueue.ProcessDelayedJobs(ctx); err != nil {
				appLogger.Error("지연 작업 처리 실패", err)
			}
		}
	}
}