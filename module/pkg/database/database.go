package database

import (
	"fmt"
	"log"
	"time"

	"signal-module/pkg/config"
	"signal-module/pkg/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type Database struct {
	DB *gorm.DB
}

func New(cfg *config.DatabaseConfig) (*Database, error) {
	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
		cfg.Host, cfg.User, cfg.Password, cfg.Name, cfg.Port, cfg.SSLMode)

	var gormLogger logger.Interface
	if cfg.Host == "localhost" || cfg.Host == "postgres" {
		gormLogger = logger.Default.LogMode(logger.Info)
	} else {
		gormLogger = logger.Default.LogMode(logger.Error)
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: gormLogger,
	})
	if err != nil {
		return nil, fmt.Errorf("데이터베이스 연결 실패: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("데이터베이스 인스턴스 가져오기 실패: %w", err)
	}

	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)
	sqlDB.SetConnMaxLifetime(time.Hour)

	log.Println("✅ 데이터베이스 연결 완료")
	return &Database{DB: db}, nil
}

func (d *Database) Migrate() error {
	log.Println("🔄 데이터베이스 마이그레이션 시작...")
	
	err := d.DB.AutoMigrate(
		&models.User{},
		&models.UserProfile{},
		&models.UserLocation{},
		&models.UserInterest{},
		&models.Signal{},
		&models.SignalParticipant{},
		&models.ChatRoom{},
		&models.ChatMessage{},
		&models.UserRating{},
		&models.ReportUser{},
		&models.PushToken{},
	)
	
	if err != nil {
		return fmt.Errorf("마이그레이션 실패: %w", err)
	}
	
	if err := d.createIndexes(); err != nil {
		return fmt.Errorf("인덱스 생성 실패: %w", err)
	}
	
	log.Println("✅ 데이터베이스 마이그레이션 완료")
	return nil
}

func (d *Database) createIndexes() error {
	indexes := []string{
		// 지리적 위치 인덱스 (PostGIS)
		`CREATE INDEX IF NOT EXISTS idx_signals_location 
		 ON signals USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326))`,
		
		// 시그널 검색 성능 인덱스
		`CREATE INDEX IF NOT EXISTS idx_signals_active 
		 ON signals (status, scheduled_at, created_at) 
		 WHERE status = 'active'`,
		
		// 사용자 위치 인덱스
		`CREATE INDEX IF NOT EXISTS idx_user_locations_active 
		 ON user_locations (user_id, is_active, updated_at)`,
		
		// 채팅 메시지 인덱스
		`CREATE INDEX IF NOT EXISTS idx_chat_messages_room_time 
		 ON chat_messages (chat_room_id, created_at DESC)`,
		
		// 푸시 토큰 인덱스
		`CREATE INDEX IF NOT EXISTS idx_push_tokens_active 
		 ON push_tokens (user_id, is_active)`,
	}

	for _, indexSQL := range indexes {
		if err := d.DB.Exec(indexSQL).Error; err != nil {
			log.Printf("⚠️ 인덱스 생성 실패: %v", err)
		}
	}

	return nil
}

func (d *Database) Close() error {
	sqlDB, err := d.DB.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}