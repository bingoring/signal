package repositories

import (
	"fmt"
	"time"

	"signal-module/pkg/models"
	"signal-module/pkg/utils"

	"gorm.io/gorm"
)

type SignalRepositoryInterface interface {
	Create(signal *models.Signal) error
	GetByID(id uint) (*models.Signal, error)
	Update(signal *models.Signal) error
	Delete(id uint) error
	Search(req *models.SearchSignalRequest) ([]models.SignalWithDistance, int64, error)
	GetByUserID(userID uint, status []models.SignalStatus, page, limit int) ([]models.Signal, int64, error)
	JoinSignal(participant *models.SignalParticipant) error
	LeaveSignal(signalID, userID uint) error
	UpdateParticipantStatus(signalID, userID uint, status models.ParticipantStatus) error
	GetParticipants(signalID uint) ([]models.SignalParticipant, error)
	GetExpiredSignals() ([]models.Signal, error)
	GetActiveSignalsInRadius(latitude, longitude, radius float64) ([]models.Signal, error)
}

type SignalRepository struct {
	db *gorm.DB
}

func NewSignalRepository(db *gorm.DB) SignalRepositoryInterface {
	return &SignalRepository{db: db}
}

func (r *SignalRepository) Create(signal *models.Signal) error {
	return r.db.Create(signal).Error
}

func (r *SignalRepository) GetByID(id uint) (*models.Signal, error) {
	var signal models.Signal
	err := r.db.Preload("Creator.Profile").
		Preload("Participants.User.Profile").
		Preload("ChatRoom").
		First(&signal, id).Error
	if err != nil {
		return nil, err
	}
	return &signal, nil
}

func (r *SignalRepository) Update(signal *models.Signal) error {
	return r.db.Save(signal).Error
}

func (r *SignalRepository) Delete(id uint) error {
	return r.db.Delete(&models.Signal{}, id).Error
}

func (r *SignalRepository) Search(req *models.SearchSignalRequest) ([]models.SignalWithDistance, int64, error) {
	var results []models.SignalWithDistance
	var total int64

	query := r.db.Model(&models.Signal{}).
		Preload("Creator.Profile").
		Where("status = ? AND expires_at > ?", models.SignalActive, time.Now())

	if req.Category != "" {
		query = query.Where("category = ?", req.Category)
	}

	if req.StartTime != nil && req.EndTime != nil {
		query = query.Where("scheduled_at BETWEEN ? AND ?", req.StartTime, req.EndTime)
	}

	// 위치 기반 검색 (PostGIS 사용)
	if req.Latitude != 0 && req.Longitude != 0 {
		radius := req.Radius
		if radius == 0 {
			radius = 5000 // 기본 5km
		}

		subQuery := `
			ST_DWithin(
				ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
				ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
				?
			)
		`
		query = query.Where(subQuery, req.Longitude, req.Latitude, radius)
	}

	// 총 개수 계산
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// 페이지네이션
	offset := utils.CalculateOffset(req.Page, req.Limit)
	query = query.Offset(offset).Limit(req.Limit)

	var signals []models.Signal
	if err := query.Find(&signals).Error; err != nil {
		return nil, 0, err
	}

	// 거리 계산 및 결과 변환
	for _, signal := range signals {
		distance := 0.0
		if req.Latitude != 0 && req.Longitude != 0 {
			distance = utils.CalculateDistance(
				req.Latitude, req.Longitude,
				signal.Latitude, signal.Longitude,
			)
		}

		results = append(results, models.SignalWithDistance{
			Signal:   signal,
			Distance: distance,
		})
	}

	return results, total, nil
}

func (r *SignalRepository) GetByUserID(userID uint, status []models.SignalStatus, page, limit int) ([]models.Signal, int64, error) {
	var signals []models.Signal
	var total int64

	query := r.db.Model(&models.Signal{}).
		Preload("Participants.User.Profile").
		Where("creator_id = ?", userID)

	if len(status) > 0 {
		query = query.Where("status IN ?", status)
	}

	// 총 개수 계산
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// 페이지네이션
	offset := utils.CalculateOffset(page, limit)
	err := query.Offset(offset).Limit(limit).
		Order("created_at DESC").
		Find(&signals).Error

	return signals, total, err
}

