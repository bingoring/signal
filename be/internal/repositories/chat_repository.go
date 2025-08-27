package repositories

import (
	"time"

	"signal-module/pkg/models"

	"gorm.io/gorm"
)

type ChatRepositoryInterface interface {
	CreateChatRoom(room *models.ChatRoom) error
	GetChatRoomBySignalID(signalID uint) (*models.ChatRoom, error)
	GetChatRoomsByUserID(userID uint) ([]models.ChatRoomInfo, error)
	SendMessage(message *models.ChatMessage) error
	GetMessages(chatRoomID uint, page, limit int) ([]models.MessageWithUser, int64, error)
	UpdateChatRoomStatus(chatRoomID uint, status models.ChatRoomStatus) error
	GetExpiredChatRooms() ([]models.ChatRoom, error)
	DeleteChatRoom(chatRoomID uint) error
}

type ChatRepository struct {
	db *gorm.DB
}

func NewChatRepository(db *gorm.DB) ChatRepositoryInterface {
	return &ChatRepository{db: db}
}

func (r *ChatRepository) CreateChatRoom(room *models.ChatRoom) error {
	return r.db.Create(room).Error
}

func (r *ChatRepository) GetChatRoomBySignalID(signalID uint) (*models.ChatRoom, error) {
	var room models.ChatRoom
	err := r.db.Preload("Signal").
		Where("signal_id = ?", signalID).
		First(&room).Error
	if err != nil {
		return nil, err
	}
	return &room, nil
}

func (r *ChatRepository) GetChatRoomsByUserID(userID uint) ([]models.ChatRoomInfo, error) {
	var roomInfos []models.ChatRoomInfo

	// 사용자가 참여한 시그널의 채팅방들
	query := `
		SELECT 
			cr.id,
			cr.signal_id,
			cr.name,
			cr.status,
			cr.expires_at,
			cr.created_at,
			cr.updated_at,
			COUNT(DISTINCT sp.id) as participant_count
		FROM chat_rooms cr
		JOIN signals s ON cr.signal_id = s.id
		JOIN signal_participants sp ON s.id = sp.signal_id
		WHERE (s.creator_id = ? OR sp.user_id = ?)
		AND sp.status = 'approved'
		AND cr.deleted_at IS NULL
		GROUP BY cr.id, cr.signal_id, cr.name, cr.status, cr.expires_at, cr.created_at, cr.updated_at
		ORDER BY cr.updated_at DESC
	`

	if err := r.db.Raw(query, userID, userID).Find(&roomInfos).Error; err != nil {
		return nil, err
	}

	// 각 채팅방의 마지막 메시지 가져오기
	for i := range roomInfos {
		var lastMessage models.ChatMessage
		err := r.db.Preload("User.Profile").
			Where("chat_room_id = ?", roomInfos[i].ID).
			Order("created_at DESC").
			First(&lastMessage).Error
		
		if err == nil {
			roomInfos[i].LastMessage = &lastMessage
		}
	}

	return roomInfos, nil
}

func (r *ChatRepository) SendMessage(message *models.ChatMessage) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 메시지 저장
		if err := tx.Create(message).Error; err != nil {
			return err
		}

		// 채팅방 업데이트 시간 갱신
		return tx.Model(&models.ChatRoom{}).
			Where("id = ?", message.ChatRoomID).
			Update("updated_at", time.Now()).Error
	})
}

func (r *ChatRepository) GetMessages(chatRoomID uint, page, limit int) ([]models.MessageWithUser, int64, error) {
	var messages []models.MessageWithUser
	var total int64

	// 총 메시지 수 계산
	if err := r.db.Model(&models.ChatMessage{}).
		Where("chat_room_id = ?", chatRoomID).
		Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// 메시지 조회 (최신순)
	offset := (page - 1) * limit
	
	query := `
		SELECT 
			cm.id,
			cm.chat_room_id,
			cm.type,
			cm.content,
			cm.image_url,
			cm.is_edited,
			cm.edited_at,
			cm.created_at,
			CASE 
				WHEN cm.user_id IS NOT NULL THEN JSON_BUILD_OBJECT(
					'id', u.id,
					'username', u.username,
					'display_name', up.display_name,
					'avatar', up.avatar
				)
				ELSE NULL
			END as user
		FROM chat_messages cm
		LEFT JOIN users u ON cm.user_id = u.id
		LEFT JOIN user_profiles up ON u.id = up.user_id
		WHERE cm.chat_room_id = ?
		AND cm.deleted_at IS NULL
		ORDER BY cm.created_at DESC
		LIMIT ? OFFSET ?
	`

	if err := r.db.Raw(query, chatRoomID, limit, offset).Find(&messages).Error; err != nil {
		return nil, 0, err
	}

	return messages, total, nil
}

func (r *ChatRepository) UpdateChatRoomStatus(chatRoomID uint, status models.ChatRoomStatus) error {
	return r.db.Model(&models.ChatRoom{}).
		Where("id = ?", chatRoomID).
		Update("status", status).Error
}

func (r *ChatRepository) GetExpiredChatRooms() ([]models.ChatRoom, error) {
	var rooms []models.ChatRoom
	err := r.db.Where("status = ? AND expires_at < ?", models.ChatRoomActive, time.Now()).
		Find(&rooms).Error
	return rooms, err
}

func (r *ChatRepository) DeleteChatRoom(chatRoomID uint) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 채팅 메시지들 소프트 삭제
		if err := tx.Where("chat_room_id = ?", chatRoomID).Delete(&models.ChatMessage{}).Error; err != nil {
			return err
		}

		// 채팅방 소프트 삭제
		return tx.Delete(&models.ChatRoom{}, chatRoomID).Error
	})
}