package handlers

import (
	"context"
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"signal-be/internal/services"
	"signal-module/pkg/config"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/oauth"
	"signal-module/pkg/utils"

	"github.com/gin-gonic/gin"
)

// OAuthHandler OAuth 관련 핸들러
type OAuthHandler struct {
	oauthService *oauth.OAuthService
	userService  services.UserServiceInterface
	config       *config.Config
	logger       *logger.Logger
}

// NewOAuthHandler OAuth 핸들러 생성
func NewOAuthHandler(
	cfg *config.Config,
	userService services.UserServiceInterface,
	logger *logger.Logger,
) *OAuthHandler {
	return &OAuthHandler{
		oauthService: oauth.NewOAuthService(cfg.OAuth),
		userService:  userService,
		config:       cfg,
		logger:       logger,
	}
}

// StartOAuthLogin Google OAuth 로그인 시작
// GET /api/v1/auth/:provider/login
func (h *OAuthHandler) StartOAuthLogin(c *gin.Context) {
	provider := c.Param("provider")

	// OAuth 인증 URL 생성 (로그인용이므로 userID는 0)
	authURL, err := h.oauthService.GetAuthURL(provider, 0, "login")
	if err != nil {
		if err.Error() == fmt.Sprintf("oauth provider '%s' not found", provider) {
			utils.BadRequestResponse(c, fmt.Sprintf("지원하지 않는 제공업체입니다: %s", provider))
			return
		}
		h.logger.Error("OAuth URL 생성 실패", err)
		utils.InternalServerErrorResponse(c, "OAuth URL 생성에 실패했습니다", err)
		return
	}

	utils.SuccessResponse(c, "OAuth URL이 생성되었습니다", gin.H{
		"auth_url": authURL,
		"provider": provider,
		"action":   "login",
	})
}

// OAuthCallback OAuth 콜백 처리
// GET /api/v1/auth/:provider/callback
func (h *OAuthHandler) OAuthCallback(c *gin.Context) {
	provider := c.Param("provider")
	code := c.Query("code")
	state := c.Query("state")
	errorParam := c.Query("error")

	// 에러 처리
	if errorParam != "" {
		errorDescription := c.Query("error_description")
		h.logger.Warn(fmt.Sprintf("OAuth 에러: %s - %s", errorParam, errorDescription))
		
		redirectURL := fmt.Sprintf("%s/auth/callback?error=%s&description=%s",
			h.config.Server.FrontendURL, errorParam, errorDescription)
		c.Redirect(http.StatusFound, redirectURL)
		return
	}

	// code 검증
	if code == "" {
		redirectURL := fmt.Sprintf("%s/auth/callback?error=no_code", h.config.Server.FrontendURL)
		c.Redirect(http.StatusFound, redirectURL)
		return
	}

	// OAuth 콜백 처리
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	result, err := h.oauthService.HandleCallback(ctx, provider, code, state)
	if err != nil {
		h.logger.Error("OAuth 콜백 처리 실패", err)
		redirectURL := fmt.Sprintf("%s/auth/callback?error=oauth_failed&provider=%s",
			h.config.Server.FrontendURL, provider)
		c.Redirect(http.StatusFound, redirectURL)
		return
	}

	// 로그인 액션 처리
	if result.Action == "login" {
		user, accessToken, refreshToken, err := h.handleOAuthLogin(result)
		if err != nil {
			h.logger.Error("OAuth 로그인 처리 실패", err)
			redirectURL := fmt.Sprintf("%s/auth/callback?error=login_failed&provider=%s",
				h.config.Server.FrontendURL, provider)
			c.Redirect(http.StatusFound, redirectURL)
			return
		}

		// 성공 리다이렉트 (토큰을 쿼리 파라미터로 전달 - 보안상 권장하지 않음, 실제로는 다른 방법 사용)
		redirectURL := fmt.Sprintf("%s/auth/callback?success=true&access_token=%s&refresh_token=%s&username=%s",
			h.config.Server.FrontendURL, accessToken, refreshToken, user.Username)
		c.Redirect(http.StatusFound, redirectURL)
		return
	}

	// 기타 액션 - 향후 확장
	redirectURL := fmt.Sprintf("%s/auth/callback?error=unsupported_action", h.config.Server.FrontendURL)
	c.Redirect(http.StatusFound, redirectURL)
}

