package services

import (
	"errors"
	"fmt"

	"signal-be/internal/repositories"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/utils"

	"gorm.io/gorm"
)

type UserServiceInterface interface {
	Register(req *models.CreateUserRequest) (*models.User, string, string, error)
	RegisterOAuth(req *models.CreateUserRequest) (*models.User, string, string, error)
	Login(email, password string) (*models.User, string, string, error)
	GetUserByID(userID uint) (*models.User, error)
	GetUserByEmail(email string) (*models.User, error)
	GetUserByUsername(username string) (*models.User, error)
	GetUserByGoogleID(googleID string) (*models.User, error)
	UpdateProfile(userID uint, req *models.UpdateProfileRequest) error
	UpdateLocation(userID uint, req *models.UpdateLocationRequest) error
	UpdateInterests(userID uint, interests []models.UserInterest) error
	RegisterPushToken(userID uint, token, platform string) error
	RateUser(raterID uint, req *models.UserRating) error
	ReportUser(reporterID uint, req *models.ReportUser) error
	RefreshToken(refreshToken string) (*models.User, string, error)
}

type UserService struct {
	userRepo   repositories.UserRepositoryInterface
	jwtManager *utils.JWTManager
	logger     *logger.Logger
}

func NewUserService(
	userRepo repositories.UserRepositoryInterface,
	jwtManager *utils.JWTManager,
	logger *logger.Logger,
) UserServiceInterface {
	return &UserService{
		userRepo:   userRepo,
		jwtManager: jwtManager,
		logger:     logger,
	}
}

func (s *UserService) Register(req *models.CreateUserRequest) (*models.User, string, string, error) {
	// 이메일 중복 확인
	if existingUser, _ := s.userRepo.GetByEmail(req.Email); existingUser != nil {
		return nil, "", "", fmt.Errorf("이미 사용중인 이메일입니다")
	}

	// 사용자명 중복 확인
	if existingUser, _ := s.userRepo.GetByUsername(req.Username); existingUser != nil {
		return nil, "", "", fmt.Errorf("이미 사용중인 사용자명입니다")
	}

	user := &models.User{
		Email:    req.Email,
		Username: req.Username,
		Provider: req.Provider,
		IsActive: true,
	}

	// 사용자 생성
	if err := s.userRepo.Create(user); err != nil {
		s.logger.Error("사용자 생성 실패", err)
		return nil, "", "", fmt.Errorf("사용자 생성에 실패했습니다")
	}

	// 프로필 생성
	profile := &models.UserProfile{
		UserID:      user.ID,
		DisplayName: req.DisplayName,
		MannerScore: 36.5, // 기본 매너 점수 (36.5도)
	}

	// 프로필을 별도로 생성하거나 사용자와 함께 생성
	user.Profile = profile

	// JWT 토큰 생성
	accessToken, refreshToken, err := s.jwtManager.GenerateTokenPair(user)
	if err != nil {
		s.logger.Error("토큰 생성 실패", err)
		return nil, "", "", fmt.Errorf("토큰 생성에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("새 사용자 등록: %s (%s)", user.Username, user.Email))

	return user, accessToken, refreshToken, nil
}

func (s *UserService) RegisterOAuth(req *models.CreateUserRequest) (*models.User, string, string, error) {
	// 이메일 중복 확인
	if existingUser, _ := s.userRepo.GetByEmail(req.Email); existingUser != nil {
		return nil, "", "", fmt.Errorf("이미 사용중인 이메일입니다")
	}

	// 사용자명 중복 확인
	if existingUser, _ := s.userRepo.GetByUsername(req.Username); existingUser != nil {
		return nil, "", "", fmt.Errorf("이미 사용중인 사용자명입니다")
	}

	user := &models.User{
		Email:    req.Email,
		Username: req.Username,
		Provider: req.Provider,
		IsActive: true,
	}

	// OAuth 제공업체별 ID 설정
	if req.Provider == "google" && req.GoogleID != nil {
		user.GoogleID = req.GoogleID
	}

	// 사용자 생성
	if err := s.userRepo.Create(user); err != nil {
		s.logger.Error("OAuth 사용자 생성 실패", err)
		return nil, "", "", fmt.Errorf("사용자 생성에 실패했습니다")
	}

	// 프로필 생성
	profile := &models.UserProfile{
		UserID:      user.ID,
		DisplayName: req.DisplayName,
		MannerScore: 36.5, // 기본 매너 점수 (36.5도)
	}

	user.Profile = profile

	// JWT 토큰 생성
	accessToken, refreshToken, err := s.jwtManager.GenerateTokenPair(user)
	if err != nil {
		s.logger.Error("토큰 생성 실패", err)
		return nil, "", "", fmt.Errorf("토큰 생성에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("새 OAuth 사용자 등록: %s (%s) via %s", 
		user.Username, user.Email, user.Provider))

	return user, accessToken, refreshToken, nil
}

func (s *UserService) GetUserByEmail(email string) (*models.User, error) {
	user, err := s.userRepo.GetByEmail(email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("사용자를 찾을 수 없습니다")
		}
		return nil, err
	}
	return user, nil
}

func (s *UserService) GetUserByUsername(username string) (*models.User, error) {
	user, err := s.userRepo.GetByUsername(username)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("사용자를 찾을 수 없습니다")
		}
		return nil, err
	}
	return user, nil
}

