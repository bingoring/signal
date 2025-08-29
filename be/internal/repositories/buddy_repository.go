package repositories

import (
	"fmt"
	"time"

	"signal-module/pkg/models"
	"signal-module/pkg/utils"

	"gorm.io/gorm"
)

type BuddyRepositoryInterface interface {
	// 단골 관계 관리
	CreateBuddy(buddy *models.UserBuddy) error
	GetBuddyRelationship(user1ID, user2ID uint) (*models.UserBuddy, error)
	UpdateBuddy(buddy *models.UserBuddy) error
	DeleteBuddy(user1ID, user2ID uint) error

	// 단골 목록 조회
	GetUserBuddies(userID uint, query *models.GetBuddiesQuery) ([]models.BuddyRelationship, int64, error)
	GetBuddyStats(userID uint) (*models.BuddyStats, error)
	GetPotentialBuddies(userID uint, minInteractions int, minMannerScore float64) ([]models.PotentialBuddy, error)

	// 매너 점수 관리
	CreateMannerLog(log *models.MannerScoreLog) error
	GetMannerLogs(userID uint, page, limit int) ([]models.MannerScoreLog, int64, error)
	GetMannerScoreHistory(userID uint, days int) ([]models.MannerScoreHistoryPoint, error)

	// 단골 초대 관리
	CreateBuddyInvitation(invitation *models.BuddyInvitation) error
	GetBuddyInvitation(id uint) (*models.BuddyInvitation, error)
	UpdateBuddyInvitation(invitation *models.BuddyInvitation) error
	GetUserInvitations(userID uint, status []models.InvitationStatus, page, limit int) ([]models.BuddyInvitation, int64, error)
	ExpireInvitations() error

	// 시그널 상호작용 관리
	CreateSignalInteraction(interaction *models.SignalInteraction) error
	GetSignalInteractions(signalID uint) ([]models.SignalInteraction, error)
	UpdateInteractionType(signalID, user1ID, user2ID uint, interactionType models.InteractionType) error
}

type BuddyRepository struct {
	db *gorm.DB
}

func NewBuddyRepository(db *gorm.DB) BuddyRepositoryInterface {
	return &BuddyRepository{db: db}
}

// CreateBuddy 새로운 단골 관계 생성
func (r *BuddyRepository) CreateBuddy(buddy *models.UserBuddy) error {
	// 작은 ID를 user1_id로, 큰 ID를 user2_id로 정규화
	if buddy.User1ID > buddy.User2ID {
		buddy.User1ID, buddy.User2ID = buddy.User2ID, buddy.User1ID
	}

	return r.db.Create(buddy).Error
}

// GetBuddyRelationship 두 사용자 간의 단골 관계 조회
func (r *BuddyRepository) GetBuddyRelationship(user1ID, user2ID uint) (*models.UserBuddy, error) {
	var buddy models.UserBuddy
	
	// ID 정규화 (작은 값이 user1_id)
	if user1ID > user2ID {
		user1ID, user2ID = user2ID, user1ID
	}

	err := r.db.Where("user1_id = ? AND user2_id = ?", user1ID, user2ID).
		Preload("User1.Profile").
		Preload("User2.Profile").
		First(&buddy).Error

	if err != nil {
		return nil, err
	}
	
	return &buddy, nil
}

// UpdateBuddy 단골 관계 업데이트
func (r *BuddyRepository) UpdateBuddy(buddy *models.UserBuddy) error {
	return r.db.Save(buddy).Error
}

// DeleteBuddy 단골 관계 삭제
func (r *BuddyRepository) DeleteBuddy(user1ID, user2ID uint) error {
	if user1ID > user2ID {
		user1ID, user2ID = user2ID, user1ID
	}

	return r.db.Where("user1_id = ? AND user2_id = ?", user1ID, user2ID).
		Delete(&models.UserBuddy{}).Error
}

// GetUserBuddies 사용자의 단골 목록 조회
func (r *BuddyRepository) GetUserBuddies(userID uint, query *models.GetBuddiesQuery) ([]models.BuddyRelationship, int64, error) {
	var relationships []models.BuddyRelationship
	var total int64

	// 기본 쿼리
	db := r.db.Table("buddy_relationships").
		Where("user_id = ? OR buddy_id = ?", userID, userID)

	// 필터링
	if query.Status != nil {
		db = db.Where("status = ?", *query.Status)
	}

	if query.MinCompatibility != nil {
		db = db.Where("compatibility_score >= ?", *query.MinCompatibility)
	}

	if query.MinInteractions != nil {
		db = db.Where("interaction_count >= ?", *query.MinInteractions)
	}

	// 총 개수 계산
	if err := db.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// 정렬 및 페이지네이션
	query.SetDefaults()
	offset := utils.CalculateOffset(query.Page, query.Limit)
	
	orderClause := fmt.Sprintf("%s %s", query.SortBy, query.SortOrder)
	err := db.Order(orderClause).
		Offset(offset).
		Limit(query.Limit).
		Find(&relationships).Error

	// 현재 사용자 관점에서 정규화
	for i := range relationships {
		rel := &relationships[i]
		if rel.UserID != userID {
			// UserID와 BuddyID 스왑
			rel.UserID, rel.BuddyID = rel.BuddyID, rel.UserID
			rel.UserName, rel.BuddyName = rel.BuddyName, rel.UserName
			rel.UserDisplayName, rel.BuddyDisplayName = rel.BuddyDisplayName, rel.UserDisplayName
			rel.UserMannerScore, rel.BuddyMannerScore = rel.BuddyMannerScore, rel.UserMannerScore
		}
	}

	return relationships, total, err
}

