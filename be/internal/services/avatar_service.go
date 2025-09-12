package services

import (
	"fmt"
	"math"
	"strings"
	"time"

	"gorm.io/gorm"

	"signal-be/internal/repositories"
	"signal-module/pkg/models"
	"signal-module/pkg/logger"
)

type AvatarService struct {
	avatarRepo repositories.AvatarRepository
	userRepo   repositories.UserRepositoryInterface
	logger     *logger.Logger
	db         *gorm.DB
}

func NewAvatarService(avatarRepo repositories.AvatarRepository, userRepo repositories.UserRepositoryInterface, logger *logger.Logger, db *gorm.DB) *AvatarService {
	return &AvatarService{
		avatarRepo: avatarRepo,
		userRepo:   userRepo,
		logger:     logger,
		db:         db,
	}
}

// GetAvatarCategories 모든 활성 아바타 카테고리와 아바타 목록 조회
func (s *AvatarService) GetAvatarCategories() (*models.AvatarSelectionResponse, error) {
	categories, err := s.avatarRepo.GetActiveCategories()
	if err != nil {
		return nil, fmt.Errorf("failed to get categories: %w", err)
	}

	response := &models.AvatarSelectionResponse{
		Categories: make([]models.CategoryWithAvatars, 0, len(categories)),
	}

	for _, category := range categories {
		avatars, err := s.avatarRepo.GetAvatarsByCategory(category.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to get avatars for category %s: %w", category.Name, err)
		}

		categoryWithAvatars := models.CategoryWithAvatars{
			ID:          category.ID,
			Name:        category.Name,
			DisplayName: category.DisplayName,
			Description: category.Description,
			Color:       category.Color,
			Avatars:     avatars,
		}

		response.Categories = append(response.Categories, categoryWithAvatars)
	}

	return response, nil
}

// GetUserAvatarSelection 사용자 맞춤 아바타 선택 화면 데이터
func (s *AvatarService) GetUserAvatarSelection(userID uint) (*models.AvatarSelectionResponse, error) {
	// 기본 카테고리와 아바타 목록 가져오기
	response, err := s.GetAvatarCategories()
	if err != nil {
		return nil, err
	}

	// 사용자 즐겨찾기 아바타
	favorites, err := s.avatarRepo.GetUserFavoriteAvatars(userID)
	if err == nil && len(favorites) > 0 {
		response.Favorites = favorites
	}

	// 사용자 최근 사용 아바타
	recent, err := s.avatarRepo.GetUserRecentAvatars(userID, 8)
	if err == nil && len(recent) > 0 {
		response.Recent = recent
	}

	return response, nil
}

// SearchAvatars 아바타 검색
func (s *AvatarService) SearchAvatars(request models.AvatarSearchRequest) (*models.AvatarSearchResponse, error) {
	// 검색어 정리
	query := strings.TrimSpace(request.Query)
	if query == "" {
		return &models.AvatarSearchResponse{
			Query:   request.Query,
			Results: []models.Avatar{},
			Total:   0,
		}, nil
	}

	// 검색 실행
	avatars, total, err := s.avatarRepo.SearchAvatars(query, request.CategoryID, request.Limit)
	if err != nil {
		return nil, fmt.Errorf("failed to search avatars: %w", err)
	}

	return &models.AvatarSearchResponse{
		Query:   request.Query,
		Results: avatars,
		Total:   total,
	}, nil
}

// SetUserAvatar 사용자 아바타 설정
func (s *AvatarService) SetUserAvatar(userID uint, request models.SetUserAvatarRequest) error {
	// 트랜잭션 시작
	tx := s.db.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// 이모지로 아바타 찾기
	avatar, err := s.avatarRepo.GetAvatarByEmoji(request.Emoji)
	if err != nil {
		tx.Rollback()
		return fmt.Errorf("avatar not found for emoji %s: %w", request.Emoji, err)
	}

	// 사용자 프로필의 아바타 필드 업데이트
	err = s.userRepo.UpdateUserAvatar(tx, userID, request.Emoji)
	if err != nil {
		tx.Rollback()
		return fmt.Errorf("failed to update user avatar: %w", err)
	}

	// 사용자-아바타 관계 업데이트 (통계용)
	err = s.avatarRepo.UpdateUserAvatarUsage(tx, userID, avatar.ID)
	if err != nil {
		tx.Rollback()
		return fmt.Errorf("failed to update avatar usage: %w", err)
	}

	// 아바타 전체 사용 통계 업데이트
	err = s.avatarRepo.IncrementAvatarUsage(tx, avatar.ID)
	if err != nil {
		tx.Rollback()
		return fmt.Errorf("failed to increment avatar usage: %w", err)
	}

	// 커밋
	if err := tx.Commit().Error; err != nil {
		return fmt.Errorf("failed to commit avatar update: %w", err)
	}

	return nil
}

