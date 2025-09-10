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
	s.logger.Info(fmt.Sprintf("사용자 %d가 채팅방 %d에 %s 타입 메시지 전송", userID, roomID, req.Type))

	// Validate message content based on type
	if err := s.validateMessageRequest(req); err != nil {
		return nil, err
	}

	// Create message
	message := &models.ChatMessage{
		ChatRoomID:     roomID,
		UserID:         &userID,
		Type:           req.Type,
		Content:        req.Content,
		ImageURL:       req.ImageURL,
		Latitude:       req.Latitude,
		Longitude:      req.Longitude,
		Address:        req.Address,
		QuickReplyType: req.QuickReplyType,
	}

	// Process specific message types
	if err := s.processSpecialMessageTypes(message); err != nil {
		return nil, err
	}

	// Save message to database
	if err := s.chatRepo.SendMessage(message); err != nil {
		s.logger.Error("메시지 저장 실패", err)
		return nil, err
	}

	s.logger.Info(fmt.Sprintf("메시지 ID %d 저장 완료 (타입: %s)", message.ID, message.Type))
	return message, nil
}

// validateMessageRequest validates message request based on type
func (s *ChatService) validateMessageRequest(req models.SendMessageRequest) error {
	switch req.Type {
	case models.MessageText:
		if req.Content == "" {
			return errors.New("텍스트 메시지 내용이 비어있습니다")
		}
	case models.MessageImage:
		if req.ImageURL == "" {
			return errors.New("이미지 URL이 필요합니다")
		}
	case models.MessageLocation:
		if req.Latitude == nil || req.Longitude == nil {
			return errors.New("위치 정보(위도, 경도)가 필요합니다")
		}
		if *req.Latitude < -90 || *req.Latitude > 90 {
			return errors.New("잘못된 위도 값입니다")
		}
		if *req.Longitude < -180 || *req.Longitude > 180 {
			return errors.New("잘못된 경도 값입니다")
		}
	case models.MessageQuickReply:
		if req.QuickReplyType == "" {
			return errors.New("빠른 응답 타입이 필요합니다")
		}
		validTypes := map[string]bool{
			"arrived": true, "late_5min": true, "late_10min": true, 
			"late_15min": true, "cancel": true, "on_way": true,
		}
		if !validTypes[req.QuickReplyType] {
			return errors.New("지원하지 않는 빠른 응답 타입입니다")
		}
	}
	return nil
}

// processSpecialMessageTypes processes special message types
func (s *ChatService) processSpecialMessageTypes(message *models.ChatMessage) error {
	switch message.Type {
	case models.MessageLocation:
		// 위치 공유 메시지의 경우 주소가 없으면 좌표로 주소 생성
		if message.Address == "" && message.Latitude != nil && message.Longitude != nil {
			message.Address = fmt.Sprintf("위도: %.6f, 경도: %.6f", *message.Latitude, *message.Longitude)
		}
		if message.Content == "" {
			message.Content = "위치를 공유했습니다"
		}
		
	case models.MessageQuickReply:
		// 빠른 응답 메시지의 경우 타입에 따라 내용 자동 생성
		if message.Content == "" {
			message.Content = s.generateQuickReplyContent(message.QuickReplyType)
		}
		
	case models.MessageCountdown, models.MessageStatus:
		// 시스템 메시지는 userID를 nil로 설정
		message.UserID = nil
	}
	
	return nil
}

