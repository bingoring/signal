package utils

import (
	"fmt"
	"time"

	"signal-module/pkg/config"
	"signal-module/pkg/models"

	"github.com/golang-jwt/jwt/v5"
)

type JWTManager struct {
	secretKey string
}

func NewJWTManager(cfg *config.JWTConfig) *JWTManager {
	return &JWTManager{
		secretKey: cfg.Secret,
	}
}

type Claims struct {
	UserID   uint   `json:"user_id"`
	Email    string `json:"email"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// JWT 토큰 생성
func (j *JWTManager) GenerateToken(user *models.User, expirationTime time.Duration) (string, error) {
	claims := &Claims{
		UserID:   user.ID,
		Email:    user.Email,
		Username: user.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expirationTime)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "signal-app",
			Subject:   fmt.Sprintf("user:%d", user.ID),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(j.secretKey))
}

// JWT 토큰 검증
func (j *JWTManager) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("예상치 못한 서명 방법: %v", token.Header["alg"])
		}
		return []byte(j.secretKey), nil
	})

	if err != nil {
		return nil, fmt.Errorf("토큰 파싱 실패: %w", err)
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, fmt.Errorf("유효하지 않은 토큰")
}

// 액세스 토큰 생성 (1시간)
func (j *JWTManager) GenerateAccessToken(user *models.User) (string, error) {
	return j.GenerateToken(user, time.Hour)
}

// 리프레시 토큰 생성 (7일)
func (j *JWTManager) GenerateRefreshToken(user *models.User) (string, error) {
	return j.GenerateToken(user, 7*24*time.Hour)
}

// 토큰 페어 생성
func (j *JWTManager) GenerateTokenPair(user *models.User) (accessToken, refreshToken string, err error) {
	accessToken, err = j.GenerateAccessToken(user)
	if err != nil {
		return "", "", fmt.Errorf("액세스 토큰 생성 실패: %w", err)
	}

	refreshToken, err = j.GenerateRefreshToken(user)
	if err != nil {
		return "", "", fmt.Errorf("리프레시 토큰 생성 실패: %w", err)
	}

	return accessToken, refreshToken, nil
}