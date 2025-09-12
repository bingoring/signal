package repositories

import (
	"fmt"
	"time"

	"gorm.io/gorm"

	"signal-module/pkg/models"
)

type AvatarRepository interface {
	// 카테고리 관련
	GetActiveCategories() ([]models.AvatarCategory, error)
	GetCategoryByID(id uint) (models.AvatarCategory, error)
	GetAvatarsByCategory(categoryID uint) ([]models.Avatar, error)
	
	// 아바타 관련
	GetAvatarByID(id uint) (models.Avatar, error)
	GetAvatarByEmoji(emoji string) (models.Avatar, error)
	GetDefaultAvatars() ([]models.Avatar, error)
	GetPopularAvatars(limit int) ([]models.AvatarStats, error)
	GetPopularAvatarsByCategory(categoryID uint, limit int) ([]models.Avatar, error)
	IncrementAvatarUsage(tx *gorm.DB, avatarID uint) error
	
	// 검색 관련
	SearchAvatars(query string, categoryID *uint, limit int) ([]models.Avatar, int, error)
	
	// 사용자-아바타 관계
	GetUserAvatar(userID, avatarID uint) (models.UserAvatar, error)
	CreateUserAvatar(userAvatar *models.UserAvatar) error
	UpdateUserAvatarUsage(tx *gorm.DB, userID, avatarID uint) error
	UpdateUserAvatarFavorite(userID, avatarID uint, isFavorite bool) error
	GetUserFavoriteAvatars(userID uint) ([]models.Avatar, error)
	GetUserRecentAvatars(userID uint, limit int) ([]models.Avatar, error)
	GetUserCategoryStats(userID uint) ([]models.CategoryUsage, error)
}

type avatarRepository struct {
	db *gorm.DB
}

func NewAvatarRepository(db *gorm.DB) AvatarRepository {
	return &avatarRepository{db: db}
}

// GetActiveCategories 활성 아바타 카테고리 목록 조회
func (r *avatarRepository) GetActiveCategories() ([]models.AvatarCategory, error) {
	var categories []models.AvatarCategory
	err := r.db.Where("is_active = ?", true).
		Order("sort_order ASC, display_name ASC").
		Find(&categories).Error
	return categories, err
}

// GetCategoryByID 카테고리 ID로 조회
func (r *avatarRepository) GetCategoryByID(id uint) (models.AvatarCategory, error) {
	var category models.AvatarCategory
	err := r.db.First(&category, id).Error
	return category, err
}

// GetAvatarsByCategory 카테고리별 아바타 목록 조회
func (r *avatarRepository) GetAvatarsByCategory(categoryID uint) ([]models.Avatar, error) {
	var avatars []models.Avatar
	err := r.db.Preload("Category").
		Where("category_id = ? AND is_active = ?", categoryID, true).
		Order("sort_order ASC, name ASC").
		Find(&avatars).Error
	return avatars, err
}

// GetAvatarByID 아바타 ID로 조회
func (r *avatarRepository) GetAvatarByID(id uint) (models.Avatar, error) {
	var avatar models.Avatar
	err := r.db.Preload("Category").First(&avatar, id).Error
	return avatar, err
}

// GetAvatarByEmoji 이모지로 아바타 조회
func (r *avatarRepository) GetAvatarByEmoji(emoji string) (models.Avatar, error) {
	var avatar models.Avatar
	err := r.db.Preload("Category").
		Where("emoji = ? AND is_active = ?", emoji, true).
		First(&avatar).Error
	return avatar, err
}

// GetDefaultAvatars 기본 추천 아바타 목록
func (r *avatarRepository) GetDefaultAvatars() ([]models.Avatar, error) {
	var avatars []models.Avatar
	err := r.db.Preload("Category").
		Where("is_default = ? AND is_active = ?", true, true).
		Order("sort_order ASC, name ASC").
		Find(&avatars).Error
	return avatars, err
}

// GetPopularAvatars 인기 아바타 통계
func (r *avatarRepository) GetPopularAvatars(limit int) ([]models.AvatarStats, error) {
	var stats []models.AvatarStats
	
	query := `
		SELECT 
			a.id as avatar_id,
			a.emoji,
			a.name,
			a.category_id,
			a.usage_count,
			COUNT(DISTINCT ua.user_id) as unique_users,
			ROUND(COUNT(DISTINCT ua.user_id) * 100.0 / (
				SELECT COUNT(DISTINCT user_id) 
				FROM user_profiles 
				WHERE avatar IS NOT NULL
			), 2) as popularity
		FROM avatars a
		LEFT JOIN user_avatars ua ON a.id = ua.avatar_id
		WHERE a.is_active = TRUE
		GROUP BY a.id, a.emoji, a.name, a.category_id, a.usage_count
		ORDER BY unique_users DESC, a.usage_count DESC
		LIMIT ?
	`
	
	err := r.db.Raw(query, limit).Scan(&stats).Error
	return stats, err
}

