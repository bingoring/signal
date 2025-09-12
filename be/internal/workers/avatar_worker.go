package workers

import (
	"fmt"
	"time"

	"gorm.io/gorm"
	"signal-be/internal/events"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
)

// AvatarWorker 아바타 통계 처리 워커
type AvatarWorker struct {
	db     *gorm.DB
	logger *logger.Logger
}

// NewAvatarWorker 새로운 아바타 워커 생성
func NewAvatarWorker(db *gorm.DB, logger *logger.Logger) *AvatarWorker {
	return &AvatarWorker{
		db:     db,
		logger: logger,
	}
}

// GetName 워커 이름 반환
func (w *AvatarWorker) GetName() string {
	return "AvatarStatisticsWorker"
}

// CanHandle 처리 가능한 이벤트 타입 확인
func (w *AvatarWorker) CanHandle(eventType events.EventType) bool {
	switch eventType {
	case events.EventAvatarSet, events.EventAvatarFavorite, events.EventAvatarUnfavorite:
		return true
	default:
		return false
	}
}

// Handle 이벤트 처리
func (w *AvatarWorker) Handle(event events.Event) error {
	avatarEvent, ok := event.(*events.AvatarEvent)
	if !ok {
		return fmt.Errorf("invalid event type for avatar worker: %T", event)
	}

	w.logger.Info(fmt.Sprintf("Processing avatar event %s: user %d, avatar %d, action %s", 
		avatarEvent.GetID(), avatarEvent.GetUserID(), avatarEvent.AvatarID, avatarEvent.Action))

	switch avatarEvent.Action {
	case "set":
		return w.handleAvatarSet(avatarEvent)
	case "favorite":
		return w.handleAvatarFavorite(avatarEvent)
	case "unfavorite":
		return w.handleAvatarUnfavorite(avatarEvent)
	default:
		return fmt.Errorf("unknown avatar action: %s", avatarEvent.Action)
	}
}

// handleAvatarSet 아바타 설정 처리
func (w *AvatarWorker) handleAvatarSet(event *events.AvatarEvent) error {
	return w.db.Transaction(func(tx *gorm.DB) error {
		now := time.Now()

		// 1. 아바타 사용 통계 업데이트
		if err := w.incrementAvatarUsage(tx, event.AvatarID); err != nil {
			return fmt.Errorf("failed to increment avatar usage: %w", err)
		}

		// 2. 사용자-아바타 관계 업데이트/생성
		if err := w.updateUserAvatarRelation(tx, event.GetUserID(), event.AvatarID, now); err != nil {
			return fmt.Errorf("failed to update user avatar relation: %w", err)
		}

		// 3. 사용자 프로필의 last_activity_at 업데이트
		if err := w.updateUserActivity(tx, event.GetUserID(), now); err != nil {
			return fmt.Errorf("failed to update user activity: %w", err)
		}

		// 4. 이전 아바타가 있다면 통계에서 감소 (선택사항)
		if event.PrevAvatarID > 0 && event.PrevAvatarID != event.AvatarID {
			w.logger.Info(fmt.Sprintf("User %d changed from avatar %d to %d", 
				event.GetUserID(), event.PrevAvatarID, event.AvatarID))
		}

		return nil
	})
}

// handleAvatarFavorite 아바타 즐겨찾기 추가 처리
func (w *AvatarWorker) handleAvatarFavorite(event *events.AvatarEvent) error {
	return w.db.Transaction(func(tx *gorm.DB) error {
		// 사용자-아바타 관계에서 즐겨찾기 설정
		result := tx.Model(&models.UserAvatar{}).
			Where("user_id = ? AND avatar_id = ?", event.GetUserID(), event.AvatarID).
			Update("is_favorite", true)

		if result.Error != nil {
			return fmt.Errorf("failed to set avatar favorite: %w", result.Error)
		}

		// 관계가 없다면 새로 생성
		if result.RowsAffected == 0 {
			userAvatar := &models.UserAvatar{
				UserID:     event.GetUserID(),
				AvatarID:   event.AvatarID,
				IsFavorite: true,
				UsageCount: 0,
				CreatedAt:  event.GetTimestamp(),
				UpdatedAt:  event.GetTimestamp(),
			}

			if err := tx.Create(userAvatar).Error; err != nil {
				return fmt.Errorf("failed to create favorite avatar relation: %w", err)
			}
		}

		w.logger.Info(fmt.Sprintf("User %d added avatar %d to favorites", 
			event.GetUserID(), event.AvatarID))

		return nil
	})
}

