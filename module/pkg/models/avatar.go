package models

import (
	"strings"
	"time"

	"gorm.io/gorm"
)

// AvatarCategory 아바타 카테고리 모델
type AvatarCategory struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	Name        string    `json:"name" gorm:"size:50;not null;uniqueIndex"`
	DisplayName string    `json:"display_name" gorm:"size:100;not null"`
	Description string    `json:"description" gorm:"size:200"`
	Color       string    `json:"color" gorm:"size:7"` // HEX color
	SortOrder   int       `json:"sort_order" gorm:"default:0"`
	IsActive    bool      `json:"is_active" gorm:"default:true"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`

	// Relations
	Avatars []Avatar `json:"avatars,omitempty" gorm:"foreignKey:CategoryID"`
}

// Avatar 아바타 모델
type Avatar struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	CategoryID  uint      `json:"category_id" gorm:"not null;index"`
	Emoji       string    `json:"emoji" gorm:"size:10;not null;uniqueIndex"`
	Name        string    `json:"name" gorm:"size:50;not null"`
	Description string    `json:"description" gorm:"size:100"`
	Keywords    string    `json:"keywords" gorm:"size:200"` // 검색용 키워드 (쉼표로 구분)
	SortOrder   int       `json:"sort_order" gorm:"default:0"`
	IsActive    bool      `json:"is_active" gorm:"default:true"`
	IsDefault   bool      `json:"is_default" gorm:"default:false"` // 기본 추천 아바타
	UsageCount  int       `json:"usage_count" gorm:"default:0"`    // 사용 통계
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`

	// Relations
	Category *AvatarCategory `json:"category,omitempty" gorm:"foreignKey:CategoryID"`
}

// UserAvatar 사용자-아바타 관계 (즐겨찾기, 최근 사용 등)
type UserAvatar struct {
	ID         uint      `json:"id" gorm:"primaryKey"`
	UserID     uint      `json:"user_id" gorm:"not null;index"`
	AvatarID   uint      `json:"avatar_id" gorm:"not null;index"`
	IsFavorite bool      `json:"is_favorite" gorm:"default:false"`
	LastUsed   time.Time `json:"last_used"`
	UsageCount int       `json:"usage_count" gorm:"default:0"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`

	// Relations
	User   *User   `json:"user,omitempty" gorm:"foreignKey:UserID"`
	Avatar *Avatar `json:"avatar,omitempty" gorm:"foreignKey:AvatarID"`

	// Unique constraint: one record per user-avatar pair
	_ struct{} `gorm:"uniqueIndex:idx_user_avatar"`
}

// AvatarStats 아바타 통계
type AvatarStats struct {
	AvatarID    uint   `json:"avatar_id"`
	Emoji       string `json:"emoji"`
	Name        string `json:"name"`
	CategoryID  uint   `json:"category_id"`
	UsageCount  int    `json:"usage_count"`
	UniqueUsers int    `json:"unique_users"`
	Popularity  float64 `json:"popularity"` // 전체 사용자 대비 사용 비율
}

// Avatar 모델 메서드
func (a *Avatar) IncrementUsage() {
	a.UsageCount++
}

func (a *Avatar) GetKeywordsList() []string {
	if a.Keywords == "" {
		return []string{}
	}
	keywords := make([]string, 0)
	for _, keyword := range splitString(a.Keywords, ",") {
		trimmed := trimString(keyword)
		if trimmed != "" {
			keywords = append(keywords, trimmed)
		}
	}
	return keywords
}

// AvatarCategory 모델 메서드
func (ac *AvatarCategory) GetActiveAvatars(db *gorm.DB) ([]Avatar, error) {
	var avatars []Avatar
	err := db.Where("category_id = ? AND is_active = ?", ac.ID, true).
		Order("sort_order ASC, name ASC").
		Find(&avatars).Error
	return avatars, err
}

// 헬퍼 함수들
func splitString(s, sep string) []string {
	return strings.Split(s, sep)
}

func trimString(s string) string {
	return strings.TrimSpace(s)
}

// DTO 구조체들
type AvatarSelectionResponse struct {
	Categories []CategoryWithAvatars `json:"categories"`
	Favorites  []Avatar              `json:"favorites,omitempty"`
	Recent     []Avatar              `json:"recent,omitempty"`
}

type CategoryWithAvatars struct {
	ID          uint     `json:"id"`
	Name        string   `json:"name"`
	DisplayName string   `json:"display_name"`
	Description string   `json:"description"`
	Color       string   `json:"color"`
	Avatars     []Avatar `json:"avatars"`
}

type AvatarSearchRequest struct {
	Query      string `json:"query" binding:"required,min=1,max=50"`
	CategoryID *uint  `json:"category_id,omitempty"`
	Limit      int    `json:"limit" binding:"min=1,max=50"`
}

type AvatarSearchResponse struct {
	Query   string   `json:"query"`
	Results []Avatar `json:"results"`
	Total   int      `json:"total"`
}

type SetUserAvatarRequest struct {
	AvatarID *uint  `json:"avatar_id,omitempty"`
	Emoji    string `json:"emoji" binding:"required,min=1,max=10"`
}

type UserAvatarStatsResponse struct {
	CurrentAvatar   *Avatar           `json:"current_avatar,omitempty"`
	Favorites       []Avatar          `json:"favorites"`
	RecentlyUsed    []Avatar          `json:"recently_used"`
	CategoryStats   []CategoryUsage   `json:"category_stats"`
	PersonalityType string            `json:"personality_type"` // 사용 패턴 기반 성향
}

type CategoryUsage struct {
	CategoryID   uint   `json:"category_id"`
	CategoryName string `json:"category_name"`
	UsageCount   int    `json:"usage_count"`
	Percentage   float64 `json:"percentage"`
}

// 아바타 개성 분석 시스템
type AvatarPersonality struct {
	Type        string                 `json:"type"`        // "adventurer", "creative", "social", etc.
	Description string                 `json:"description"` // 성향 설명
	Traits      []PersonalityTrait     `json:"traits"`      // 특성 목록
	Suggestions []Avatar               `json:"suggestions"` // 추천 아바타
	Stats       PersonalityStatsDetail `json:"stats"`       // 상세 통계
}

type PersonalityTrait struct {
	Name        string  `json:"name"`        // 특성명
	Score       float64 `json:"score"`       // 점수 (0-100)
	Description string  `json:"description"` // 설명
}

type PersonalityStatsDetail struct {
	DominantCategories []string `json:"dominant_categories"` // 주로 사용하는 카테고리들
	ChangeFrequency    string   `json:"change_frequency"`    // 변경 빈도 ("high", "medium", "low")
	FavoriteEmojis     []string `json:"favorite_emojis"`     // 자주 사용하는 이모지들
	SeasonalPattern    string   `json:"seasonal_pattern"`    // 계절별 패턴 (향후 확장)
}