// GetPopularAvatarsByCategory 카테고리별 인기 아바타
func (r *avatarRepository) GetPopularAvatarsByCategory(categoryID uint, limit int) ([]models.Avatar, error) {
	var avatars []models.Avatar
	err := r.db.Preload("Category").
		Where("category_id = ? AND is_active = ?", categoryID, true).
		Order("usage_count DESC, sort_order ASC").
		Limit(limit).
		Find(&avatars).Error
	return avatars, err
}

// IncrementAvatarUsage 아바타 사용 통계 증가
func (r *avatarRepository) IncrementAvatarUsage(tx *gorm.DB, avatarID uint) error {
	return tx.Model(&models.Avatar{}).
		Where("id = ?", avatarID).
		UpdateColumn("usage_count", gorm.Expr("usage_count + ?", 1)).Error
}

// SearchAvatars 아바타 검색
func (r *avatarRepository) SearchAvatars(query string, categoryID *uint, limit int) ([]models.Avatar, int, error) {
	var avatars []models.Avatar
	var total int64

	// 기본 쿼리 구성
	db := r.db.Model(&models.Avatar{}).Preload("Category").Where("is_active = ?", true)

	// 카테고리 필터
	if categoryID != nil {
		db = db.Where("category_id = ?", *categoryID)
	}

	// 검색 조건 - 여러 필드에서 검색
	searchCondition := r.db.Where("name LIKE ?", "%"+query+"%").
		Or("description LIKE ?", "%"+query+"%").
		Or("keywords LIKE ?", "%"+query+"%")

	db = db.Where(searchCondition)

	// 총 개수 카운트
	err := db.Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	// 결과 조회 - 관련도 순으로 정렬
	orderClause := fmt.Sprintf(`
		CASE 
			WHEN name LIKE '%s' THEN 1
			WHEN description LIKE '%s' THEN 2
			WHEN keywords LIKE '%s' THEN 3
			ELSE 4
		END, usage_count DESC, sort_order ASC
	`, "%"+query+"%", "%"+query+"%", "%"+query+"%")
	
	err = db.Order(orderClause).
		Limit(limit).
		Find(&avatars).Error

	return avatars, int(total), err
}

// GetUserAvatar 사용자-아바타 관계 조회
func (r *avatarRepository) GetUserAvatar(userID, avatarID uint) (models.UserAvatar, error) {
	var userAvatar models.UserAvatar
	err := r.db.Where("user_id = ? AND avatar_id = ?", userID, avatarID).
		First(&userAvatar).Error
	return userAvatar, err
}

// CreateUserAvatar 사용자-아바타 관계 생성
func (r *avatarRepository) CreateUserAvatar(userAvatar *models.UserAvatar) error {
	return r.db.Create(userAvatar).Error
}

// UpdateUserAvatarUsage 사용자-아바타 사용 기록 업데이트
func (r *avatarRepository) UpdateUserAvatarUsage(tx *gorm.DB, userID, avatarID uint) error {
	now := time.Now()
	
	// 기존 기록이 있는지 확인
	var existing models.UserAvatar
	err := tx.Where("user_id = ? AND avatar_id = ?", userID, avatarID).First(&existing).Error
	
	if err == gorm.ErrRecordNotFound {
		// 새 기록 생성
		userAvatar := &models.UserAvatar{
			UserID:     userID,
			AvatarID:   avatarID,
			LastUsed:   now,
			UsageCount: 1,
			CreatedAt:  now,
			UpdatedAt:  now,
		}
		return tx.Create(userAvatar).Error
	} else if err != nil {
		return err
	}

	// 기존 기록 업데이트
	return tx.Model(&existing).Updates(models.UserAvatar{
		LastUsed:   now,
		UsageCount: existing.UsageCount + 1,
		UpdatedAt:  now,
	}).Error
}

// UpdateUserAvatarFavorite 즐겨찾기 상태 업데이트
func (r *avatarRepository) UpdateUserAvatarFavorite(userID, avatarID uint, isFavorite bool) error {
	return r.db.Model(&models.UserAvatar{}).
		Where("user_id = ? AND avatar_id = ?", userID, avatarID).
		Update("is_favorite", isFavorite).Error
}

// GetUserFavoriteAvatars 사용자 즐겨찾기 아바타 목록
func (r *avatarRepository) GetUserFavoriteAvatars(userID uint) ([]models.Avatar, error) {
	var avatars []models.Avatar
	
	err := r.db.Preload("Category").
		Joins("JOIN user_avatars ua ON avatars.id = ua.avatar_id").
		Where("ua.user_id = ? AND ua.is_favorite = ? AND avatars.is_active = ?", 
			userID, true, true).
		Order("ua.updated_at DESC").
		Find(&avatars).Error
		
	return avatars, err
}