// handleAvatarUnfavorite 아바타 즐겨찾기 제거 처리
func (w *AvatarWorker) handleAvatarUnfavorite(event *events.AvatarEvent) error {
	result := w.db.Model(&models.UserAvatar{}).
		Where("user_id = ? AND avatar_id = ?", event.GetUserID(), event.AvatarID).
		Update("is_favorite", false)

	if result.Error != nil {
		return fmt.Errorf("failed to unset avatar favorite: %w", result.Error)
	}

	w.logger.Info(fmt.Sprintf("User %d removed avatar %d from favorites", 
		event.GetUserID(), event.AvatarID))

	return nil
}

// incrementAvatarUsage 아바타 사용 횟수 증가
func (w *AvatarWorker) incrementAvatarUsage(tx *gorm.DB, avatarID uint) error {
	result := tx.Model(&models.Avatar{}).
		Where("id = ?", avatarID).
		UpdateColumn("usage_count", gorm.Expr("usage_count + 1"))

	if result.Error != nil {
		return result.Error
	}

	if result.RowsAffected == 0 {
		return fmt.Errorf("avatar %d not found", avatarID)
	}

	return nil
}

// updateUserAvatarRelation 사용자-아바타 관계 업데이트
func (w *AvatarWorker) updateUserAvatarRelation(tx *gorm.DB, userID, avatarID uint, timestamp time.Time) error {
	// 기존 관계가 있는지 확인
	var existing models.UserAvatar
	err := tx.Where("user_id = ? AND avatar_id = ?", userID, avatarID).First(&existing).Error

	if err == gorm.ErrRecordNotFound {
		// 새 관계 생성
		userAvatar := &models.UserAvatar{
			UserID:     userID,
			AvatarID:   avatarID,
			LastUsed:   &timestamp,
			UsageCount: 1,
			CreatedAt:  timestamp,
			UpdatedAt:  timestamp,
		}
		return tx.Create(userAvatar).Error
	} else if err != nil {
		return err
	}

	// 기존 관계 업데이트
	return tx.Model(&existing).Updates(map[string]interface{}{
		"last_used":    timestamp,
		"usage_count":  gorm.Expr("usage_count + 1"),
		"updated_at":   timestamp,
	}).Error
}

// updateUserActivity 사용자 활동 시간 업데이트
func (w *AvatarWorker) updateUserActivity(tx *gorm.DB, userID uint, timestamp time.Time) error {
	return tx.Model(&models.UserProfile{}).
		Where("user_id = ?", userID).
		Update("last_activity_at", timestamp).Error
}

// BatchUpdatePopularityRankings 인기 아바타 순위 배치 업데이트
func (w *AvatarWorker) BatchUpdatePopularityRankings() error {
	w.logger.Info("Starting batch update of avatar popularity rankings")

	// 1. 전체 인기 순위 계산
	if err := w.updateGlobalPopularityRanking(); err != nil {
		return fmt.Errorf("failed to update global popularity ranking: %w", err)
	}

	// 2. 카테고리별 인기 순위 계산
	if err := w.updateCategoryPopularityRankings(); err != nil {
		return fmt.Errorf("failed to update category popularity rankings: %w", err)
	}

	// 3. 트렌딩 아바타 계산 (최근 7일 기준)
	if err := w.updateTrendingAvatars(); err != nil {
		return fmt.Errorf("failed to update trending avatars: %w", err)
	}

	w.logger.Info("Avatar popularity rankings updated successfully")
	return nil
}

// updateGlobalPopularityRanking 전체 인기 순위 업데이트
func (w *AvatarWorker) updateGlobalPopularityRanking() error {
	type PopularityData struct {
		AvatarID    uint    `json:"avatar_id"`
		UsageCount  int     `json:"usage_count"`
		UniqueUsers int     `json:"unique_users"`
		Popularity  float64 `json:"popularity"`
	}

	var popularityData []PopularityData
	
	query := `
		SELECT 
			a.id as avatar_id,
			a.usage_count,
			COUNT(DISTINCT ua.user_id) as unique_users,
			ROUND(
				(a.usage_count * 0.7 + COUNT(DISTINCT ua.user_id) * 0.3) * 100.0 / 
				(SELECT MAX(combined_score) FROM (
					SELECT (usage_count * 0.7 + COUNT(DISTINCT ua2.user_id) * 0.3) as combined_score
					FROM avatars a2 
					LEFT JOIN user_avatars ua2 ON a2.id = ua2.avatar_id 
					WHERE a2.is_active = true
					GROUP BY a2.id
				) as max_scores),
				2
			) as popularity
		FROM avatars a
		LEFT JOIN user_avatars ua ON a.id = ua.avatar_id
		WHERE a.is_active = true
		GROUP BY a.id, a.usage_count
		ORDER BY popularity DESC, unique_users DESC, a.usage_count DESC
	`

	if err := w.db.Raw(query).Scan(&popularityData).Error; err != nil {
		return err
	}

	// Redis나 별도 캐시에 저장 (여기서는 로그로 대체)
	w.logger.Info(fmt.Sprintf("Updated global popularity rankings for %d avatars", len(popularityData)))
	
	return nil
}

