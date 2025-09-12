package workers

import (
	"fmt"
	"math"

	"gorm.io/gorm"
	"signal-be/internal/events"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
)

// MannerWorker 매너온도 계산 워커
type MannerWorker struct {
	db     *gorm.DB
	logger *logger.Logger
}

// NewMannerWorker 새로운 매너온도 워커 생성
func NewMannerWorker(db *gorm.DB, logger *logger.Logger) *MannerWorker {
	return &MannerWorker{
		db:     db,
		logger: logger,
	}
}

// GetName 워커 이름 반환
func (w *MannerWorker) GetName() string {
	return "MannerTemperatureWorker"
}

// CanHandle 처리 가능한 이벤트 타입 확인
func (w *MannerWorker) CanHandle(eventType events.EventType) bool {
	switch eventType {
	case events.EventMannerUpdate, events.EventSignalComplete, events.EventUserNoShow:
		return true
	default:
		return false
	}
}

// Handle 이벤트 처리
func (w *MannerWorker) Handle(event events.Event) error {
	mannerEvent, ok := event.(*events.MannerEvent)
	if !ok {
		return fmt.Errorf("invalid event type for manner worker: %T", event)
	}

	w.logger.Info(fmt.Sprintf("Processing manner event %s for user %d", 
		mannerEvent.GetID(), mannerEvent.GetUserID()))

	switch mannerEvent.EventType {
	case "signal_complete":
		return w.handleSignalComplete(mannerEvent)
	case "no_show":
		return w.handleNoShow(mannerEvent)
	case "rating_received":
		return w.handleRatingReceived(mannerEvent)
	default:
		return w.recalculateMannerTemperature(mannerEvent.GetUserID())
	}
}

// handleSignalComplete 시그널 완료 처리
func (w *MannerWorker) handleSignalComplete(event *events.MannerEvent) error {
	return w.db.Transaction(func(tx *gorm.DB) error {
		// 사용자 프로필 업데이트
		result := tx.Model(&models.UserProfile{}).
			Where("user_id = ?", event.GetUserID()).
			Updates(map[string]interface{}{
				"signal_count":      gorm.Expr("signal_count + 1"),
				"last_activity_at":  event.GetTimestamp(),
			})

		if result.Error != nil {
			return fmt.Errorf("failed to update signal count: %w", result.Error)
		}

		// 매너온도 재계산
		return w.recalculateMannerTemperature(event.GetUserID())
	})
}

// handleNoShow 노쇼 처리
func (w *MannerWorker) handleNoShow(event *events.MannerEvent) error {
	return w.db.Transaction(func(tx *gorm.DB) error {
		// 노쇼 횟수 증가
		result := tx.Model(&models.UserProfile{}).
			Where("user_id = ?", event.GetUserID()).
			Updates(map[string]interface{}{
				"no_show_count":    gorm.Expr("no_show_count + 1"),
				"last_activity_at": event.GetTimestamp(),
			})

		if result.Error != nil {
			return fmt.Errorf("failed to update no_show count: %w", result.Error)
		}

		// 매너온도 재계산
		return w.recalculateMannerTemperature(event.GetUserID())
	})
}

// handleRatingReceived 평가 받음 처리
func (w *MannerWorker) handleRatingReceived(event *events.MannerEvent) error {
	return w.db.Transaction(func(tx *gorm.DB) error {
		// 평가 수 증가 및 평균 계산
		var profile models.UserProfile
		if err := tx.Where("user_id = ?", event.GetUserID()).First(&profile).Error; err != nil {
			return fmt.Errorf("failed to get user profile: %w", err)
		}

		// 새로운 평균 매너온도 계산
		totalRatings := profile.TotalRatings + 1
		newTemperature := (profile.MannerTemperature*float64(profile.TotalRatings) + event.Rating) / float64(totalRatings)

		// 업데이트
		result := tx.Model(&profile).Updates(map[string]interface{}{
			"total_ratings":      totalRatings,
			"manner_temperature": newTemperature,
			"last_activity_at":   event.GetTimestamp(),
		})

		if result.Error != nil {
			return fmt.Errorf("failed to update ratings: %w", result.Error)
		}

		w.logger.Info(fmt.Sprintf("Updated manner temperature for user %d: %.1f → %.1f", 
			event.GetUserID(), profile.MannerTemperature, newTemperature))

		return nil
	})
}

