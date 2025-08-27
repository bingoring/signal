package services

import (
	"context"
	"fmt"

	"signal-module/pkg/config"
	"signal-module/pkg/logger"
	"signal-module/pkg/queue"
)

type PushNotificationService struct {
	config *config.Config
	logger *logger.Logger
}

func NewPushNotificationService(config *config.Config, logger *logger.Logger) *PushNotificationService {
	return &PushNotificationService{
		config: config,
		logger: logger,
	}
}

func (s *PushNotificationService) ProcessPushNotificationJob(ctx context.Context, job *queue.Job) error {
	userIDs, ok := job.Payload["user_ids"].([]interface{})
	if !ok {
		return fmt.Errorf("잘못된 user_ids 형식")
	}

	title, ok := job.Payload["title"].(string)
	if !ok {
		return fmt.Errorf("잘못된 title 형식")
	}

	body, ok := job.Payload["body"].(string)
	if !ok {
		return fmt.Errorf("잘못된 body 형식")
	}

	dataPayload, _ := job.Payload["data"].(map[string]string)

	// 사용자 ID 변환
	targetUserIDs := make([]uint, len(userIDs))
	for i, userID := range userIDs {
		if id, ok := userID.(float64); ok {
			targetUserIDs[i] = uint(id)
		}
	}

	s.logger.Info(fmt.Sprintf("푸시 알림 발송 시작: %d명의 사용자", len(targetUserIDs)))

	// 실제 푸시 알림 발송 로직
	for _, userID := range targetUserIDs {
		if err := s.sendPushToUser(ctx, userID, title, body, dataPayload); err != nil {
			s.logger.Error(fmt.Sprintf("사용자 %d 푸시 알림 발송 실패", userID), err)
			continue
		}
	}

	s.logger.LogPushNotificationSent(ctx, targetUserIDs, title)
	return nil
}

func (s *PushNotificationService) sendPushToUser(ctx context.Context, userID uint, title, body string, data map[string]string) error {
	// TODO: 실제 FCM/APNS 발송 로직 구현
	// 1. 사용자의 푸시 토큰들을 데이터베이스에서 조회
	// 2. 각 플랫폼별로 푸시 알림 발송 (FCM for Android, APNS for iOS)
	// 3. 실패한 토큰들은 비활성화 처리

	s.logger.Info(fmt.Sprintf("푸시 알림 발송 완료: 사용자 %d, 제목 %s", userID, title))
	return nil
}

// FCM 발송
func (s *PushNotificationService) sendFCM(token, title, body string, data map[string]string) error {
	// TODO: FCM SDK를 사용한 Android 푸시 알림 발송
	return nil
}

// APNS 발송
func (s *PushNotificationService) sendAPNS(token, title, body string, data map[string]string) error {
	// TODO: APNS를 사용한 iOS 푸시 알림 발송
	return nil
}