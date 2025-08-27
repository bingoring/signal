package config

import (
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Database DatabaseConfig
	JWT      JWTConfig
	Server   ServerConfig
	Redis    RedisConfig
	Push     PushConfig
	Location LocationConfig
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	Name     string
	SSLMode  string
}

type JWTConfig struct {
	Secret string
}

type ServerConfig struct {
	Port        string
	Mode        string
	FrontendURL string
}

type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

type PushConfig struct {
	FCMServerKey string
	APNSKeyPath  string
	APNSKeyID    string
	APNSTeamID   string
}

type LocationConfig struct {
	DefaultRadius float64 // 기본 검색 반경 (미터)
	MaxRadius     float64 // 최대 검색 반경 (미터)
}

func LoadConfig() *Config {
	if err := godotenv.Load(); err != nil {
		log.Println("⚠️ .env 파일을 찾을 수 없습니다. 환경변수를 사용합니다.")
	} else {
		log.Println("✅ .env 파일을 로드했습니다.")
	}

	return &Config{
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "signal"),
			Password: getEnv("DB_PASSWORD", "signal_password"),
			Name:     getEnv("DB_NAME", "signal"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
		JWT: JWTConfig{
			Secret: getEnv("JWT_SECRET", "signal-super-secret-jwt-key"),
		},
		Server: ServerConfig{
			Port:        getEnv("PORT", "8080"),
			Mode:        getEnv("GIN_MODE", "debug"),
			FrontendURL: getEnv("FRONTEND_URL", "http://localhost:3000"),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       getEnvAsInt("REDIS_DB", 0),
		},
		Push: PushConfig{
			FCMServerKey: getEnv("FCM_SERVER_KEY", ""),
			APNSKeyPath:  getEnv("APNS_KEY_PATH", ""),
			APNSKeyID:    getEnv("APNS_KEY_ID", ""),
			APNSTeamID:   getEnv("APNS_TEAM_ID", ""),
		},
		Location: LocationConfig{
			DefaultRadius: getEnvAsFloat("DEFAULT_RADIUS", 5000.0), // 5km
			MaxRadius:     getEnvAsFloat("MAX_RADIUS", 50000.0),    // 50km
		},
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getEnvAsFloat(key string, defaultValue float64) float64 {
	if value := os.Getenv(key); value != "" {
		if floatValue, err := strconv.ParseFloat(value, 64); err == nil {
			return floatValue
		}
	}
	return defaultValue
}