// recalculateMannerTemperature 매너온도 재계산
func (w *MannerWorker) recalculateMannerTemperature(userID uint) error {
	var profile models.UserProfile
	if err := w.db.Where("user_id = ?", userID).First(&profile).Error; err != nil {
		return fmt.Errorf("failed to get user profile: %w", err)
	}

	// 매너온도 계산
	newTemperature := w.calculateMannerTemperature(
		profile.SignalCount,
		profile.JoinCount,
		profile.NoShowCount,
		profile.TotalRatings,
		profile.CompletionRate,
	)

	// 완료율 재계산
	totalActivities := profile.SignalCount + profile.JoinCount
	var completionRate float64
	if totalActivities > 0 {
		completedActivities := totalActivities - profile.NoShowCount
		completionRate = (float64(completedActivities) / float64(totalActivities)) * 100.0
	}

	// 업데이트
	result := w.db.Model(&profile).Updates(map[string]interface{}{
		"manner_temperature": newTemperature,
		"completion_rate":    completionRate,
	})

	if result.Error != nil {
		return fmt.Errorf("failed to update manner temperature: %w", result.Error)
	}

	w.logger.Info(fmt.Sprintf("Recalculated manner temperature for user %d: %.1f (completion: %.1f%%)", 
		userID, newTemperature, completionRate))

	return nil
}

// calculateMannerTemperature 매너온도 계산 로직 (기존 MySQL 함수 이식)
func (w *MannerWorker) calculateMannerTemperature(
	signalCount, joinCount, noShowCount, totalRatings int,
	completionRate float64,
) float64 {
	const (
		baseTemp        = 36.5
		completionBonus = 0.1
		ratingBonus     = 0.05
		noShowPenalty   = 0.3
		maxTemp         = 50.0
		minTemp         = 20.0
	)

	// 완료한 Signal 수 계산
	completedSignals := signalCount + joinCount - noShowCount

	// 기본 온도에서 시작
	finalTemp := baseTemp

	// 완료 보너스
	finalTemp += float64(completedSignals) * completionBonus

	// 평가 보너스 (완료율이 80% 이상이고 평가가 있을 때)
	if totalRatings > 0 && completionRate > 80 {
		finalTemp += float64(totalRatings) * ratingBonus
	}

	// 노쇼 페널티
	finalTemp -= float64(noShowCount) * noShowPenalty

	// 최대/최소값 제한
	finalTemp = math.Max(minTemp, math.Min(maxTemp, finalTemp))

	return math.Round(finalTemp*10) / 10 // 소수점 첫째자리까지
}

// BatchRecalculateAll 모든 사용자 매너온도 일괄 재계산
func (w *MannerWorker) BatchRecalculateAll() error {
	w.logger.Info("Starting batch recalculation of all manner temperatures")

	var profiles []models.UserProfile
	if err := w.db.Find(&profiles).Error; err != nil {
		return fmt.Errorf("failed to get user profiles: %w", err)
	}

	batchSize := 100
	successCount := 0
	errorCount := 0

	for i := 0; i < len(profiles); i += batchSize {
		end := i + batchSize
		if end > len(profiles) {
			end = len(profiles)
		}

		batch := profiles[i:end]
		
		// 배치 처리
		if err := w.processBatch(batch); err != nil {
			w.logger.Error(fmt.Sprintf("Failed to process batch %d-%d: %v", i, end, err))
			errorCount += len(batch)
		} else {
			successCount += len(batch)
		}
	}

	w.logger.Info(fmt.Sprintf("Batch recalculation completed: %d success, %d errors", 
		successCount, errorCount))

	return nil
}

// processBatch 배치 처리
func (w *MannerWorker) processBatch(profiles []models.UserProfile) error {
	return w.db.Transaction(func(tx *gorm.DB) error {
		for _, profile := range profiles {
			newTemperature := w.calculateMannerTemperature(
				profile.SignalCount,
				profile.JoinCount,
				profile.NoShowCount,
				profile.TotalRatings,
				profile.CompletionRate,
			)

			// 완료율 재계산
			totalActivities := profile.SignalCount + profile.JoinCount
			var completionRate float64
			if totalActivities > 0 {
				completedActivities := totalActivities - profile.NoShowCount
				completionRate = (float64(completedActivities) / float64(totalActivities)) * 100.0
			}

			// 업데이트
			if err := tx.Model(&profile).Updates(map[string]interface{}{
				"manner_temperature": newTemperature,
				"completion_rate":    completionRate,
			}).Error; err != nil {
				return fmt.Errorf("failed to update profile %d: %w", profile.UserID, err)
			}
		}
		return nil
	})
}