// handleOAuthLogin OAuth 로그인 처리
func (h *OAuthHandler) handleOAuthLogin(result *oauth.CallbackResult) (*models.User, string, string, error) {
	var user *models.User
	var err error

	// 제공업체별로 기존 사용자 확인
	switch result.Provider {
	case "google":
		user, err = h.userService.GetUserByGoogleID(result.Profile.ID)
	default:
		return nil, "", "", fmt.Errorf("지원하지 않는 제공업체: %s", result.Provider)
	}

	if err != nil {
		// 사용자가 없으면 새로 생성
		if err.Error() == "사용자를 찾을 수 없습니다" {
			user, err = h.createOAuthUser(result)
			if err != nil {
				return nil, "", "", fmt.Errorf("OAuth 사용자 생성 실패: %w", err)
			}
			result.IsNewUser = true
		} else {
			return nil, "", "", fmt.Errorf("사용자 조회 실패: %w", err)
		}
	}

	// JWT 토큰 생성
	jwtManager := utils.NewJWTManager(&h.config.JWT)
	accessToken, refreshToken, err := jwtManager.GenerateTokenPair(user)
	if err != nil {
		return nil, "", "", fmt.Errorf("토큰 생성 실패: %w", err)
	}

	h.logger.Info(fmt.Sprintf("OAuth 로그인 성공: %s (%s) via %s", 
		user.Username, user.Email, result.Provider))

	return user, accessToken, refreshToken, nil
}

// createOAuthUser OAuth를 통한 새 사용자 생성
func (h *OAuthHandler) createOAuthUser(result *oauth.CallbackResult) (*models.User, error) {
	// 이메일 중복 확인
	existingUser, _ := h.userService.GetUserByEmail(result.Profile.Email)
	if existingUser != nil {
		return nil, fmt.Errorf("이미 등록된 이메일입니다")
	}

	// 사용자명 생성 (이메일 @ 앞부분 사용, 중복시 번호 추가)
	username := h.generateUsername(result.Profile.Email)

	createReq := &models.CreateUserRequest{
		Email:       result.Profile.Email,
		Username:    username,
		DisplayName: result.Profile.DisplayName,
		Provider:    result.Provider,
	}

	// OAuth 제공업체별 ID 설정
	if result.Provider == "google" {
		createReq.GoogleID = &result.Profile.ID
	}

	user, _, _, err := h.userService.RegisterOAuth(createReq)
	if err != nil {
		return nil, err
	}

	return user, nil
}

// generateUsername 이메일에서 사용자명 생성
func (h *OAuthHandler) generateUsername(email string) string {
	// 이메일에서 @ 앞부분 추출
	atIndex := strings.Index(email, "@")
	if atIndex == -1 {
		return "user" + strconv.FormatInt(time.Now().Unix(), 10)
	}

	baseUsername := email[:atIndex]
	
	// 특수문자 제거 및 소문자로 변환
	baseUsername = strings.ToLower(baseUsername)
	baseUsername = regexp.MustCompile(`[^a-z0-9]`).ReplaceAllString(baseUsername, "")
	
	if len(baseUsername) < 3 {
		baseUsername = "user" + baseUsername
	}
	
	if len(baseUsername) > 20 {
		baseUsername = baseUsername[:20]
	}

	// 중복 확인 및 번호 추가
	username := baseUsername
	counter := 1
	for {
		if existingUser, _ := h.userService.GetUserByUsername(username); existingUser == nil {
			break
		}
		username = fmt.Sprintf("%s%d", baseUsername, counter)
		counter++
		
		// 최대 길이 초과시 조정
		if len(username) > 20 {
			baseUsername = baseUsername[:20-len(fmt.Sprintf("%d", counter))]
			username = fmt.Sprintf("%s%d", baseUsername, counter)
		}
	}

	return username
}

// GetSupportedProviders 지원되는 OAuth 제공업체 목록 조회
// GET /api/v1/auth/oauth/providers
func (h *OAuthHandler) GetSupportedProviders(c *gin.Context) {
	providers := h.oauthService.GetSupportedProviders()

	utils.SuccessResponse(c, "지원되는 OAuth 제공업체 목록입니다", gin.H{
		"providers": providers,
		"count":     len(providers),
	})
}