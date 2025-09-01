package services

import (
	"errors"
	"fmt"
	"time"

	"signal-be/internal/repositories"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/redis"
)

type ChatService struct {
	chatRepo    repositories.ChatRepositoryInterface
	signalRepo  repositories.SignalRepositoryInterface
	redisClient *redis.Client
	logger      *logger.Logger
}

func NewChatService(
	chatRepo repositories.ChatRepositoryInterface,
	signalRepo repositories.SignalRepositoryInterface,
	redisClient *redis.Client,
	logger *logger.Logger,
) *ChatService {
	return &ChatService{
		chatRepo:    chatRepo,
		signalRepo:  signalRepo,
		redisClient: redisClient,
		logger:      logger,
	}
}

// GetUserChatRooms retrieves all chat rooms for a user
func (s *ChatService) GetUserChatRooms(userID uint) ([]models.ChatRoomInfo, error) {
	s.logger.Info(fmt.Sprintf("사용자 %d의 채팅방 목록 조회 시작", userID))

	rooms, err := s.chatRepo.GetChatRoomsByUserID(userID)
	if err != nil {
		s.logger.Error("채팅방 목록 조회 실패", err)
		return nil, err
	}

	s.logger.Info(fmt.Sprintf("사용자 %d의 채팅방 %d개 조회 완료", userID, len(rooms)))
	return rooms, nil
}

// CheckRoomAccess checks if user has access to a chat room
func (s *ChatService) CheckRoomAccess(userID uint, roomID uint) (bool, error) {
	// Get the chat room by room ID
	room, err := s.chatRepo.GetChatRoomByID(roomID)
	if err != nil {
		return false, err
	}

	// Check if user is the signal creator
	signal, err := s.signalRepo.GetByID(room.SignalID)
	if err != nil {
		return false, err
	}

	if signal.CreatorID == userID {
		return true, nil
	}

	// Check if user is an approved participant
	isParticipant, err := s.signalRepo.IsUserParticipant(room.SignalID, userID, models.ParticipantApproved)
	if err != nil {
		return false, err
	}

	return isParticipant, nil
}

// GetMessages retrieves messages for a chat room with pagination
func (s *ChatService) GetMessages(roomID uint, page, limit int) ([]models.MessageWithUser, int64, error) {
	s.logger.Info(fmt.Sprintf("채팅방 %d 메시지 조회 (page: %d, limit: %d)", roomID, page, limit))

	messages, total, err := s.chatRepo.GetMessages(roomID, page, limit)
	if err != nil {
		s.logger.Error("메시지 조회 실패", err)
		return nil, 0, err
	}

	s.logger.Info(fmt.Sprintf("채팅방 %d 메시지 %d개 조회 완료 (총 %d개)", roomID, len(messages), total))
	return messages, total, nil
}

// SendMessage sends a new message to a chat room
func (s *ChatService) SendMessage(roomID uint, userID uint, req models.SendMessageRequest) (*models.ChatMessage, error) {
	s.logger.Info(fmt.Sprintf("사용자 %d가 채팅방 %d에 메시지 전송", userID, roomID))

	// Validate message content
	if req.Content == "" && req.Type == models.MessageText {
		return nil, errors.New("메시지 내용이 비어있습니다")
	}

	// Create message
	message := &models.ChatMessage{
		ChatRoomID: roomID,
		UserID:     &userID,
		Type:       req.Type,
		Content:    req.Content,
		ImageURL:   req.ImageURL,
	}

	// Save message to database
	if err := s.chatRepo.SendMessage(message); err != nil {
		s.logger.Error("메시지 저장 실패", err)
		return nil, err
	}

	s.logger.Info(fmt.Sprintf("메시지 ID %d 저장 완료", message.ID))
	return message, nil
}

// CanCreateChatRoom checks if user can create a chat room for a signal
func (s *ChatService) CanCreateChatRoom(userID uint, signalID uint) (bool, error) {
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return false, err
	}

	// Only signal creator can create chat room
	if signal.CreatorID != userID {
		return false, nil
	}

	// Check if chat room already exists for this signal
	existingRoom, err := s.chatRepo.GetChatRoomBySignalID(signalID)
	if err == nil && existingRoom != nil {
		return false, errors.New("이 시그널에 대한 채팅방이 이미 존재합니다")
	}

	return true, nil
}

