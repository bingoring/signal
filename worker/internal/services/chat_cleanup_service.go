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

type ChatCleanupService struct {
	db     *gorm.DB
	logger *logger.Logger
}

func NewChatCleanupService(db *gorm.DB, logger *logger.Logger) *ChatCleanupService {
	return &ChatCleanupService{
		db:     db,
		logger: logger,
	}
}

func (s *ChatCleanupService) ProcessChatRoomExpirationJob(ctx context.Context, job *queue.Job) error {
	chatRoomID, ok := job.Payload["chat_room_id"].(float64)
	if !ok {
		return fmt.Errorf("잘못된 chat_room_id 형식")
	}

	roomID := uint(chatRoomID)

	s.logger.Info(fmt.Sprintf("채팅방 만료 처리 시작: %d", roomID))

	// 채팅방 조회
	var chatRoom models.ChatRoom
	if err := s.db.First(&chatRoom, roomID).Error; err != nil {
		return fmt.Errorf("채팅방 조회 실패: %w", err)
	}

	// 이미 만료된 채팅방인지 확인
	if chatRoom.Status == models.ChatRoomExpired {
		s.logger.Info(fmt.Sprintf("이미 만료된 채팅방: %d", roomID))
		return nil
	}

	// 만료 시간 확인
	if chatRoom.ExpiresAt != nil && time.Now().Before(*chatRoom.ExpiresAt) {
		s.logger.Info(fmt.Sprintf("아직 만료되지 않은 채팅방: %d", roomID))
		return nil
	}

	// 트랜잭션으로 채팅방과 메시지 정리
	return s.db.Transaction(func(tx *gorm.DB) error {
		// 1. 채팅방 상태를 만료로 변경
		if err := tx.Model(&chatRoom).Update("status", models.ChatRoomExpired).Error; err != nil {
			return fmt.Errorf("채팅방 상태 업데이트 실패: %w", err)
		}

		// 2. 모든 메시지 소프트 삭제
		if err := tx.Where("chat_room_id = ?", roomID).Delete(&models.ChatMessage{}).Error; err != nil {
			return fmt.Errorf("채팅 메시지 삭제 실패: %w", err)
		}

		// 3. 채팅방 소프트 삭제
		if err := tx.Delete(&chatRoom).Error; err != nil {
			return fmt.Errorf("채팅방 삭제 실패: %w", err)
		}

		s.logger.LogChatRoomExpired(ctx, roomID)
		s.logger.Info(fmt.Sprintf("채팅방 만료 처리 완료: %d", roomID))

		return nil
	})
}

// 만료된 채팅방들을 일괄 정리하는 배치 작업
func (s *ChatCleanupService) CleanupExpiredChatRooms(ctx context.Context) error {
	var expiredRooms []models.ChatRoom

	// 만료 시간이 지난 활성 채팅방들 조회
	if err := s.db.Where("status = ? AND expires_at < ?", models.ChatRoomActive, time.Now()).Find(&expiredRooms).Error; err != nil {
		return fmt.Errorf("만료된 채팅방 조회 실패: %w", err)
	}

	if len(expiredRooms) == 0 {
		return nil
	}

	s.logger.Info(fmt.Sprintf("만료된 채팅방 일괄 정리 시작: %d개", len(expiredRooms)))

	// 각 채팅방별로 정리 작업 수행
	for _, room := range expiredRooms {
		job := &queue.Job{
			Type: queue.JobExpireChatRoom,
			Payload: map[string]interface{}{
				"chat_room_id": float64(room.ID),
			},
		}

		if err := s.ProcessChatRoomExpirationJob(ctx, job); err != nil {
			s.logger.Error(fmt.Sprintf("채팅방 %d 정리 실패", room.ID), err)
			continue
		}
	}

	s.logger.Info(fmt.Sprintf("만료된 채팅방 일괄 정리 완료: %d개", len(expiredRooms)))
	return nil
}