// GetBuddyStats 사용자의 단골 통계 조회
func (r *BuddyRepository) GetBuddyStats(userID uint) (*models.BuddyStats, error) {
	stats := &models.BuddyStats{}

	// 기본 통계
	var totalBuddies, activeBuddies int64
	var avgCompatibility float64

	r.db.Model(&models.UserBuddy{}).
		Where("(user1_id = ? OR user2_id = ?)", userID, userID).
		Count(&totalBuddies)

	r.db.Model(&models.UserBuddy{}).
		Where("(user1_id = ? OR user2_id = ?) AND status = ?", userID, userID, models.BuddyStatusActive).
		Count(&activeBuddies)

	r.db.Model(&models.UserBuddy{}).
		Where("(user1_id = ? OR user2_id = ?) AND status = ?", userID, userID, models.BuddyStatusActive).
		Select("AVG(compatibility_score)").
		Scan(&avgCompatibility)

	stats.TotalBuddies = int(totalBuddies)
	stats.ActiveBuddies = int(activeBuddies)
	stats.AverageCompatibility = avgCompatibility

	// 총 상호작용 수
	var totalInteractions int64
	r.db.Model(&models.SignalInteraction{}).
		Where("user1_id = ? OR user2_id = ?", userID, userID).
		Count(&totalInteractions)
	stats.TotalInteractions = int(totalInteractions)

	// 매너 점수 히스토리
	history, _ := r.GetMannerScoreHistory(userID, 30)
	stats.MannerScoreHistory = history

	// 최근 단골들
	recentQuery := &models.GetBuddiesQuery{
		SortBy:    "created_at",
		SortOrder: "desc",
		Page:      1,
		Limit:     5,
	}
	recentQuery.SetDefaults()
	recentBuddies, _, _ := r.GetUserBuddies(userID, recentQuery)
	stats.RecentBuddies = recentBuddies

	// 카테고리별 매너 점수 분석
	var categoryBreakdown []struct {
		Category string  `json:"category"`
		AvgScore float64 `json:"avg_score"`
	}
	r.db.Model(&models.MannerScoreLog{}).
		Where("ratee_id = ?", userID).
		Select("category, AVG(score_change) as avg_score").
		Group("category").
		Find(&categoryBreakdown)

	stats.CategoryBreakdown = make(map[models.MannerCategory]float64)
	for _, cb := range categoryBreakdown {
		stats.CategoryBreakdown[models.MannerCategory(cb.Category)] = cb.AvgScore
	}

	return stats, nil
}

// GetPotentialBuddies 단골 후보자 조회 (stored procedure 사용)
func (r *BuddyRepository) GetPotentialBuddies(userID uint, minInteractions int, minMannerScore float64) ([]models.PotentialBuddy, error) {
	var candidates []models.PotentialBuddy

	query := `
		SELECT * FROM get_potential_buddies(?, ?, ?)
	`

	err := r.db.Raw(query, userID, minInteractions, minMannerScore).Scan(&candidates).Error
	return candidates, err
}

// CreateMannerLog 매너 점수 로그 생성
func (r *BuddyRepository) CreateMannerLog(log *models.MannerScoreLog) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 매너 로그 저장
		if err := tx.Create(log).Error; err != nil {
			return err
		}

		// 사용자 프로필의 매너 점수 업데이트
		return r.updateUserMannerScore(tx, log.RateeID)
	})
}

// updateUserMannerScore 사용자의 매너 점수 재계산
func (r *BuddyRepository) updateUserMannerScore(tx *gorm.DB, userID uint) error {
	// 최근 30일간의 매너 점수 변화량 합계 계산
	var totalScoreChange float64
	var logCount int64

	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)
	
	err := tx.Model(&models.MannerScoreLog{}).
		Where("ratee_id = ? AND created_at >= ?", userID, thirtyDaysAgo).
		Select("SUM(score_change)").
		Scan(&totalScoreChange).Error
	
	if err != nil {
		return err
	}

	err = tx.Model(&models.MannerScoreLog{}).
		Where("ratee_id = ? AND created_at >= ?", userID, thirtyDaysAgo).
		Count(&logCount).Error
		
	if err != nil {
		return err
	}

	// 기본 점수 5.0에서 시작하여 평균 변화량 적용
	baseScore := 5.0
	var newScore float64
	
	if logCount > 0 {
		avgChange := totalScoreChange / float64(logCount)
		newScore = baseScore + avgChange
	} else {
		newScore = baseScore
	}

	// 점수 범위 제한 (0.0 ~ 10.0)
	if newScore < 0.0 {
		newScore = 0.0
	} else if newScore > 10.0 {
		newScore = 10.0
	}

	// 프로필 업데이트
	return tx.Model(&models.UserProfile{}).
		Where("user_id = ?", userID).
		Update("manner_score", newScore).Error
}