// ToggleAvatarFavorite 아바타 즐겨찾기 토글
func (s *AvatarService) ToggleAvatarFavorite(userID uint, avatarID uint) (bool, error) {
	userAvatar, err := s.avatarRepo.GetUserAvatar(userID, avatarID)
	if err != nil {
		// 관계가 없으면 새로 생성하고 즐겨찾기로 설정
		err = s.avatarRepo.CreateUserAvatar(&models.UserAvatar{
			UserID:     userID,
			AvatarID:   avatarID,
			IsFavorite: true,
			CreatedAt:  time.Now(),
			UpdatedAt:  time.Now(),
		})
		if err != nil {
			return false, fmt.Errorf("failed to create favorite: %w", err)
		}
		return true, nil
	}

	// 즐겨찾기 상태 토글
	newFavoriteStatus := !userAvatar.IsFavorite
	err = s.avatarRepo.UpdateUserAvatarFavorite(userID, avatarID, newFavoriteStatus)
	if err != nil {
		return false, fmt.Errorf("failed to toggle favorite: %w", err)
	}

	return newFavoriteStatus, nil
}

// GetUserAvatarStats 사용자 아바타 통계 및 분석
func (s *AvatarService) GetUserAvatarStats(userID uint) (*models.UserAvatarStatsResponse, error) {
	stats := &models.UserAvatarStatsResponse{}

	// 현재 아바타
	currentProfile, err := s.userRepo.GetUserProfile(userID)
	if err == nil && currentProfile.Avatar != nil {
		currentAvatar, err := s.avatarRepo.GetAvatarByEmoji(*currentProfile.Avatar)
		if err == nil {
			stats.CurrentAvatar = &currentAvatar
		}
	}

	// 즐겨찾기 아바타
	favorites, err := s.avatarRepo.GetUserFavoriteAvatars(userID)
	if err == nil {
		stats.Favorites = favorites
	}

	// 최근 사용 아바타
	recent, err := s.avatarRepo.GetUserRecentAvatars(userID, 5)
	if err == nil {
		stats.RecentlyUsed = recent
	}

	// 카테고리 사용 통계
	categoryStats, err := s.avatarRepo.GetUserCategoryStats(userID)
	if err == nil {
		stats.CategoryStats = categoryStats
	}

	// 개성 분석
	personality, err := s.analyzeUserPersonality(userID, categoryStats)
	if err == nil {
		stats.PersonalityType = personality.Type
	}

	return stats, nil
}

// GetPopularAvatars 인기 아바타 목록
func (s *AvatarService) GetPopularAvatars(limit int) ([]models.AvatarStats, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	return s.avatarRepo.GetPopularAvatars(limit)
}