// updateCategoryPopularityRankings 카테고리별 인기 순위 업데이트
func (w *AvatarWorker) updateCategoryPopularityRankings() error {
	var categories []models.AvatarCategory
	if err := w.db.Where("is_active = ?", true).Find(&categories).Error; err != nil {
		return err
	}

	for _, category := range categories {
		query := `
			SELECT 
				a.id as avatar_id,
				a.usage_count,
				COUNT(DISTINCT ua.user_id) as unique_users
			FROM avatars a
			LEFT JOIN user_avatars ua ON a.id = ua.avatar_id
			WHERE a.category_id = ? AND a.is_active = true
			GROUP BY a.id, a.usage_count
			ORDER BY unique_users DESC, a.usage_count DESC
			LIMIT 10
		`

		var categoryPopularity []struct {
			AvatarID    uint `json:"avatar_id"`
			UsageCount  int  `json:"usage_count"`
			UniqueUsers int  `json:"unique_users"`
		}

		if err := w.db.Raw(query, category.ID).Scan(&categoryPopularity).Error; err != nil {
			w.logger.Error(fmt.Sprintf("Failed to update popularity for category %s: %v", category.Name, err))
			continue
		}

		w.logger.Info(fmt.Sprintf("Updated popularity ranking for category %s: %d avatars", 
			category.Name, len(categoryPopularity)))
	}

	return nil
}

// updateTrendingAvatars 트렌딩 아바타 업데이트 (최근 7일 기준)
func (w *AvatarWorker) updateTrendingAvatars() error {
	query := `
		SELECT 
			a.id as avatar_id,
			a.emoji,
			a.name,
			COUNT(DISTINCT ua.user_id) as recent_users,
			SUM(ua.usage_count) as recent_usage
		FROM avatars a
		JOIN user_avatars ua ON a.id = ua.avatar_id
		WHERE a.is_active = true 
		  AND ua.last_used >= DATE_SUB(NOW(), INTERVAL 7 DAY)
		GROUP BY a.id, a.emoji, a.name
		HAVING recent_users >= 2
		ORDER BY recent_users DESC, recent_usage DESC
		LIMIT 20
	`

	var trendingAvatars []struct {
		AvatarID    uint   `json:"avatar_id"`
		Emoji       string `json:"emoji"`
		Name        string `json:"name"`
		RecentUsers int    `json:"recent_users"`
		RecentUsage int    `json:"recent_usage"`
	}

	if err := w.db.Raw(query).Scan(&trendingAvatars).Error; err != nil {
		return err
	}

	w.logger.Info(fmt.Sprintf("Updated trending avatars: %d avatars trending in the last 7 days", 
		len(trendingAvatars)))

	return nil
}

// GetAvatarStatistics 아바타 통계 조회
func (w *AvatarWorker) GetAvatarStatistics() (map[string]interface{}, error) {
	stats := make(map[string]interface{})

	// 전체 아바타 수
	var totalAvatars int64
	w.db.Model(&models.Avatar{}).Where("is_active = ?", true).Count(&totalAvatars)
	stats["total_avatars"] = totalAvatars

	// 사용된 아바타 수
	var usedAvatars int64
	w.db.Model(&models.Avatar{}).Where("is_active = ? AND usage_count > 0", true).Count(&usedAvatars)
	stats["used_avatars"] = usedAvatars

	// 총 사용 횟수
	var totalUsage struct {
		Total int64 `gorm:"column:total"`
	}
	w.db.Model(&models.Avatar{}).
		Select("SUM(usage_count) as total").
		Where("is_active = ?", true).
		Scan(&totalUsage)
	stats["total_usage"] = totalUsage.Total

	// 활성 사용자 수 (아바타를 설정한 사용자)
	var activeUsers int64
	w.db.Table("user_avatars").
		Select("COUNT(DISTINCT user_id)").
		Count(&activeUsers)
	stats["active_users"] = activeUsers

	return stats, nil
}