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

type UserProfile struct {
	ID          uint   `json:"id" gorm:"primaryKey"`
	UserID      uint   `json:"user_id" gorm:"uniqueIndex;not null"`
	DisplayName string `json:"display_name" gorm:"size:100;not null"`
	Avatar      string `json:"avatar"`
	Bio         string `json:"bio" gorm:"size:500"`
	Age         int    `json:"age"`
	Gender      string `json:"gender" gorm:"size:10"`
	
	MannerScore       float64 `json:"manner_score" gorm:"default:36.5"`
	TotalRatings      int     `json:"total_ratings" gorm:"default:0"`
	CompletedSignals  int     `json:"completed_signals" gorm:"default:0"`
	NoShowCount       int     `json:"no_show_count" gorm:"default:0"`
	
	PushNotifications     bool `json:"push_notifications" gorm:"default:true"`
	LocationSharing       bool `json:"location_sharing" gorm:"default:true"`
	ProfilePublic         bool `json:"profile_public" gorm:"default:true"`
	
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

type UpdateProfileRequest struct {
	DisplayName string `json:"display_name" binding:"required,min=2,max=50"`
	Avatar      string `json:"avatar"`
	Bio         string `json:"bio" binding:"max=500"`
	Age         int    `json:"age" binding:"min=14,max=100"`
	Gender      string `json:"gender" binding:"oneof=male female other"`
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