// GetMannerLogs 매너 점수 로그 조회
func (r *BuddyRepository) GetMannerLogs(userID uint, page, limit int) ([]models.MannerScoreLog, int64, error) {
	var logs []models.MannerScoreLog
	var total int64

	// 총 개수 계산
	r.db.Model(&models.MannerScoreLog{}).
		Where("ratee_id = ?", userID).
		Count(&total)

	// 로그 조회
	offset := utils.CalculateOffset(page, limit)
	err := r.db.Where("ratee_id = ?", userID).
		Preload("Rater").
		Preload("Signal").
		Order("created_at DESC").
		Offset(offset).
		Limit(limit).
		Find(&logs).Error

	return logs, total, err
}

// GetMannerScoreHistory 매너 점수 히스토리 조회
func (r *BuddyRepository) GetMannerScoreHistory(userID uint, days int) ([]models.MannerScoreHistoryPoint, error) {
	var history []models.MannerScoreHistoryPoint

	startDate := time.Now().AddDate(0, 0, -days)

	// 일별 매너 점수 변화 조회
	query := `
		WITH daily_scores AS (
			SELECT 
				DATE(created_at) as date,
				AVG(score_change) as daily_score
			FROM manner_score_logs 
			WHERE ratee_id = ? AND created_at >= ?
			GROUP BY DATE(created_at)
			ORDER BY DATE(created_at)
		)
		SELECT 
			date,
			5.0 + AVG(daily_score) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING) as score
		FROM daily_scores
	`

	err := r.db.Raw(query, userID, startDate).Scan(&history).Error
	return history, err
}

// CreateBuddyInvitation 단골 초대 생성
func (r *BuddyRepository) CreateBuddyInvitation(invitation *models.BuddyInvitation) error {
	return r.db.Create(invitation).Error
}

// GetBuddyInvitation 단골 초대 조회
func (r *BuddyRepository) GetBuddyInvitation(id uint) (*models.BuddyInvitation, error) {
	var invitation models.BuddyInvitation
	
	err := r.db.Where("id = ?", id).
		Preload("Signal").
		Preload("Inviter.Profile").
		Preload("Invitee.Profile").
		First(&invitation).Error

	if err != nil {
		return nil, err
	}

	return &invitation, nil
}

// UpdateBuddyInvitation 단골 초대 업데이트
func (r *BuddyRepository) UpdateBuddyInvitation(invitation *models.BuddyInvitation) error {
	return r.db.Save(invitation).Error
}

// GetUserInvitations 사용자의 초대 목록 조회
func (r *BuddyRepository) GetUserInvitations(userID uint, status []models.InvitationStatus, page, limit int) ([]models.BuddyInvitation, int64, error) {
	var invitations []models.BuddyInvitation
	var total int64

	query := r.db.Model(&models.BuddyInvitation{}).
		Where("invitee_id = ?", userID)

	if len(status) > 0 {
		query = query.Where("status IN ?", status)
	}

	// 총 개수 계산
	query.Count(&total)

	// 초대 목록 조회
	offset := utils.CalculateOffset(page, limit)
	err := query.
		Preload("Signal").
		Preload("Inviter.Profile").
		Order("created_at DESC").
		Offset(offset).
		Limit(limit).
		Find(&invitations).Error

	return invitations, total, err
}

// ExpireInvitations 만료된 초대 처리
func (r *BuddyRepository) ExpireInvitations() error {
	return r.db.Model(&models.BuddyInvitation{}).
		Where("status = ? AND expires_at < ?", models.InvitationStatusPending, time.Now()).
		Update("status", models.InvitationStatusExpired).Error
}

// CreateSignalInteraction 시그널 상호작용 생성
func (r *BuddyRepository) CreateSignalInteraction(interaction *models.SignalInteraction) error {
	// ID 정규화
	if interaction.User1ID > interaction.User2ID {
		interaction.User1ID, interaction.User2ID = interaction.User2ID, interaction.User1ID
	}

	return r.db.Create(interaction).Error
}

// GetSignalInteractions 시그널의 모든 상호작용 조회
func (r *BuddyRepository) GetSignalInteractions(signalID uint) ([]models.SignalInteraction, error) {
	var interactions []models.SignalInteraction

	err := r.db.Where("signal_id = ?", signalID).
		Preload("User1.Profile").
		Preload("User2.Profile").
		Find(&interactions).Error

	return interactions, err
}

// UpdateInteractionType 상호작용 타입 업데이트
func (r *BuddyRepository) UpdateInteractionType(signalID, user1ID, user2ID uint, interactionType models.InteractionType) error {
	// ID 정규화
	if user1ID > user2ID {
		user1ID, user2ID = user2ID, user1ID
	}

	return r.db.Model(&models.SignalInteraction{}).
		Where("signal_id = ? AND user1_id = ? AND user2_id = ?", signalID, user1ID, user2ID).
		Update("interaction_type", interactionType).Error
}