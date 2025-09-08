package models

import (
	"time"
	"gorm.io/gorm"
)

// AuthToken represents a magic link token for authentication
type AuthToken struct {
	ID        uint           `json:"id" gorm:"primaryKey"`
	Email     string         `json:"email" gorm:"not null;index"`
	Token     string         `json:"token" gorm:"not null;uniqueIndex"`
	Purpose   string         `json:"purpose" gorm:"not null"` // "login", "signup"
	Used      bool           `json:"used" gorm:"default:false"`
	ExpiresAt time.Time      `json:"expires_at" gorm:"not null;index"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`
}

// IsExpired checks if the token has expired
func (at *AuthToken) IsExpired() bool {
	return time.Now().After(at.ExpiresAt)
}

// IsValid checks if the token is valid (not used and not expired)
func (at *AuthToken) IsValid() bool {
	return !at.Used && !at.IsExpired()
}

// MarkAsUsed marks the token as used
func (at *AuthToken) MarkAsUsed() {
	at.Used = true
}