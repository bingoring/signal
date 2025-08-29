package services

import (
	"errors"
	"time"

	"signal-be/internal/repositories"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"

	"gorm.io/gorm"
)

type BuddyServiceInterface interface {
	// 단골 관계 관리
	CreateBuddy(userID, buddyID uint) (*models.UserBuddy, error)
	GetBuddyRelationship(userID, buddyID uint) (*models.UserBuddy, error)
	UpdateBuddy(userID, buddyID uint, req *models.UpdateBuddyRequest) error
	DeleteBuddy(userID, buddyID uint) error

	// 단골 목록 및 통계
	GetUserBuddies(userID uint, query *models.GetBuddiesQuery) ([]models.BuddyRelationship, int64, error)
	GetBuddyStats(userID uint) (*models.BuddyStats, error)
	GetPotentialBuddies(userID uint, minInteractions int, minMannerScore float64) ([]models.PotentialBuddy, error)

	// 매너 점수 관리
	CreateMannerLog(raterID uint, req *models.CreateMannerLogRequest) (*models.MannerScoreLog, error)
	GetMannerLogs(userID uint, page, limit int) ([]models.MannerScoreLog, int64, error)
	GetMannerScoreHistory(userID uint, days int) ([]models.MannerScoreHistoryPoint, error)

	// 단골 초대 관리
	CreateBuddyInvitation(inviterID uint, req *models.CreateBuddyInvitationRequest) (*models.BuddyInvitation, error)
	GetUserInvitations(userID uint, status []models.InvitationStatus, page, limit int) ([]models.BuddyInvitation, int64, error)
	RespondBuddyInvitation(userID, invitationID uint, status models.InvitationStatus) error

	// 시그널 상호작용 관리
	CreateSignalInteraction(signalID, user1ID, user2ID uint, interactionType models.InteractionType) error
	UpdateInteractionType(signalID, user1ID, user2ID uint, interactionType models.InteractionType) error
}

type BuddyService struct {
	buddyRepo repositories.BuddyRepositoryInterface
	userRepo  repositories.UserRepositoryInterface
	logger    *logger.Logger
}

func NewBuddyService(
	buddyRepo repositories.BuddyRepositoryInterface,
	userRepo repositories.UserRepositoryInterface,
	logger *logger.Logger,
) BuddyServiceInterface {
	return &BuddyService{
		buddyRepo: buddyRepo,
		userRepo:  userRepo,
		logger:    logger,
	}
}

// CreateBuddy 새로운 단골 관계 생성
func (s *BuddyService) CreateBuddy(userID, buddyID uint) (*models.UserBuddy, error) {
	// 상대방 사용자 존재 확인
	_, err := s.userRepo.GetByID(buddyID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("존재하지 않는 사용자입니다")
		}
		return nil, err
	}

	// 기존 단골 관계 확인
	existing, err := s.buddyRepo.GetBuddyRelationship(userID, buddyID)
	if err == nil && existing != nil {
		return nil, errors.New("이미 단골 관계입니다")
	}

	// 새로운 단골 관계 생성
	buddy := &models.UserBuddy{
		User1ID:             userID,
		User2ID:             buddyID,
		Status:              string(models.BuddyStatusActive),
		CompatibilityScore:  5.0,
		InteractionCount:    1,
		TotalSignals:        0,
		CreatedAt:           time.Now(),
		LastInteraction:     time.Now(),
	}

	if err := s.buddyRepo.CreateBuddy(buddy); err != nil {
		s.logger.Error("단골 관계 생성 실패", err)
		return nil, errors.New("단골 관계 생성에 실패했습니다")
	}

	return buddy, nil
}

// GetBuddyRelationship 단골 관계 조회
func (s *BuddyService) GetBuddyRelationship(userID, buddyID uint) (*models.UserBuddy, error) {
	buddy, err := s.buddyRepo.GetBuddyRelationship(userID, buddyID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("단골 관계를 찾을 수 없습니다")
		}
		return nil, err
	}

	return buddy, nil
}

// UpdateBuddy 단골 관계 업데이트
func (s *BuddyService) UpdateBuddy(userID, buddyID uint, req *models.UpdateBuddyRequest) error {
	buddy, err := s.buddyRepo.GetBuddyRelationship(userID, buddyID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("단골 관계를 찾을 수 없습니다")
		}
		return err
	}

	// 업데이트 적용
	if req.Status != nil {
		buddy.Status = string(*req.Status)
	}

	if req.CompatibilityScore != nil {
		if *req.CompatibilityScore < 0 || *req.CompatibilityScore > 10 {
			return errors.New("궁합 점수는 0-10 사이여야 합니다")
		}
		buddy.CompatibilityScore = *req.CompatibilityScore
	}

	if req.Notes != nil {
		buddy.Notes = *req.Notes
	}

	return s.buddyRepo.UpdateBuddy(buddy)
}

// DeleteBuddy 단골 관계 삭제
func (s *BuddyService) DeleteBuddy(userID, buddyID uint) error {
	// 단골 관계 존재 확인
	_, err := s.buddyRepo.GetBuddyRelationship(userID, buddyID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("단골 관계를 찾을 수 없습니다")
		}
		return err
	}

	return s.buddyRepo.DeleteBuddy(userID, buddyID)
}

// GetUserBuddies 사용자의 단골 목록 조회
func (s *BuddyService) GetUserBuddies(userID uint, query *models.GetBuddiesQuery) ([]models.BuddyRelationship, int64, error) {
	query.SetDefaults()
	return s.buddyRepo.GetUserBuddies(userID, query)
}

