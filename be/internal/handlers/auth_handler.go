package handlers

import (
	"strings"
	"signal-be/internal/services"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/utils"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	userService services.UserServiceInterface
	authService *services.AuthService
	logger      *logger.Logger
}

func NewAuthHandler(userService services.UserServiceInterface, authService *services.AuthService, logger *logger.Logger) *AuthHandler {
	return &AuthHandler{
		userService: userService,
		authService: authService,
		logger:      logger,
	}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req models.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
		return
	}

	user, accessToken, refreshToken, err := h.userService.Register(&req)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	utils.CreatedResponse(c, "회원가입이 완료되었습니다", gin.H{
		"user":          user,
		"access_token":  accessToken,
		"refresh_token": refreshToken,
	})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "이메일을 입력해주세요")
		return
	}

	user, accessToken, refreshToken, err := h.userService.Login(req.Email, req.Password)
	if err != nil {
		utils.UnauthorizedResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "로그인이 완료되었습니다", gin.H{
		"user":          user,
		"access_token":  accessToken,
		"refresh_token": refreshToken,
	})
}

func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "리프레시 토큰이 필요합니다")
		return
	}

	user, accessToken, err := h.userService.RefreshToken(req.RefreshToken)
	if err != nil {
		utils.UnauthorizedResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, "토큰이 갱신되었습니다", gin.H{
		"user":         user,
		"access_token": accessToken,
	})
}

// SendMagicLink handles POST /api/v1/auth/magic-link
func (h *AuthHandler) SendMagicLink(c *gin.Context) {
	var req services.AuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "유효한 이메일 주소를 입력해주세요")
		return
	}

	response, err := h.authService.SendMagicLink(req.Email)
	if err != nil {
		h.logger.Error("Failed to send magic link", err)
		utils.InternalServerErrorResponse(c, "매직링크 전송에 실패했습니다", err)
		return
	}

	utils.SuccessResponse(c, response.Message, nil)
}

// VerifyMagicLink handles GET /api/v1/auth/verify
func (h *AuthHandler) VerifyMagicLink(c *gin.Context) {
	token := c.Query("token")
	if token == "" {
		utils.BadRequestResponse(c, "토큰이 필요합니다")
		return
	}

	response, err := h.authService.VerifyMagicLink(token)
	if err != nil {
		h.logger.Error("Failed to verify magic link", err)
		
		switch err {
		case services.ErrInvalidToken:
			utils.BadRequestResponse(c, "유효하지 않거나 만료된 토큰입니다")
		case services.ErrTokenAlreadyUsed:
			utils.BadRequestResponse(c, "이미 사용된 토큰입니다")
		case services.ErrUserNotFound:
			utils.NotFoundResponse(c, "사용자를 찾을 수 없습니다")
		default:
			utils.InternalServerErrorResponse(c, "인증에 실패했습니다", err)
		}
		return
	}

	// Set JWT token in cookie for web browser access
	c.SetCookie(
		"auth_token",
		response.Token,
		60*60*24*7, // 7 days
		"/",
		"",
		false, // set to true in production with HTTPS
		true,  // HTTP only
	)

	utils.SuccessResponse(c, "로그인이 완료되었습니다", gin.H{
		"token":       response.Token,
		"user":        response.User,
		"is_new_user": response.IsNewUser,
	})
}

// GetProfile handles GET /api/v1/auth/profile
func (h *AuthHandler) GetProfile(c *gin.Context) {
	userInterface, exists := c.Get("user")
	if !exists {
		utils.UnauthorizedResponse(c, "인증이 필요합니다")
		return
	}

	_, ok := userInterface.(*services.JWTClaims)
	if !ok {
		utils.InternalServerErrorResponse(c, "잘못된 사용자 정보입니다", nil)
		return
	}

	// Get authorization header
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" {
		token, err := c.Cookie("auth_token")
		if err != nil {
			utils.UnauthorizedResponse(c, "인증 토큰이 필요합니다")
			return
		}
		authHeader = "Bearer " + token
	}

	tokenString := authHeader[7:] // Remove "Bearer " prefix
	fullUser, err := h.authService.GetUserFromToken(tokenString)
	if err != nil {
		utils.InternalServerErrorResponse(c, "사용자 프로필을 가져올 수 없습니다", err)
		return
	}

	utils.SuccessResponse(c, "프로필 조회 완료", gin.H{
		"user": fullUser,
	})
}

// Logout handles POST /api/v1/auth/logout
func (h *AuthHandler) Logout(c *gin.Context) {
	// Clear the auth cookie
	c.SetCookie(
		"auth_token",
		"",
		-1, // Expire immediately
		"/",
		"",
		false,
		true,
	)

	utils.SuccessResponse(c, "로그아웃이 완료되었습니다", nil)
}

// AuthMiddleware provides JWT authentication middleware
func (h *AuthHandler) AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			// Try to get token from cookie
			token, err := c.Cookie("auth_token")
			if err != nil {
				utils.UnauthorizedResponse(c, "인증이 필요합니다")
				c.Abort()
				return
			}
			authHeader = "Bearer " + token
		}

		if !strings.HasPrefix(authHeader, "Bearer ") {
			utils.UnauthorizedResponse(c, "잘못된 인증 헤더 형식입니다")
			c.Abort()
			return
		}

		tokenString := authHeader[7:] // Remove "Bearer " prefix
		claims, err := h.authService.ValidateJWT(tokenString)
		if err != nil {
			utils.UnauthorizedResponse(c, "유효하지 않거나 만료된 토큰입니다")
			c.Abort()
			return
		}

		// Add user info to context
		c.Set("user", claims)
		c.Set("user_id", claims.UserID)
		c.Set("user_email", claims.Email)
		c.Next()
	}
}

// OptionalAuthMiddleware provides optional JWT authentication
func (h *AuthHandler) OptionalAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			// Try to get token from cookie
			token, err := c.Cookie("auth_token")
			if err != nil {
				// No auth provided, continue without setting user context
				c.Next()
				return
			}
			authHeader = "Bearer " + token
		}

		if strings.HasPrefix(authHeader, "Bearer ") {
			tokenString := authHeader[7:]
			claims, err := h.authService.ValidateJWT(tokenString)
			if err == nil {
				c.Set("user", claims)
				c.Set("user_id", claims.UserID)
				c.Set("user_email", claims.Email)
			}
		}

		c.Next()
	}
}