// analyzeUserPersonality 사용자의 아바타 사용 패턴을 분석하여 성향 판단
func (s *AvatarService) analyzeUserPersonality(userID uint, categoryStats []models.CategoryUsage) (*models.AvatarPersonality, error) {
	if len(categoryStats) == 0 {
		return &models.AvatarPersonality{
			Type:        "newcomer",
			Description: "아직 다양한 아바타를 탐험중인 새로운 사용자",
			Traits:      []models.PersonalityTrait{},
			Suggestions: []models.Avatar{},
		}, nil
	}

	// 가장 많이 사용하는 카테고리 분석
	dominantCategory := categoryStats[0]
	personality := &models.AvatarPersonality{
		Traits:      []models.PersonalityTrait{},
		Suggestions: []models.Avatar{},
		Stats: models.PersonalityStatsDetail{
			DominantCategories: []string{dominantCategory.CategoryName},
		},
	}

	// 카테고리별 성향 분석
	switch dominantCategory.CategoryName {
	case "emotions":
		personality.Type = "expressive"
		personality.Description = "감정 표현이 풍부하고 소통을 중시하는 표현형"
		personality.Traits = append(personality.Traits, models.PersonalityTrait{
			Name:        "감정 표현력",
			Score:       85.0,
			Description: "다양한 감정을 자유롭게 표현합니다",
		})
	case "activities":
		personality.Type = "active"
		personality.Description = "다양한 활동과 취미를 즐기는 활동형"
		personality.Traits = append(personality.Traits, models.PersonalityTrait{
			Name:        "활동성",
			Score:       90.0,
			Description: "새로운 경험과 활동을 좋아합니다",
		})
	case "travel":
		personality.Type = "adventurer"
		personality.Description = "모험과 새로운 경험을 추구하는 모험가"
		personality.Traits = append(personality.Traits, models.PersonalityTrait{
			Name:        "모험심",
			Score:       95.0,
			Description: "새로운 장소와 경험을 탐구합니다",
		})
	case "creative":
		personality.Type = "creative"
		personality.Description = "창의성과 예술적 감성이 풍부한 창작형"
		personality.Traits = append(personality.Traits, models.PersonalityTrait{
			Name:        "창의성",
			Score:       88.0,
			Description: "예술과 창작 활동에 관심이 많습니다",
		})
	default:
		personality.Type = "balanced"
		personality.Description = "균형 잡힌 관심사를 가진 조화로운 성향"
		personality.Traits = append(personality.Traits, models.PersonalityTrait{
			Name:        "균형감",
			Score:       75.0,
			Description: "다양한 영역에 고르게 관심을 가집니다",
		})
	}

	// 변경 빈도 분석
	totalUsage := 0
	for _, stat := range categoryStats {
		totalUsage += stat.UsageCount
	}

	if totalUsage >= 20 {
		personality.Stats.ChangeFrequency = "high"
	} else if totalUsage >= 10 {
		personality.Stats.ChangeFrequency = "medium"
	} else {
		personality.Stats.ChangeFrequency = "low"
	}

	// 추천 아바타 생성 (같은 카테고리에서 인기 있는 아바타들)
	if dominantCategory.CategoryID > 0 {
		recommendations, err := s.avatarRepo.GetPopularAvatarsByCategory(dominantCategory.CategoryID, 5)
		if err == nil {
			personality.Suggestions = recommendations
		}
	}

	return personality, nil
}

// GetAvatarPersonalityAnalysis 아바타 기반 성향 분석 상세 정보
func (s *AvatarService) GetAvatarPersonalityAnalysis(userID uint) (*models.AvatarPersonality, error) {
	categoryStats, err := s.avatarRepo.GetUserCategoryStats(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user category stats: %w", err)
	}

	return s.analyzeUserPersonality(userID, categoryStats)
}

// ValidateAvatarEmoji 이모지가 유효한 아바타인지 확인
func (s *AvatarService) ValidateAvatarEmoji(emoji string) (*models.Avatar, error) {
	avatar, err := s.avatarRepo.GetAvatarByEmoji(emoji)
	if err != nil {
		return nil, fmt.Errorf("invalid avatar emoji: %s", emoji)
	}

	if !avatar.IsActive {
		return nil, fmt.Errorf("avatar is not active: %s", emoji)
	}

	return &avatar, nil
}

// GetDefaultAvatars 기본 추천 아바타 목록
func (s *AvatarService) GetDefaultAvatars() ([]models.Avatar, error) {
	return s.avatarRepo.GetDefaultAvatars()
}

// BulkUpdateAvatarStats 아바타 통계 일괄 업데이트 (배치 작업용)
func (s *AvatarService) BulkUpdateAvatarStats() error {
	// 모든 아바타의 사용 통계 재계산
	var avatars []models.Avatar
	if err := s.db.Find(&avatars).Error; err != nil {
		return fmt.Errorf("failed to get avatars: %w", err)
	}

	for _, avatar := range avatars {
		// 실제 사용 횟수 계산
		var actualUsage int64
		err := s.db.Model(&models.UserAvatar{}).
			Where("avatar_id = ?", avatar.ID).
			Count(&actualUsage).Error
		
		if err != nil {
			continue
		}

		// 통계 업데이트
		s.db.Model(&avatar).Update("usage_count", actualUsage)
	}

	return nil
}

// Helper functions for mathematical calculations
func calculateSimilarity(a, b []float64) float64 {
	if len(a) != len(b) {
		return 0
	}

	var dotProduct, normA, normB float64
	for i := range a {
		dotProduct += a[i] * b[i]
		normA += a[i] * a[i]
		normB += b[i] * b[i]
	}

	if normA == 0 || normB == 0 {
		return 0
	}

	return dotProduct / (math.Sqrt(normA) * math.Sqrt(normB))
}