// GetBuddyStats 사용자의 단골 통계 조회
func (s *BuddyService) GetBuddyStats(userID uint) (*models.BuddyStats, error) {
	return s.buddyRepo.GetBuddyStats(userID)
}

// GetPotentialBuddies 단골 후보자 조회
func (s *BuddyService) GetPotentialBuddies(userID uint, minInteractions int, minMannerScore float64) ([]models.PotentialBuddy, error) {
	return s.buddyRepo.GetPotentialBuddies(userID, minInteractions, minMannerScore)
}

// CreateMannerLog 매너 점수 평가 생성
func (s *BuddyService) CreateMannerLog(raterID uint, req *models.CreateMannerLogRequest) (*models.MannerScoreLog, error) {
	// 평가 대상자 존재 확인
	_, err := s.userRepo.GetByID(req.RateeID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("존재하지 않는 사용자입니다")
		}
		return nil, err
	}

	// 시그널 관련 평가인 경우 중복 평가 방지 확인은 데이터베이스 제약조건에서 처리

	log := &models.MannerScoreLog{
		SignalID:    req.SignalID,
		RaterID:     raterID,
		RateeID:     req.RateeID,
		ScoreChange: req.ScoreChange,
		Category:    string(req.Category),
		Reason:      req.Reason,
		CreatedAt:   time.Now(),
	}

	if err := s.buddyRepo.CreateMannerLog(log); err != nil {
		s.logger.Error("매너 점수 평가 생성 실패", err)
		return nil, errors.New("매너 점수 평가에 실패했습니다")
	}

	return log, nil
}

// GetMannerLogs 매너 점수 이력 조회
func (s *BuddyService) GetMannerLogs(userID uint, page, limit int) ([]models.MannerScoreLog, int64, error) {
	if page <= 0 {
		page = 1
	}
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	return s.buddyRepo.GetMannerLogs(userID, page, limit)
}

// GetMannerScoreHistory 매너 점수 히스토리 조회
func (s *BuddyService) GetMannerScoreHistory(userID uint, days int) ([]models.MannerScoreHistoryPoint, error) {
	if days <= 0 {
		days = 30
	}

	return s.buddyRepo.GetMannerScoreHistory(userID, days)
}

// CreateBuddyInvitation 단골 초대 생성
func (s *BuddyService) CreateBuddyInvitation(inviterID uint, req *models.CreateBuddyInvitationRequest) (*models.BuddyInvitation, error) {
	// 초대 받을 사용자 존재 확인
	_, err := s.userRepo.GetByID(req.InviteeID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("존재하지 않는 사용자입니다")
		}
		return nil, err
	}

	// 두 사용자가 단골 관계인지 확인
	_, err = s.buddyRepo.GetBuddyRelationship(inviterID, req.InviteeID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("단골 관계가 아닙니다")
		}
		return nil, err
	}

	invitation := &models.BuddyInvitation{
		SignalID:  req.SignalID,
		InviterID: inviterID,
		InviteeID: req.InviteeID,
		Status:    string(models.InvitationStatusPending),
		Message:   req.Message,
		ExpiresAt: time.Now().Add(24 * time.Hour),
		CreatedAt: time.Now(),
	}

	if err := s.buddyRepo.CreateBuddyInvitation(invitation); err != nil {
		s.logger.Error("단골 초대 생성 실패", err)
		return nil, errors.New("단골 초대 생성에 실패했습니다")
	}

	return invitation, nil
}

// GetUserInvitations 사용자의 초대 목록 조회
func (s *BuddyService) GetUserInvitations(userID uint, status []models.InvitationStatus, page, limit int) ([]models.BuddyInvitation, int64, error) {
	if page <= 0 {
		page = 1
	}
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	return s.buddyRepo.GetUserInvitations(userID, status, page, limit)
}

// RespondBuddyInvitation 단골 초대 응답
func (s *BuddyService) RespondBuddyInvitation(userID, invitationID uint, status models.InvitationStatus) error {
	invitation, err := s.buddyRepo.GetBuddyInvitation(invitationID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("초대를 찾을 수 없습니다")
		}
		return err
	}

	// 초대 받은 사용자만 응답 가능
	if invitation.InviteeID != userID {
		return errors.New("초대에 응답할 권한이 없습니다")
	}

	// 이미 응답한 초대인지 확인
	if invitation.Status != string(models.InvitationStatusPending) {
		return errors.New("이미 응답한 초대입니다")
	}

	// 만료된 초대인지 확인
	if time.Now().After(invitation.ExpiresAt) {
		return errors.New("만료된 초대입니다")
	}

	// 응답 업데이트
	invitation.Status = string(status)
	now := time.Now()
	invitation.RespondedAt = &now

	return s.buddyRepo.UpdateBuddyInvitation(invitation)
}

// CreateSignalInteraction 시그널 상호작용 생성
func (s *BuddyService) CreateSignalInteraction(signalID, user1ID, user2ID uint, interactionType models.InteractionType) error {
	interaction := &models.SignalInteraction{
		SignalID:        signalID,
		User1ID:         user1ID,
		User2ID:         user2ID,
		InteractionType: string(interactionType),
		CreatedAt:       time.Now(),
	}

	return s.buddyRepo.CreateSignalInteraction(interaction)
}

// UpdateInteractionType 상호작용 타입 업데이트
func (s *BuddyService) UpdateInteractionType(signalID, user1ID, user2ID uint, interactionType models.InteractionType) error {
	return s.buddyRepo.UpdateInteractionType(signalID, user1ID, user2ID, interactionType)
}