func (s *UserService) GetUserByGoogleID(googleID string) (*models.User, error) {
	user, err := s.userRepo.GetByGoogleID(googleID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("사용자를 찾을 수 없습니다")
		}
		return nil, err
	}
	return user, nil
}

func (s *UserService) Login(email, password string) (*models.User, string, string, error) {
	// 현재는 패스워드 없이 이메일만으로 로그인 (매직링크 방식)
	user, err := s.userRepo.GetByEmail(email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, "", "", fmt.Errorf("존재하지 않는 사용자입니다")
		}
		s.logger.Error("사용자 조회 실패", err)
		return nil, "", "", fmt.Errorf("로그인에 실패했습니다")
	}

	if !user.IsActive {
		return nil, "", "", fmt.Errorf("비활성화된 계정입니다")
	}

	if user.IsBlocked {
		return nil, "", "", fmt.Errorf("차단된 계정입니다")
	}

	// JWT 토큰 생성
	accessToken, refreshToken, err := s.jwtManager.GenerateTokenPair(user)
	if err != nil {
		s.logger.Error("토큰 생성 실패", err)
		return nil, "", "", fmt.Errorf("토큰 생성에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("사용자 로그인: %s (%s)", user.Username, user.Email))

	return user, accessToken, refreshToken, nil
}

func (s *UserService) GetUserByID(userID uint) (*models.User, error) {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("사용자를 찾을 수 없습니다")
		}
		return nil, err
	}
	return user, nil
}

