package models

import (
	"time"

	"gorm.io/gorm"
)

type User struct {
	ID        uint           `json:"id" gorm:"primaryKey"`
	Email     string         `json:"email" gorm:"unique;not null"`
	Username  string         `json:"username" gorm:"unique;not null"`
	Provider  string         `json:"provider" gorm:"default:'local'"`
	GoogleID  *string        `json:"google_id" gorm:"unique"`
	AppleID   *string        `json:"apple_id" gorm:"unique"`
	IsActive  bool           `json:"is_active" gorm:"default:true"`
	IsBlocked bool           `json:"is_blocked" gorm:"default:false"`
	
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	Profile   *UserProfile    `json:"profile,omitempty" gorm:"foreignKey:UserID"`
	Location  *UserLocation   `json:"location,omitempty" gorm:"foreignKey:UserID"`
	Interests []UserInterest  `json:"interests,omitempty" gorm:"foreignKey:UserID"`
	PushTokens []PushToken    `json:"-" gorm:"foreignKey:UserID"`
}

// Phase 1: 최소주의 프로필 시스템
type UserProfile struct {
	ID      uint `json:"id" gorm:"primaryKey"`
	UserID  uint `json:"user_id" gorm:"uniqueIndex;not null"`
	
	// 기본 정보 (최소화)
	DisplayName string `json:"display_name" gorm:"size:30;not null"` // 100자 → 30자로 축소
	
	// 매너온도 시스템 (핵심)
	MannerTemperature float64 `json:"manner_temperature" gorm:"default:36.5"` // 기존 MannerScore → MannerTemperature로 명명 변경
	
	// 활동 기반 신뢰 지표
	SignalCount       int     `json:"signal_count" gorm:"default:0"`        // 생성한 Signal 수
	JoinCount         int     `json:"join_count" gorm:"default:0"`          // 참여한 Signal 수
	CompletionRate    float64 `json:"completion_rate" gorm:"default:0"`     // 완료율 (0-100)
	TotalRatings      int     `json:"total_ratings" gorm:"default:0"`       // 받은 평가 수
	NoShowCount       int     `json:"no_show_count" gorm:"default:0"`       // 노쇼 횟수
	LastActivityAt    *time.Time `json:"last_activity_at"`                  // 최근 활동 시간
	
	// 선택적 정보 (Phase 2에서 확장 예정)
	Avatar     *string `json:"avatar,omitempty"`     // 이모지 아바타 (선택사항)
	OneLine    *string `json:"one_line,omitempty" gorm:"size:50"`  // Bio 500자 → 한 줄 소개 50자
	
	// 기본 설정 (간소화)
	NotificationsEnabled bool `json:"notifications_enabled" gorm:"default:true"` // 여러 설정을 하나로 통합
	
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	User User `json:"-" gorm:"foreignKey:UserID"`
}

type UserLocation struct {
	ID        uint    `json:"id" gorm:"primaryKey"`
	UserID    uint    `json:"user_id" gorm:"uniqueIndex;not null"`
	Latitude  float64 `json:"latitude" gorm:"not null"`
	Longitude float64 `json:"longitude" gorm:"not null"`
	Address   string  `json:"address" gorm:"size:200"`
	IsActive  bool    `json:"is_active" gorm:"default:true"`
	
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	User User `json:"-" gorm:"foreignKey:UserID"`
}

type InterestCategory string

const (
	InterestSports      InterestCategory = "sports"
	InterestFood        InterestCategory = "food"
	InterestGame        InterestCategory = "game"
	InterestCulture     InterestCategory = "culture"
	InterestStudy       InterestCategory = "study"
	InterestHobby       InterestCategory = "hobby"
	InterestTravel      InterestCategory = "travel"
	InterestShopping    InterestCategory = "shopping"
	InterestMusic       InterestCategory = "music"
	InterestMovie       InterestCategory = "movie"
)