// generateQuickReplyContent generates content for quick reply messages
func (s *ChatService) generateQuickReplyContent(quickReplyType string) string {
	switch quickReplyType {
	case "arrived":
		return "도착했어요! 📍"
	case "late_5min":
		return "5분 늦을게요 😅"
	case "late_10min":
		return "10분 늦을게요 😅"
	case "late_15min":
		return "15분 늦을게요 😅"
	case "cancel":
		return "죄송합니다, 참석이 어려워졌어요 😢"
	case "on_way":
		return "지금 가는 중이에요! 🚶‍♂️"
	default:
		return "빠른 응답"
	}
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

// GetChatRoomBySignalID retrieves chat room by signal ID
func (s *ChatService) GetChatRoomBySignalID(signalID uint) (*models.ChatRoom, error) {
	return s.chatRepo.GetChatRoomBySignalID(signalID)
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

// StartMeeting transitions chat room to meeting status when signal starts
func (s *ChatService) StartMeeting(signalID uint) error {
	s.logger.Info(fmt.Sprintf("시그널 %d 모임 시작 - 채팅방 상태 전환", signalID))

	room, err := s.chatRepo.GetChatRoomBySignalID(signalID)
	if err != nil {
		return fmt.Errorf("채팅방 조회 실패: %v", err)
	}

	if room.Status != models.ChatRoomActive {
		return fmt.Errorf("활성 상태가 아닌 채팅방은 모임을 시작할 수 없습니다")
	}

	if err := s.chatRepo.UpdateChatRoomStatus(room.ID, models.ChatRoomMeeting); err != nil {
		return fmt.Errorf("채팅방 상태 업데이트 실패: %v", err)
	}

	// 모임 시작 시스템 메시지 전송
	systemMessage := &models.ChatMessage{
		ChatRoomID: room.ID,
		UserID:     nil,
		Type:       models.MessageStatus,
		Content:    "🎉 모임이 시작되었습니다! 즐거운 시간 보내세요!",
	}

	if err := s.chatRepo.SendMessage(systemMessage); err != nil {
		s.logger.Error("모임 시작 시스템 메시지 전송 실패", err)
	}

	s.logger.Info(fmt.Sprintf("채팅방 %d 모임 상태로 전환 완료", room.ID))
	return nil
}

// CompleteMeeting marks the meeting as successfully completed
func (s *ChatService) CompleteMeeting(signalID uint, hostUserID uint) error {
	s.logger.Info(fmt.Sprintf("시그널 %d 모임 완료 처리 시작", signalID))

	room, err := s.chatRepo.GetChatRoomBySignalID(signalID)
	if err != nil {
		return fmt.Errorf("채팅방 조회 실패: %v", err)
	}

	// 권한 확인 - 시그널 주최자인지 확인
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널 조회 실패: %v", err)
	}

	if signal.CreatorID != hostUserID {
		return fmt.Errorf("시그널 주최자만 모임을 완료할 수 있습니다")
	}

	if room.Status != models.ChatRoomMeeting {
		return fmt.Errorf("모임 진행 중인 채팅방만 완료 처리가 가능합니다")
	}

	if err := s.chatRepo.UpdateChatRoomStatus(room.ID, models.ChatRoomCompleted); err != nil {
		return fmt.Errorf("채팅방 상태 업데이트 실패: %v", err)
	}

	// 모임 완료 시스템 메시지 전송
	systemMessage := &models.ChatMessage{
		ChatRoomID: room.ID,
		UserID:     nil,
		Type:       models.MessageStatus,
		Content:    "✅ 모임이 성공적으로 완료되었습니다! 수고하셨습니다! 채팅방은 24시간 후 자동 삭제됩니다.",
	}

	if err := s.chatRepo.SendMessage(systemMessage); err != nil {
		s.logger.Error("모임 완료 시스템 메시지 전송 실패", err)
	}

	s.logger.Info(fmt.Sprintf("채팅방 %d 모임 완료 처리 완료", room.ID))
	return nil
}

// SendCountdownMessage sends countdown system message
func (s *ChatService) SendCountdownMessage(signalID uint, minutesLeft int) error {
	room, err := s.chatRepo.GetChatRoomBySignalID(signalID)
	if err != nil {
		return fmt.Errorf("채팅방 조회 실패: %v", err)
	}

	if room.Status != models.ChatRoomActive {
		return nil // 활성 상태가 아니면 카운트다운 메시지 전송 안함
	}

	var content string
	if minutesLeft > 0 {
		content = fmt.Sprintf("⏰ 모임 시작까지 %d분 남았습니다!", minutesLeft)
	} else {
		content = "🚀 모임이 곧 시작됩니다!"
	}

	systemMessage := &models.ChatMessage{
		ChatRoomID: room.ID,
		UserID:     nil,
		Type:       models.MessageCountdown,
		Content:    content,
	}

	if err := s.chatRepo.SendMessage(systemMessage); err != nil {
		return fmt.Errorf("카운트다운 메시지 전송 실패: %v", err)
	}

	s.logger.Info(fmt.Sprintf("채팅방 %d에 카운트다운 메시지 전송: %d분", room.ID, minutesLeft))
	return nil
}

// GetActiveRoomsByStatus retrieves chat rooms by status
func (s *ChatService) GetActiveRoomsByStatus(status models.ChatRoomStatus) ([]models.ChatRoom, error) {
	// This would need a new repository method
	s.logger.Info(fmt.Sprintf("%s 상태의 채팅방 조회", status))
	// For now, return empty - would need to implement in repository
	return []models.ChatRoom{}, nil
}