func (s *UserService) UpdateProfile(userID uint, req *models.UpdateProfileRequest) error {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return fmt.Errorf("사용자를 찾을 수 없습니다")
	}

	if user.Profile == nil {
		user.Profile = &models.UserProfile{UserID: userID}
	}

	// 프로필 정보 업데이트
	user.Profile.DisplayName = req.DisplayName
	user.Profile.Avatar = req.Avatar
	user.Profile.Bio = req.Bio
	user.Profile.Age = req.Age
	user.Profile.Gender = req.Gender

	if err := s.userRepo.Update(user); err != nil {
		s.logger.Error("프로필 업데이트 실패", err)
		return fmt.Errorf("프로필 업데이트에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("프로필 업데이트: 사용자 %d", userID))

	return nil
}

func (s *UserService) UpdateLocation(userID uint, req *models.UpdateLocationRequest) error {
	// 좌표 유효성 검사
	if !utils.IsValidCoordinate(req.Latitude, req.Longitude) {
		return fmt.Errorf("유효하지 않은 좌표입니다")
	}

	// 한국 범위 내인지 확인 (선택사항)
	if !utils.IsInKorea(req.Latitude, req.Longitude) {
		s.logger.Warn(fmt.Sprintf("한국 범위 밖의 좌표: 사용자 %d", userID))
	}

	location := &models.UserLocation{
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
		Address:   req.Address,
	}

	if err := s.userRepo.UpdateLocation(userID, location); err != nil {
		s.logger.Error("위치 업데이트 실패", err)
		return fmt.Errorf("위치 업데이트에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("위치 업데이트: 사용자 %d", userID))

	return nil
}

func (s *UserService) UpdateInterests(userID uint, interests []models.UserInterest) error {
	if len(interests) == 0 {
		return fmt.Errorf("최소 하나의 관심사를 선택해주세요")
	}

	if len(interests) > 10 {
		return fmt.Errorf("관심사는 최대 10개까지 선택할 수 있습니다")
	}

	if err := s.userRepo.UpdateInterests(userID, interests); err != nil {
		s.logger.Error("관심사 업데이트 실패", err)
		return fmt.Errorf("관심사 업데이트에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("관심사 업데이트: 사용자 %d, 개수 %d", userID, len(interests)))

	return nil
}

func (s *UserService) RegisterPushToken(userID uint, token, platform string) error {
	pushToken := &models.PushToken{
		UserID:   userID,
		Token:    token,
		Platform: platform,
	}

	if err := s.userRepo.AddPushToken(pushToken); err != nil {
		s.logger.Error("푸시 토큰 등록 실패", err)
		return fmt.Errorf("푸시 토큰 등록에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("푸시 토큰 등록: 사용자 %d, 플랫폼 %s", userID, platform))

	return nil
}

func (s *UserService) RateUser(raterID uint, req *models.UserRating) error {
	req.RaterID = raterID

	if req.RaterID == req.RateeID {
		return fmt.Errorf("자기 자신을 평가할 수 없습니다")
	}

	if req.Score < 1 || req.Score > 5 {
		return fmt.Errorf("평점은 1-5점 사이여야 합니다")
	}

	if err := s.userRepo.RateUser(req); err != nil {
		s.logger.Error("사용자 평가 실패", err)
		return fmt.Errorf("사용자 평가에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("사용자 평가: %d -> %d, 점수 %d", raterID, req.RateeID, req.Score))

	return nil
}

func (s *UserService) ReportUser(reporterID uint, req *models.ReportUser) error {
	req.ReporterID = reporterID

	if req.ReporterID == req.ReportedID {
		return fmt.Errorf("자기 자신을 신고할 수 없습니다")
	}

	if err := s.userRepo.ReportUser(req); err != nil {
		s.logger.Error("사용자 신고 실패", err)
		return fmt.Errorf("사용자 신고에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("사용자 신고: %d -> %d, 사유 %s", reporterID, req.ReportedID, req.Reason))

	return nil
}

func (s *UserService) RefreshToken(refreshToken string) (*models.User, string, error) {
	claims, err := s.jwtManager.ValidateToken(refreshToken)
	if err != nil {
		return nil, "", fmt.Errorf("유효하지 않은 리프레시 토큰입니다")
	}

	user, err := s.userRepo.GetByID(claims.UserID)
	if err != nil {
		return nil, "", fmt.Errorf("사용자를 찾을 수 없습니다")
	}

	if !user.IsActive || user.IsBlocked {
		return nil, "", fmt.Errorf("비활성화되거나 차단된 계정입니다")
	}

	// 새 액세스 토큰 생성
	accessToken, err := s.jwtManager.GenerateAccessToken(user)
	if err != nil {
		s.logger.Error("토큰 생성 실패", err)
		return nil, "", fmt.Errorf("토큰 생성에 실패했습니다")
	}

	return user, accessToken, nil
}