type UserInterest struct {
	ID       uint             `json:"id" gorm:"primaryKey"`
	UserID   uint             `json:"user_id" gorm:"not null"`
	Category InterestCategory `json:"category" gorm:"not null"`
	Name     string           `json:"name" gorm:"size:50;not null"`
	
	CreatedAt time.Time `json:"created_at"`

	User User `json:"-" gorm:"foreignKey:UserID"`
}

type PushToken struct {
	ID       uint   `json:"id" gorm:"primaryKey"`
	UserID   uint   `json:"user_id" gorm:"not null"`
	Token    string `json:"token" gorm:"size:500;not null"`
	Platform string `json:"platform" gorm:"size:10;not null"` // ios, android
	IsActive bool   `json:"is_active" gorm:"default:true"`
	
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	User User `json:"-" gorm:"foreignKey:UserID"`
}

type UserRating struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	RaterID   uint   `json:"rater_id" gorm:"not null"`   // 평가하는 사용자
	RateeID   uint   `json:"ratee_id" gorm:"not null"`   // 평가받는 사용자
	SignalID  uint   `json:"signal_id" gorm:"not null"`  // 관련 시그널
	Score     int    `json:"score" gorm:"not null"`      // 1-5점
	Comment   string `json:"comment" gorm:"size:200"`
	IsNoShow  bool   `json:"is_no_show" gorm:"default:false"`
	
	CreatedAt time.Time `json:"created_at"`

	Rater  User `json:"rater,omitempty" gorm:"foreignKey:RaterID"`
	Ratee  User `json:"ratee,omitempty" gorm:"foreignKey:RateeID"`
	Signal Signal `json:"-" gorm:"foreignKey:SignalID"`
}

type ReportReason string

const (
	ReportInappropriate ReportReason = "inappropriate"
	ReportSpam          ReportReason = "spam"
	ReportFake          ReportReason = "fake"
	ReportHarassment    ReportReason = "harassment"
	ReportOther         ReportReason = "other"
)

type ReportUser struct {
	ID        uint         `json:"id" gorm:"primaryKey"`
	ReporterID uint        `json:"reporter_id" gorm:"not null"`
	ReportedID uint        `json:"reported_id" gorm:"not null"`
	SignalID   *uint       `json:"signal_id"`
	Reason     ReportReason `json:"reason" gorm:"not null"`
	Comment    string       `json:"comment" gorm:"size:500"`
	Status     string       `json:"status" gorm:"default:'pending'"` // pending, resolved, dismissed
	
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	Reporter User    `json:"reporter,omitempty" gorm:"foreignKey:ReporterID"`
	Reported User    `json:"reported,omitempty" gorm:"foreignKey:ReportedID"`
	Signal   *Signal `json:"signal,omitempty" gorm:"foreignKey:SignalID"`
}

// DTO 구조체들
type CreateUserRequest struct {
	Email       string  `json:"email" binding:"required,email"`
	Username    string  `json:"username" binding:"required,min=3,max=20"`
	DisplayName string  `json:"display_name" binding:"required,min=2,max=50"`
	Provider    string  `json:"provider"`
	GoogleID    *string `json:"google_id,omitempty"`
	AppleID     *string `json:"apple_id,omitempty"`
}

// Phase 1: 최소주의 프로필 업데이트 요청
type UpdateProfileRequest struct {
	DisplayName string  `json:"display_name" binding:"required,min=2,max=30"` // 50자 → 30자
	Avatar      *string `json:"avatar,omitempty"`     // 이모지 아바타 (선택사항)
	OneLine     *string `json:"one_line,omitempty" binding:"max=50"` // Bio 500자 → 한 줄 소개 50자
	NotificationsEnabled *bool `json:"notifications_enabled,omitempty"` // 알림 설정
}

type UpdateLocationRequest struct {
	Latitude  float64 `json:"latitude" binding:"required"`
	Longitude float64 `json:"longitude" binding:"required"`
	Address   string  `json:"address"`
}

type UserClaims struct {
	UserID   uint   `json:"user_id"`
	Email    string `json:"email"`
	Username string `json:"username"`
}

