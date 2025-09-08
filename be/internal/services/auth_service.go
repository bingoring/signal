package services

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"gorm.io/gorm"

	"signal-module/pkg/models"
)

type AuthService struct {
	db          *gorm.DB
	emailService *EmailService
	jwtSecret   []byte
	appURL      string
}

type AuthRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type AuthResponse struct {
	Message string `json:"message"`
	Success bool   `json:"success"`
}

type TokenVerifyResponse struct {
	Token    string      `json:"token"`
	User     models.User `json:"user"`
	IsNewUser bool       `json:"is_new_user"`
}

type JWTClaims struct {
	UserID uint   `json:"user_id"`
	Email  string `json:"email"`
	jwt.RegisteredClaims
}

var (
	ErrInvalidToken = errors.New("invalid or expired token")
	ErrTokenAlreadyUsed = errors.New("token has already been used")
	ErrUserNotFound = errors.New("user not found")
)

func NewAuthService(db *gorm.DB, emailService *EmailService, jwtSecret string, appURL string) *AuthService {
	return &AuthService{
		db:          db,
		emailService: emailService,
		jwtSecret:   []byte(jwtSecret),
		appURL:      appURL,
	}
}

// SendMagicLink generates and sends a magic link to the user's email
func (as *AuthService) SendMagicLink(email string) (*AuthResponse, error) {
	// Generate secure random token
	token, err := as.generateSecureToken()
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	// Check if user exists
	var user models.User
	userExists := true
	err = as.db.Where("email = ?", email).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			userExists = false
		} else {
			return nil, fmt.Errorf("database error: %w", err)
		}
	}

	purpose := "login"
	if !userExists {
		purpose = "signup"
	}

	// Clean up any existing tokens for this email
	err = as.db.Where("email = ? AND used = false", email).Delete(&models.AuthToken{}).Error
	if err != nil {
		log.Printf("Failed to clean up existing tokens: %v", err)
	}

	// Create new auth token
	authToken := &models.AuthToken{
		Email:     email,
		Token:     token,
		Purpose:   purpose,
		Used:      false,
		ExpiresAt: time.Now().Add(15 * time.Minute), // 15분 유효
	}

	err = as.db.Create(authToken).Error
	if err != nil {
		return nil, fmt.Errorf("failed to create auth token: %w", err)
	}

	// Send magic link email
	magicLink := fmt.Sprintf("%s/auth/verify?token=%s", as.appURL, token)
	err = as.emailService.SendMagicLinkEmail(email, magicLink, purpose)
	if err != nil {
		return nil, fmt.Errorf("failed to send email: %w", err)
	}

	message := "로그인 링크가 이메일로 전송되었습니다. 이메일을 확인해주세요."
	if !userExists {
		message = "회원가입 링크가 이메일로 전송되었습니다. 이메일을 확인해주세요."
	}

	return &AuthResponse{
		Message: message,
		Success: true,
	}, nil
}

// VerifyMagicLink verifies the magic link token and returns JWT
func (as *AuthService) VerifyMagicLink(token string) (*TokenVerifyResponse, error) {
	// Find the auth token
	var authToken models.AuthToken
	err := as.db.Where("token = ?", token).First(&authToken).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrInvalidToken
		}
		return nil, fmt.Errorf("database error: %w", err)
	}

	// Check if token is valid
	if !authToken.IsValid() {
		if authToken.Used {
			return nil, ErrTokenAlreadyUsed
		}
		return nil, ErrInvalidToken
	}

	// Mark token as used
	authToken.MarkAsUsed()
	err = as.db.Save(&authToken).Error
	if err != nil {
		return nil, fmt.Errorf("failed to mark token as used: %w", err)
	}

	var user models.User
	isNewUser := false

	// Handle signup vs login
	if authToken.Purpose == "signup" {
		// Create new user
		user = models.User{
			Email:    authToken.Email,
			Username: as.generateUsernameFromEmail(authToken.Email),
			IsActive: true,
		}
		
		err = as.db.Create(&user).Error
		if err != nil {
			return nil, fmt.Errorf("failed to create user: %w", err)
		}
		isNewUser = true
	} else {
		// Find existing user
		err = as.db.Where("email = ?", authToken.Email).First(&user).Error
		if err != nil {
			return nil, ErrUserNotFound
		}
	}

	// Generate JWT token
	jwtToken, err := as.generateJWT(user)
	if err != nil {
		return nil, fmt.Errorf("failed to generate JWT: %w", err)
	}

	return &TokenVerifyResponse{
		Token:    jwtToken,
		User:     user,
		IsNewUser: isNewUser,
	}, nil
}

// ValidateJWT validates and parses JWT token
func (as *AuthService) ValidateJWT(tokenString string) (*JWTClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return as.jwtSecret, nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*JWTClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

// GetUserFromToken extracts user from JWT token
func (as *AuthService) GetUserFromToken(tokenString string) (*models.User, error) {
	claims, err := as.ValidateJWT(tokenString)
	if err != nil {
		return nil, err
	}

	var user models.User
	err = as.db.Where("id = ?", claims.UserID).First(&user).Error
	if err != nil {
		return nil, ErrUserNotFound
	}

	return &user, nil
}

// generateSecureToken generates a cryptographically secure random token
func (as *AuthService) generateSecureToken() (string, error) {
	bytes := make([]byte, 32)
	_, err := rand.Read(bytes)
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// generateJWT creates a JWT token for the user
func (as *AuthService) generateJWT(user models.User) (string, error) {
	claims := &JWTClaims{
		UserID: user.ID,
		Email:  user.Email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour * 7)), // 7 days
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(as.jwtSecret)
}

// generateUsernameFromEmail creates a username from email
func (as *AuthService) generateUsernameFromEmail(email string) string {
	// Simple implementation - take part before @ and add random suffix if needed
	atIndex := 0
	for i, char := range email {
		if char == '@' {
			atIndex = i
			break
		}
	}
	
	if atIndex > 0 {
		baseUsername := email[:atIndex]
		
		// Check if username exists
		var count int64
		as.db.Model(&models.User{}).Where("username LIKE ?", baseUsername+"%").Count(&count)
		
		if count == 0 {
			return baseUsername
		}
		
		return fmt.Sprintf("%s_%d", baseUsername, count+1)
	}
	
	return "user_" + fmt.Sprintf("%d", time.Now().Unix())
}