// CreateChatRoom creates a new chat room for a signal
func (s *ChatService) CreateChatRoom(signalID uint) (*models.ChatRoom, error) {
	s.logger.Info(fmt.Sprintf("시그널 %d의 채팅방 생성 시작", signalID))

	// Get signal information
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return nil, err
	}

	// Calculate expiry time (24 hours after signal scheduled time)
	expiryTime := signal.ScheduledAt.Add(24 * time.Hour)

	// Create chat room
	room := &models.ChatRoom{
		SignalID:  signalID,
		Name:      fmt.Sprintf("%s 채팅방", signal.Title),
		Status:    models.ChatRoomActive,
		ExpiresAt: &expiryTime,
	}

	if err := s.chatRepo.CreateChatRoom(room); err != nil {
		s.logger.Error("채팅방 생성 실패", err)
		return nil, err
	}

	s.logger.Info(fmt.Sprintf("채팅방 ID %d 생성 완료", room.ID))
	return room, nil
}

// JoinChatRoom allows user to join a chat room (if they have permission)
func (s *ChatService) JoinChatRoom(userID uint, roomID uint) error {
	s.logger.Info(fmt.Sprintf("사용자 %d가 채팅방 %d 참여 시도", userID, roomID))

	// Check if user has access
	hasAccess, err := s.CheckRoomAccess(userID, roomID)
	if err != nil {
		return err
	}

	if !hasAccess {
		return errors.New("채팅방에 참여할 권한이 없습니다")
	}

	// Check if room is still active
	room, err := s.GetChatRoom(roomID)
	if err != nil {
		return err
	}

	if room.Status != models.ChatRoomActive {
		return errors.New("채팅방이 활성화되어 있지 않습니다")
	}

	// Check if room has expired
	if room.ExpiresAt != nil && time.Now().After(*room.ExpiresAt) {
		// Update room status to expired
		if err := s.chatRepo.UpdateChatRoomStatus(roomID, models.ChatRoomExpired); err != nil {
			s.logger.Error("만료된 채팅방 상태 업데이트 실패", err)
		}
		return errors.New("채팅방이 만료되었습니다")
	}

	s.logger.Info(fmt.Sprintf("사용자 %d 채팅방 %d 참여 성공", userID, roomID))
	return nil
}

// GetChatRoom retrieves information about a specific chat room
func (s *ChatService) GetChatRoom(roomID uint) (*models.ChatRoom, error) {
	return s.chatRepo.GetChatRoomByID(roomID)
}

// CleanupExpiredRooms cleans up expired chat rooms
func (s *ChatService) CleanupExpiredRooms() error {
	s.logger.Info("만료된 채팅방 정리 시작")

	expiredRooms, err := s.chatRepo.GetExpiredChatRooms()
	if err != nil {
		s.logger.Error("만료된 채팅방 조회 실패", err)
		return err
	}

	for _, room := range expiredRooms {
		if err := s.chatRepo.UpdateChatRoomStatus(room.ID, models.ChatRoomExpired); err != nil {
			s.logger.Error(fmt.Sprintf("채팅방 %d 상태 업데이트 실패", room.ID), err)
			continue
		}

		s.logger.Info(fmt.Sprintf("채팅방 %d를 만료 상태로 변경", room.ID))
	}

	s.logger.Info(fmt.Sprintf("만료된 채팅방 %d개 정리 완료", len(expiredRooms)))
	return nil
}

// GetRoomStats returns statistics about a chat room
func (s *ChatService) GetRoomStats(roomID uint) (map[string]interface{}, error) {
	// Get total message count
	_, total, err := s.chatRepo.GetMessages(roomID, 1, 1)
	if err != nil {
		return nil, err
	}

	return map[string]interface{}{
		"total_messages": total,
		"room_id":        roomID,
	}, nil
}