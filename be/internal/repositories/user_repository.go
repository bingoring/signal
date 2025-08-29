package repositories

import (
	"signal-module/pkg/models"

	"gorm.io/gorm"
)

type UserRepositoryInterface interface {
	Create(user *models.User) error
	GetByID(id uint) (*models.User, error)
	GetByEmail(email string) (*models.User, error)
	GetByUsername(username string) (*models.User, error)
	GetByGoogleID(googleID string) (*models.User, error)
	Update(user *models.User) error
	UpdateLocation(userID uint, location *models.UserLocation) error
	UpdateInterests(userID uint, interests []models.UserInterest) error
	AddPushToken(token *models.PushToken) error
	GetPushTokens(userID uint) ([]models.PushToken, error)
	GetUsersInRadius(latitude, longitude, radius float64, excludeUserID uint) ([]models.User, error)
	GetMatchedUsersForSignal(signal *models.Signal) ([]models.User, error)
	RateUser(rating *models.UserRating) error
	ReportUser(report *models.ReportUser) error
}

type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) UserRepositoryInterface {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(user *models.User) error {
	return r.db.Create(user).Error
}

func (r *UserRepository) GetByID(id uint) (*models.User, error) {
	var user models.User
	err := r.db.Preload("Profile").
		Preload("Location").
		Preload("Interests").
		First(&user, id).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) GetByEmail(email string) (*models.User, error) {
	var user models.User
	err := r.db.Preload("Profile").Where("email = ?", email).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) GetByUsername(username string) (*models.User, error) {
	var user models.User
	err := r.db.Where("username = ?", username).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) GetByGoogleID(googleID string) (*models.User, error) {
	var user models.User
	err := r.db.Preload("Profile").Where("google_id = ?", googleID).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) Update(user *models.User) error {
	return r.db.Save(user).Error
}

func (r *UserRepository) UpdateLocation(userID uint, location *models.UserLocation) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 기존 위치 비활성화
		if err := tx.Model(&models.UserLocation{}).
			Where("user_id = ? AND is_active = ?", userID, true).
			Update("is_active", false).Error; err != nil {
			return err
		}

		// 새 위치 추가
		location.UserID = userID
		location.IsActive = true
		return tx.Create(location).Error
	})
}

func (r *UserRepository) UpdateInterests(userID uint, interests []models.UserInterest) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 기존 관심사 삭제
		if err := tx.Where("user_id = ?", userID).Delete(&models.UserInterest{}).Error; err != nil {
			return err
		}

		// 새 관심사 추가
		for i := range interests {
			interests[i].UserID = userID
		}
		return tx.Create(&interests).Error
	})
}

func (r *UserRepository) AddPushToken(token *models.PushToken) error {
	// 기존 동일한 토큰이 있으면 업데이트, 없으면 생성
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 같은 사용자의 동일한 플랫폼 토큰을 비활성화
		if err := tx.Model(&models.PushToken{}).
			Where("user_id = ? AND platform = ? AND is_active = ?", token.UserID, token.Platform, true).
			Update("is_active", false).Error; err != nil {
			return err
		}

		// 새 토큰 생성
		token.IsActive = true
		return tx.Create(token).Error
	})
}

func (r *UserRepository) GetPushTokens(userID uint) ([]models.PushToken, error) {
	var tokens []models.PushToken
	err := r.db.Where("user_id = ? AND is_active = ?", userID, true).Find(&tokens).Error
	return tokens, err
}

func (r *UserRepository) GetUsersInRadius(latitude, longitude, radius float64, excludeUserID uint) ([]models.User, error) {
	var users []models.User
	
	// PostGIS를 사용한 지리적 검색
	query := `
		SELECT DISTINCT u.* FROM users u
		JOIN user_locations ul ON u.id = ul.user_id
		WHERE ul.is_active = true
		AND u.id != ?
		AND u.is_active = true
		AND u.is_blocked = false
		AND ST_DWithin(
			ST_SetSRID(ST_MakePoint(ul.longitude, ul.latitude), 4326)::geography,
			ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
			?
		)
	`
	
	err := r.db.Preload("Profile").
		Raw(query, excludeUserID, longitude, latitude, radius).
		Find(&users).Error
	
	return users, err
}

// GetMatchedUsersForSignal 시그널에 매칭되는 사용자들 조회
func (r *UserRepository) GetMatchedUsersForSignal(signal *models.Signal) ([]models.User, error) {
	var users []models.User
	
	// 관심사가 같고, 반경 내에 있으며, 연령대가 맞는 사용자들을 찾음
	query := r.db.Preload("Profile").
		Joins("JOIN user_profiles ON user_profiles.user_id = users.id").
		Joins("LEFT JOIN user_interests ON user_interests.user_id = users.id").
		Joins("LEFT JOIN user_locations ON user_locations.user_id = users.id").
		Where("users.is_active = ?", true).
		Where("users.id != ?", signal.CreatorID). // 생성자 제외
		Where("user_interests.category = ?", signal.Category)

	// 연령대 필터링
	if signal.MinAge > 0 && signal.MaxAge > 0 {
		query = query.Where("user_profiles.age BETWEEN ? AND ?", signal.MinAge, signal.MaxAge)
	}

	// 성별 필터링
	if signal.GenderPreference != "" && signal.GenderPreference != "any" {
		query = query.Where("user_profiles.gender = ?", signal.GenderPreference)
	}

	// 위치 기반 필터링 (10km 반경)
	query = query.Where(`
		ST_DWithin(
			ST_SetSRID(ST_MakePoint(user_locations.longitude, user_locations.latitude), 4326)::geography,
			ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
			10000
		)
	`, signal.Longitude, signal.Latitude)

	// 매너 점수가 30점 이상인 사용자만
	query = query.Where("user_profiles.manner_score >= ?", 30.0)

	// 최대 50명까지만 알림
	err := query.Limit(50).Find(&users).Error
	
	return users, err
}

func (r *UserRepository) RateUser(rating *models.UserRating) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 평가 저장
		if err := tx.Create(rating).Error; err != nil {
			return err
		}

		// 평가받은 사용자의 매너 점수 업데이트
		var profile models.UserProfile
		if err := tx.Where("user_id = ?", rating.RateeID).First(&profile).Error; err != nil {
			return err
		}

		// 새 평균 점수 계산
		totalScore := float64(profile.TotalRatings)*profile.MannerScore + float64(rating.Score)
		profile.TotalRatings++
		profile.MannerScore = totalScore / float64(profile.TotalRatings)

		if rating.IsNoShow {
			profile.NoShowCount++
		}

		return tx.Save(&profile).Error
	})
}

func (r *UserRepository) ReportUser(report *models.ReportUser) error {
	return r.db.Create(report).Error
}