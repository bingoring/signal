package integration

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/suite"
	_ "github.com/lib/pq"
	"gopkg.in/yaml.v3"
)

type TestConfig struct {
	TestEnvironments struct {
		Docker struct {
			BackendURL    string `yaml:"backend_url"`
			WebSocketURL  string `yaml:"websocket_url"`
			DatabaseURL   string `yaml:"database_url"`
			RedisURL      string `yaml:"redis_url"`
		} `yaml:"docker"`
	} `yaml:"test_environments"`
	
	TestData struct {
		Users struct {
			Count int `yaml:"count"`
			LocationRange struct {
				LatMin float64 `yaml:"lat_min"`
				LatMax float64 `yaml:"lat_max"`
				LngMin float64 `yaml:"lng_min"`
				LngMax float64 `yaml:"lng_max"`
			} `yaml:"location_range"`
		} `yaml:"users"`
		
		Signals struct {
			Count           int      `yaml:"count"`
			Categories      []string `yaml:"categories"`
			MaxParticipants []int    `yaml:"max_participants"`
		} `yaml:"signals"`
		
		ChatRooms struct {
			Count           int `yaml:"count"`
			MessagesPerRoom int `yaml:"messages_per_room"`
		} `yaml:"chat_rooms"`
	} `yaml:"test_data"`
	
	Timeouts struct {
		APIRequest       int `yaml:"api_request"`
		WebSocketConnect int `yaml:"websocket_connect"`
		DatabaseQuery    int `yaml:"database_query"`
		TestScenario     int `yaml:"test_scenario"`
	} `yaml:"timeouts"`
}

type IntegrationTestSuite struct {
	suite.Suite
	config     *TestConfig
	db         *sql.DB
	redis      *redis.Client
	httpClient *http.Client
	baseURL    string
	wsURL      string
	testUsers  []TestUser
	testSignals []TestSignal
}

type TestUser struct {
	ID       uint    `json:"id"`
	Email    string  `json:"email"`
	Name     string  `json:"name"`
	Token    string  `json:"token"`
	Latitude float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type TestSignal struct {
	ID          uint      `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Category    string    `json:"category"`
	CreatorID   uint      `json:"creator_id"`
	Latitude    float64   `json:"latitude"`
	Longitude   float64   `json:"longitude"`
	MaxCount    int       `json:"max_count"`
	CreatedAt   time.Time `json:"created_at"`
}

type ChatRoom struct {
	ID        uint      `json:"id"`
	SignalID  uint      `json:"signal_id"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

type ChatMessage struct {
	ID        uint      `json:"id"`
	RoomID    uint      `json:"room_id"`
	UserID    uint      `json:"user_id"`
	Type      string    `json:"type"`
	Content   string    `json:"content"`
	Location  *Location `json:"location,omitempty"`
	ImageURL  string    `json:"image_url,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type Location struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

func TestIntegrationSuite(t *testing.T) {
	suite.Run(t, new(IntegrationTestSuite))
}

func (s *IntegrationTestSuite) SetupSuite() {
	// Load test configuration
	configFile, err := os.ReadFile("../config.yaml")
	s.Require().NoError(err, "Failed to load test config")
	
	s.config = &TestConfig{}
	err = yaml.Unmarshal(configFile, s.config)
	s.Require().NoError(err, "Failed to parse test config")
	
	// Set URLs
	s.baseURL = s.config.TestEnvironments.Docker.BackendURL
	s.wsURL = s.config.TestEnvironments.Docker.WebSocketURL
	
	// Initialize HTTP client
	s.httpClient = &http.Client{
		Timeout: time.Duration(s.config.Timeouts.APIRequest) * time.Second,
	}
	
	// Initialize database connection
	s.db, err = sql.Open("postgres", s.config.TestEnvironments.Docker.DatabaseURL)
	s.Require().NoError(err, "Failed to connect to test database")
	
	err = s.db.Ping()
	s.Require().NoError(err, "Failed to ping test database")
	
	// Initialize Redis connection
	opt, err := redis.ParseURL(s.config.TestEnvironments.Docker.RedisURL)
	s.Require().NoError(err, "Failed to parse Redis URL")
	
	s.redis = redis.NewClient(opt)
	_, err = s.redis.Ping(context.Background()).Result()
	s.Require().NoError(err, "Failed to connect to test Redis")
	
	log.Println("Integration test suite setup completed")
}

func (s *IntegrationTestSuite) TearDownSuite() {
	if s.db != nil {
		s.db.Close()
	}
	if s.redis != nil {
		s.redis.Close()
	}
	log.Println("Integration test suite teardown completed")
}

func (s *IntegrationTestSuite) SetupTest() {
	// Clean up test data before each test
	s.cleanupTestData()
	
	// Wait for services to be ready
	s.waitForServices()
}

func (s *IntegrationTestSuite) TearDownTest() {
	// Clean up test data after each test
	s.cleanupTestData()
}

func (s *IntegrationTestSuite) cleanupTestData() {
	// Clean up database
	tables := []string{"chat_messages", "chat_rooms", "signal_participants", "signals", "users"}
	for _, table := range tables {
		_, err := s.db.Exec(fmt.Sprintf("DELETE FROM %s WHERE email LIKE 'test%%' OR title LIKE 'test%%'", table))
		if err != nil {
			log.Printf("Warning: Failed to clean up table %s: %v", table, err)
		}
	}
	
	// Clean up Redis
	ctx := context.Background()
	keys, err := s.redis.Keys(ctx, "test:*").Result()
	if err == nil && len(keys) > 0 {
		s.redis.Del(ctx, keys...)
	}
}

func (s *IntegrationTestSuite) waitForServices() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	// Wait for backend service
	for {
		select {
		case <-ctx.Done():
			s.FailNow("Backend service not ready within timeout")
		default:
			resp, err := s.httpClient.Get(s.baseURL + "/health")
			if err == nil && resp.StatusCode == 200 {
				resp.Body.Close()
				log.Println("Backend service is ready")
				return
			}
			if resp != nil {
				resp.Body.Close()
			}
			time.Sleep(1 * time.Second)
		}
	}
}

// Helper methods for test data creation
func (s *IntegrationTestSuite) createTestUser(email, name string, lat, lng float64) TestUser {
	// Implementation will be added in subsequent files
	return TestUser{}
}

func (s *IntegrationTestSuite) createTestSignal(creatorID uint, title, category string, lat, lng float64, maxCount int) TestSignal {
	// Implementation will be added in subsequent files
	return TestSignal{}
}

func (s *IntegrationTestSuite) createWebSocketConnection(token string) (*websocket.Conn, error) {
	// Implementation will be added in subsequent files
	return nil, nil
}