// GetUserRecentAvatars 사용자 최근 사용 아바타 목록
func (r *avatarRepository) GetUserRecentAvatars(userID uint, limit int) ([]models.Avatar, error) {
	var avatars []models.Avatar
	
	err := r.db.Preload("Category").
		Joins("JOIN user_avatars ua ON avatars.id = ua.avatar_id").
		Where("ua.user_id = ? AND ua.last_used IS NOT NULL AND avatars.is_active = ?", 
			userID, true).
		Order("ua.last_used DESC").
		Limit(limit).
		Find(&avatars).Error
		
	return avatars, err
}

// GetUserCategoryStats 사용자의 카테고리별 사용 통계
func (r *avatarRepository) GetUserCategoryStats(userID uint) ([]models.CategoryUsage, error) {
	var stats []models.CategoryUsage
	
	query := `
		SELECT 
			ac.id as category_id,
			ac.display_name as category_name,
			SUM(ua.usage_count) as usage_count,
			ROUND(SUM(ua.usage_count) * 100.0 / (
				SELECT SUM(usage_count) 
				FROM user_avatars 
				WHERE user_id = ?
			), 2) as percentage
		FROM user_avatars ua
		JOIN avatars a ON ua.avatar_id = a.id
		JOIN avatar_categories ac ON a.category_id = ac.id
		WHERE ua.user_id = ? AND a.is_active = TRUE
		GROUP BY ac.id, ac.display_name
		HAVING usage_count > 0
		ORDER BY usage_count DESC, ac.display_name ASC
	`
	
	err := r.db.Raw(query, userID, userID).Scan(&stats).Error
	return stats, err
}

// Advanced search methods

// GetSimilarAvatars 유사한 아바타 추천 (키워드 기반)
func (r *avatarRepository) GetSimilarAvatars(avatarID uint, limit int) ([]models.Avatar, error) {
	// 기준 아바타의 키워드 가져오기
	var baseAvatar models.Avatar
	err := r.db.First(&baseAvatar, avatarID).Error
	if err != nil {
		return nil, err
	}

	var avatars []models.Avatar
	err = r.db.Preload("Category").
		Where("id != ? AND is_active = ?", avatarID, true).
		Where("keywords LIKE ? OR description LIKE ?", 
			"%"+baseAvatar.Keywords+"%", "%"+baseAvatar.Description+"%").
		Order("usage_count DESC").
		Limit(limit).
		Find(&avatars).Error

	return avatars, err
}

// GetTrendingAvatars 트렌딩 아바타 (최근 일주일 기준)
func (r *avatarRepository) GetTrendingAvatars(limit int) ([]models.Avatar, error) {
	var avatars []models.Avatar
	
	query := `
		SELECT DISTINCT a.*
		FROM avatars a
		JOIN user_avatars ua ON a.id = ua.avatar_id
		WHERE a.is_active = TRUE 
		AND ua.last_used >= DATE_SUB(NOW(), INTERVAL 7 DAY)
		ORDER BY COUNT(ua.user_id) DESC, a.usage_count DESC
		LIMIT ?
	`
	
	err := r.db.Preload("Category").Raw(query, limit).Find(&avatars).Error
	return avatars, err
}

// GetAvatarRecommendations 사용자 맞춤 아바타 추천
func (r *avatarRepository) GetAvatarRecommendations(userID uint, limit int) ([]models.Avatar, error) {
	// 사용자의 선호 카테고리 분석
	categoryStats, err := r.GetUserCategoryStats(userID)
	if err != nil || len(categoryStats) == 0 {
		// 통계가 없으면 기본 추천 아바타 반환
		return r.GetDefaultAvatars()
	}

	// 가장 선호하는 카테고리의 인기 아바타 추천
	preferredCategoryID := categoryStats[0].CategoryID
	return r.GetPopularAvatarsByCategory(preferredCategoryID, limit)
}

// Batch operations

// BulkUpdateAvatarUsageStats 아바타 사용 통계 일괄 업데이트
func (r *avatarRepository) BulkUpdateAvatarUsageStats() error {
	query := `
		UPDATE avatars a
		SET usage_count = (
			SELECT COUNT(*)
			FROM user_avatars ua
			WHERE ua.avatar_id = a.id
		)
	`
	return r.db.Exec(query).Error
}

// CleanupOldAvatarRecords 오래된 아바타 사용 기록 정리 (30일 이상)
func (r *avatarRepository) CleanupOldAvatarRecords() error {
	return r.db.Where("last_used < ? AND is_favorite = ?", 
		time.Now().AddDate(0, 0, -30), false).
		Delete(&models.UserAvatar{}).Error
}