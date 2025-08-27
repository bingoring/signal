package services

import (
	"context"
	"fmt"
	"time"

	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/queue"

	"gorm.io/gorm"
)

type SignalSchedulerService struct {
	db       *gorm.DB
	queue    *queue.Queue
	logger   *logger.Logger
}

func NewSignalSchedulerService(db *gorm.DB, queue *queue.Queue, logger *logger.Logger) *SignalSchedulerService {
	return &SignalSchedulerService{
		db:     db,
		queue:  queue,
		logger: logger,
	}
}

// 만료된 시그널들을 처리
func (s *SignalSchedulerService) ProcessExpiredSignals(ctx context.Context) error {
	var expiredSignals []models.Signal

	// 만료 시간이 지난 활성 시그널들 조회
	if err := s.db.Where("status = ? AND expires_at < ?", models.SignalActive, time.Now()).Find(&expiredSignals).Error; err != nil {
		return fmt.Errorf("만료된 시그널 조회 실패: %w", err)
	}

	if len(expiredSignals) == 0 {
		return nil
	}

	s.logger.Info(fmt.Sprintf("만료된 시그널 처리 시작: %d개", len(expiredSignals)))

	// 각 시그널을 만료 상태로 변경
	for _, signal := range expiredSignals {
		if err := s.db.Model(&signal).Update("status", models.SignalClosed).Error; err != nil {
			s.logger.Error(fmt.Sprintf("시그널 %d 상태 업데이트 실패", signal.ID), err)
			continue
		}

		// Redis에서 활성 시그널 제거
		// TODO: Redis 연동 추가

		s.logger.LogSignalExpired(ctx, signal.ID)
	}

	s.logger.Info(fmt.Sprintf("만료된 시그널 처리 완료: %d개", len(expiredSignals)))
	return nil
}

// 정원이 찬 시그널들에 대해 채팅방 생성
func (s *SignalSchedulerService) CreateChatRoomsForFullSignals(ctx context.Context) error {
	var fullSignals []models.Signal

	// 정원이 찬 시그널들 중 채팅방이 없는 것들 조회
	if err := s.db.Where("status = ? AND current_participants >= max_participants", models.SignalFull).
		Where("id NOT IN (SELECT signal_id FROM chat_rooms WHERE deleted_at IS NULL)").
		Find(&fullSignals).Error; err != nil {
		return fmt.Errorf("정원이 찬 시그널 조회 실패: %w", err)
	}

	if len(fullSignals) == 0 {
		return nil
	}

	s.logger.Info(fmt.Sprintf("채팅방 생성 시작: %d개 시그널", len(fullSignals)))

	// 각 시그널에 대해 채팅방 생성
	for _, signal := range fullSignals {
		// 채팅방 만료 시간: 시그널 시작 24시간 후
		expiresAt := signal.ScheduledAt.Add(24 * time.Hour)

		chatRoom := &models.ChatRoom{
			SignalID:  signal.ID,
			Name:      fmt.Sprintf("%s 채팅방", signal.Title),
			Status:    models.ChatRoomActive,
			ExpiresAt: &expiresAt,
		}

		if err := s.db.Create(chatRoom).Error; err != nil {
			s.logger.Error(fmt.Sprintf("시그널 %d 채팅방 생성 실패", signal.ID), err)
			continue
		}

		// 채팅방 만료 작업 스케줄링
		if err := s.queue.ScheduleChatRoomExpiration(ctx, chatRoom.ID, expiresAt); err != nil {
			s.logger.Error(fmt.Sprintf("채팅방 %d 만료 스케줄링 실패", chatRoom.ID), err)
		}

		s.logger.LogChatRoomCreated(ctx, chatRoom.ID, signal.ID)
	}

	s.logger.Info(fmt.Sprintf("채팅방 생성 완료: %d개", len(fullSignals)))
	return nil
}

// 만료된 채팅방들을 스케줄링
func (s *SignalSchedulerService) ScheduleExpiredChatRooms(ctx context.Context) error {
	var expiredRooms []models.ChatRoom

	// 만료 시간이 지난 활성 채팅방들 조회
	if err := s.db.Where("status = ? AND expires_at < ?", models.ChatRoomActive, time.Now()).Find(&expiredRooms).Error; err != nil {
		return fmt.Errorf("만료된 채팅방 조회 실패: %w", err)
	}

	if len(expiredRooms) == 0 {
		return nil
	}

	s.logger.Info(fmt.Sprintf("채팅방 만료 스케줄링 시작: %d개", len(expiredRooms)))

	// 각 채팅방에 대해 만료 작업 큐에 추가
	for _, room := range expiredRooms {
		if err := s.queue.ScheduleChatRoomExpiration(ctx, room.ID, time.Now()); err != nil {
			s.logger.Error(fmt.Sprintf("채팅방 %d 만료 스케줄링 실패", room.ID), err)
			continue
		}
	}

	s.logger.Info(fmt.Sprintf("채팅방 만료 스케줄링 완료: %d개", len(expiredRooms)))
	return nil
}

// 매너 점수 업데이트 (일일/주간 배치 작업)
func (s *SignalSchedulerService) UpdateMannerScores(ctx context.Context) error {
	s.logger.Info("매너 점수 업데이트 시작")

	// TODO: 매너 점수 계산 로직 구현
	// 1. 최근 평가들을 기반으로 매너 점수 재계산
	// 2. 노쇼 카운트가 높은 사용자들의 패널티 적용
	// 3. 활발한 참여자들에게 보너스 점수 적용

	// 예시: 모든 사용자의 매너 점수를 재계산
	var users []models.User
	if err := s.db.Preload("Profile").Find(&users).Error; err != nil {
		return fmt.Errorf("사용자 조회 실패: %w", err)
	}

	for _, user := range users {
		if user.Profile == nil {
			continue
		}

		// 최근 30일간의 평가들을 조회하여 새로운 매너 점수 계산
		var ratings []models.UserRating
		thirtyDaysAgo := time.Now().AddDate(0, 0, -30)
		
		if err := s.db.Where("ratee_id = ? AND created_at > ?", user.ID, thirtyDaysAgo).Find(&ratings).Error; err != nil {
			continue
		}

		if len(ratings) > 0 {
			totalScore := 0
			noShowCount := 0
			
			for _, rating := range ratings {
				totalScore += rating.Score
				if rating.IsNoShow {
					noShowCount++
				}
			}

			newScore := float64(totalScore) / float64(len(ratings))
			
			// 노쇼에 대한 패널티 적용
			if noShowCount > 0 {
				penalty := float64(noShowCount) * 0.5
				newScore = newScore - penalty
				if newScore < 1.0 {
					newScore = 1.0
				}
			}

			// 매너 점수 업데이트
			if err := s.db.Model(user.Profile).Updates(map[string]interface{}{
				"manner_score":   newScore,
				"total_ratings":  len(ratings),
				"no_show_count":  noShowCount,
			}).Error; err != nil {
				s.logger.Error(fmt.Sprintf("사용자 %d 매너 점수 업데이트 실패", user.ID), err)
			}
		}
	}

	s.logger.Info("매너 점수 업데이트 완료")
	return nil
}