// Phase 1: 매너온도 계산 및 헬퍼 메서드들
type MannerTemperatureCalculator struct {
	BaseTemperature    float64 // 기본 온도 (36.5도)
	CompletionBonus    float64 // 완료 시 보너스 (+0.1도)
	RatingBonus        float64 // 좋은 평가 보너스 (+0.05도)
	NoShowPenalty      float64 // 노쇼 페널티 (-0.3도)
	MaxTemperature     float64 // 최대 온도 (50.0도)
	MinTemperature     float64 // 최소 온도 (20.0도)
}

// 기본 매너온도 계산기
func NewMannerTemperatureCalculator() *MannerTemperatureCalculator {
	return &MannerTemperatureCalculator{
		BaseTemperature: 36.5,
		CompletionBonus: 0.1,
		RatingBonus:     0.05,
		NoShowPenalty:   0.3,
		MaxTemperature:  50.0,
		MinTemperature:  20.0,
	}
}

// 매너온도 계산 메서드
func (p *UserProfile) CalculateMannerTemperature() float64 {
	calc := NewMannerTemperatureCalculator()
	
	// 기본 온도에서 시작
	temperature := calc.BaseTemperature
	
	// 완료 보너스 (완료한 Signal 수 * 0.1도)
	completedSignals := float64(p.SignalCount + p.JoinCount - p.NoShowCount)
	temperature += completedSignals * calc.CompletionBonus
	
	// 평가 보너스 (평점이 4점 이상일 때만 적용)
	if p.TotalRatings > 0 && p.CompletionRate > 80 {
		temperature += float64(p.TotalRatings) * calc.RatingBonus
	}
	
	// 노쇼 페널티
	temperature -= float64(p.NoShowCount) * calc.NoShowPenalty
	
	// 최대/최소값 제한
	if temperature > calc.MaxTemperature {
		temperature = calc.MaxTemperature
	}
	if temperature < calc.MinTemperature {
		temperature = calc.MinTemperature
	}
	
	return temperature
}

// 매너온도 업데이트 메서드
func (p *UserProfile) UpdateMannerTemperature() {
	p.MannerTemperature = p.CalculateMannerTemperature()
}

// 신뢰도 레벨 반환 (매너온도 기반)
func (p *UserProfile) GetTrustLevel() string {
	temp := p.MannerTemperature
	
	switch {
	case temp >= 45.0:
		return "매우 높음" // Very High
	case temp >= 40.0:
		return "높음"     // High
	case temp >= 37.0:
		return "보통"     // Normal
	case temp >= 32.0:
		return "낮음"     // Low
	default:
		return "매우 낮음" // Very Low
	}
}

// 활동 지표 업데이트 메서드들
func (p *UserProfile) IncrementSignalCount() {
	p.SignalCount++
	p.UpdateCompletionRate()
	p.UpdateMannerTemperature()
	p.LastActivityAt = &time.Time{}
	now := time.Now()
	p.LastActivityAt = &now
}

func (p *UserProfile) IncrementJoinCount() {
	p.JoinCount++
	p.UpdateCompletionRate()
	p.UpdateMannerTemperature()
	now := time.Now()
	p.LastActivityAt = &now
}

func (p *UserProfile) IncrementNoShowCount() {
	p.NoShowCount++
	p.UpdateCompletionRate()
	p.UpdateMannerTemperature()
}

func (p *UserProfile) IncrementRatingCount() {
	p.TotalRatings++
	p.UpdateMannerTemperature()
}

// 완료율 계산 메서드
func (p *UserProfile) UpdateCompletionRate() {
	totalParticipated := p.SignalCount + p.JoinCount
	if totalParticipated == 0 {
		p.CompletionRate = 0
		return
	}
	
	completed := totalParticipated - p.NoShowCount
	p.CompletionRate = (float64(completed) / float64(totalParticipated)) * 100
}

// 최근 활동 여부 확인 (7일 이내)
func (p *UserProfile) IsRecentlyActive() bool {
	if p.LastActivityAt == nil {
		return false
	}
	return time.Since(*p.LastActivityAt) <= 7*24*time.Hour
}