func (r *SignalRepository) JoinSignal(participant *models.SignalParticipant) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 참여자 추가
		if err := tx.Create(participant).Error; err != nil {
			return err
		}

		// 승인 상태면 참여자 수 증가
		if participant.Status == models.ParticipantApproved {
			if err := tx.Model(&models.Signal{}).
				Where("id = ?", participant.SignalID).
				Update("current_participants", gorm.Expr("current_participants + 1")).Error; err != nil {
				return err
			}

			// 정원이 다 찼으면 상태 변경
			var signal models.Signal
			if err := tx.First(&signal, participant.SignalID).Error; err != nil {
				return err
			}

			if signal.CurrentParticipants >= signal.MaxParticipants {
				return tx.Model(&signal).Update("status", models.SignalFull).Error
			}
		}

		return nil
	})
}

func (r *SignalRepository) LeaveSignal(signalID, userID uint) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 참여자 상태 업데이트
		var participant models.SignalParticipant
		if err := tx.Where("signal_id = ? AND user_id = ?", signalID, userID).
			First(&participant).Error; err != nil {
			return err
		}

		now := time.Now()
		participant.Status = models.ParticipantLeft
		participant.LeftAt = &now

		if err := tx.Save(&participant).Error; err != nil {
			return err
		}

		// 승인된 상태였다면 참여자 수 감소
		if participant.Status == models.ParticipantApproved {
			if err := tx.Model(&models.Signal{}).
				Where("id = ?", signalID).
				Update("current_participants", gorm.Expr("current_participants - 1")).Error; err != nil {
				return err
			}

			// Full 상태였다면 Active로 변경
			var signal models.Signal
			if err := tx.First(&signal, signalID).Error; err != nil {
				return err
			}

			if signal.Status == models.SignalFull && signal.CurrentParticipants < signal.MaxParticipants {
				return tx.Model(&signal).Update("status", models.SignalActive).Error
			}
		}

		return nil
	})
}

func (r *SignalRepository) UpdateParticipantStatus(signalID, userID uint, status models.ParticipantStatus) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 참여자 상태 업데이트
		var participant models.SignalParticipant
		if err := tx.Where("signal_id = ? AND user_id = ?", signalID, userID).
			First(&participant).Error; err != nil {
			return err
		}

		oldStatus := participant.Status
		participant.Status = status

		if status == models.ParticipantApproved {
			now := time.Now()
			participant.JoinedAt = &now
		}

		if err := tx.Save(&participant).Error; err != nil {
			return err
		}

		// 참여자 수 업데이트
		if oldStatus != models.ParticipantApproved && status == models.ParticipantApproved {
			// 승인됨: 참여자 수 증가
			if err := tx.Model(&models.Signal{}).
				Where("id = ?", signalID).
				Update("current_participants", gorm.Expr("current_participants + 1")).Error; err != nil {
				return err
			}
		} else if oldStatus == models.ParticipantApproved && status != models.ParticipantApproved {
			// 승인 취소됨: 참여자 수 감소
			if err := tx.Model(&models.Signal{}).
				Where("id = ?", signalID).
				Update("current_participants", gorm.Expr("current_participants - 1")).Error; err != nil {
				return err
			}
		}

		// 시그널 상태 업데이트
		var signal models.Signal
		if err := tx.First(&signal, signalID).Error; err != nil {
			return err
		}

		if signal.CurrentParticipants >= signal.MaxParticipants {
			return tx.Model(&signal).Update("status", models.SignalFull).Error
		} else if signal.Status == models.SignalFull {
			return tx.Model(&signal).Update("status", models.SignalActive).Error
		}

		return nil
	})
}

func (r *SignalRepository) GetParticipants(signalID uint) ([]models.SignalParticipant, error) {
	var participants []models.SignalParticipant
	err := r.db.Preload("User.Profile").
		Where("signal_id = ?", signalID).
		Find(&participants).Error
	return participants, err
}

func (r *SignalRepository) GetExpiredSignals() ([]models.Signal, error) {
	var signals []models.Signal
	err := r.db.Where("status = ? AND expires_at < ?", models.SignalActive, time.Now()).
		Find(&signals).Error
	return signals, err
}

func (r *SignalRepository) GetActiveSignalsInRadius(latitude, longitude, radius float64) ([]models.Signal, error) {
	var signals []models.Signal
	
	query := `
		SELECT * FROM signals
		WHERE status = ?
		AND expires_at > ?
		AND ST_DWithin(
			ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
			ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
			?
		)
	`
	
	err := r.db.Raw(query, models.SignalActive, time.Now(), longitude, latitude, radius).
		Find(&signals).Error
	
	return signals, err
}