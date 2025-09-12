package integration

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"signal-module/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
)

type MinimalProfileTestSuite struct {
	BaseIntegrationTestSuite
}

func (suite *MinimalProfileTestSuite) SetupTest() {
	suite.BaseIntegrationTestSuite.SetupTest()
}

func (suite *MinimalProfileTestSuite) TearDownTest() {
	suite.BaseIntegrationTestSuite.TearDownTest()
}

// TestMannerTemperatureCalculation - 매너온도 계산 로직 테스트
func (suite *MinimalProfileTestSuite) TestMannerTemperatureCalculation() {
	// Given: 새 사용자 생성
	user := suite.CreateTestUser("testuser@example.com", "testuser", "테스트유저")
	
	// When: 기본 매너온도 확인
	assert.Equal(suite.T(), 36.5, user.Profile.MannerTemperature, "기본 매너온도는 36.5도여야 합니다")
	
	// When: Signal 생성 활동 추가
	user.Profile.IncrementSignalCount()
	
	// Then: 매너온도 증가 확인 (36.5 + 0.1 = 36.6)
	expectedTemp := 36.6
	assert.Equal(suite.T(), expectedTemp, user.Profile.MannerTemperature, "Signal 생성 시 매너온도가 0.1도 증가해야 합니다")
	assert.Equal(suite.T(), 100.0, user.Profile.CompletionRate, "완료율이 100%여야 합니다")
	
	// When: 노쇼 추가
	user.Profile.IncrementNoShowCount()
	
	// Then: 매너온도 감소 확인 (36.6 - 0.3 = 36.3)
	expectedTemp = 36.3
	assert.Equal(suite.T(), expectedTemp, user.Profile.MannerTemperature, "노쇼 시 매너온도가 0.3도 감소해야 합니다")
	assert.Equal(suite.T(), 0.0, user.Profile.CompletionRate, "완료율이 0%가 되어야 합니다")
}

// TestTrustLevelClassification - 신뢰도 레벨 분류 테스트
func (suite *MinimalProfileTestSuite) TestTrustLevelClassification() {
	testCases := []struct {
		temperature float64
		expected   string
	}{
		{50.0, "매우 높음"},
		{45.0, "매우 높음"},
		{44.9, "높음"},
		{40.0, "높음"},
		{39.9, "보통"},
		{37.0, "보통"},
		{36.9, "낮음"},
		{32.0, "낮음"},
		{31.9, "매우 낮음"},
		{20.0, "매우 낮음"},
	}
	
	user := suite.CreateTestUser("trust@example.com", "trustuser", "신뢰테스트")
	
	for _, tc := range testCases {
		user.Profile.MannerTemperature = tc.temperature
		actual := user.Profile.GetTrustLevel()
		assert.Equal(suite.T(), tc.expected, actual, 
			fmt.Sprintf("매너온도 %.1f도에서 신뢰도는 '%s'이어야 합니다", tc.temperature, tc.expected))
	}
}

// TestQuickSetupAPI - 빠른 프로필 설정 API 테스트
func (suite *MinimalProfileTestSuite) TestQuickSetupAPI() {
	// Given: 인증된 사용자
	user := suite.CreateTestUser("quicksetup@example.com", "quickuser", "")
	token := suite.GenerateJWTToken(user)
	
	// When: 빠른 설정 요청
	setupData := map[string]interface{}{
		"display_name": "빠른설정유저",
		"avatar":       "😊",
		"one_line":     "즉석 만남을 좋아하는 사람입니다!",
	}
	
	body, _ := json.Marshal(setupData)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/quick-setup", bytes.NewBuffer(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	
	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
	
	// Then: 성공적인 설정 확인
	assert.Equal(suite.T(), http.StatusOK, w.Code)
	
	var response map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &response)
	
	data := response["data"].(map[string]interface{})
	assert.Equal(suite.T(), "빠른설정유저", data["display_name"])
	assert.Equal(suite.T(), "😊", data["avatar"])
	assert.Equal(suite.T(), "즉석 만남을 좋아하는 사람입니다!", data["one_line"])
	assert.Equal(suite.T(), 36.5, data["manner_temperature"])
	assert.Equal(suite.T(), true, data["setup_completed"])
}

// TestMinimalProfileAPI - 최소 프로필 조회 API 테스트
func (suite *MinimalProfileTestSuite) TestMinimalProfileAPI() {
	// Given: 활동이 있는 사용자 생성
	user := suite.CreateTestUser("active@example.com", "activeuser", "활성사용자")
	user.Profile.DisplayName = "활성사용자"
	user.Profile.Avatar = &[]string{"🎾"}[0]
	user.Profile.OneLine = &[]string{"테니스를 좋아합니다"}[0]
	user.Profile.SignalCount = 5
	user.Profile.JoinCount = 10
	user.Profile.NoShowCount = 1
	user.Profile.UpdateMannerTemperature()
	suite.db.Save(&user.Profile)
	
	// When: 다른 사용자가 최소 프로필 조회
	otherUser := suite.CreateTestUser("viewer@example.com", "viewer", "조회자")
	token := suite.GenerateJWTToken(otherUser)
	
	req := httptest.NewRequest(http.MethodGet, "/api/v1/users/activeuser/minimal", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	
	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
	
	// Then: 최소 정보만 반환 확인
	assert.Equal(suite.T(), http.StatusOK, w.Code)
	
	var response map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &response)
	
	data := response["data"].(map[string]interface{})
	assert.Equal(suite.T(), "activeuser", data["username"])
	assert.Equal(suite.T(), "활성사용자", data["display_name"])
	assert.Equal(suite.T(), "🎾", data["avatar"])
	assert.Equal(suite.T(), "테니스를 좋아합니다", data["one_line"])
	assert.Equal(suite.T(), 15.0, data["total_activities"]) // 5 + 10
	
	// 민감한 정보는 포함되지 않아야 함
	assert.NotContains(suite.T(), data, "email")
	assert.NotContains(suite.T(), data, "no_show_count")
	assert.NotContains(suite.T(), data, "total_ratings")
}

// TestMannerTemperatureUpdateAPI - 매너온도 업데이트 API 테스트
func (suite *MinimalProfileTestSuite) TestMannerTemperatureUpdateAPI() {
	// Given: 인증된 사용자
	user := suite.CreateTestUser("update@example.com", "updateuser", "업데이트유저")
	token := suite.GenerateJWTToken(user)
	
	// When: Signal 생성 활동 업데이트
	updateData := map[string]interface{}{
		"action": "signal_created",
	}
	
	body, _ := json.Marshal(updateData)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/manner-temperature", bytes.NewBuffer(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	
	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
	
	// Then: 매너온도 업데이트 확인
	assert.Equal(suite.T(), http.StatusOK, w.Code)
	
	var response map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &response)
	
	data := response["data"].(map[string]interface{})
	assert.Equal(suite.T(), 36.6, data["manner_temperature"]) // 36.5 + 0.1
	assert.Equal(suite.T(), "보통", data["trust_level"])
	assert.Equal(suite.T(), 100.0, data["completion_rate"])
	assert.Equal(suite.T(), 1.0, data["total_activities"])
}

// TestTrustStatsAPI - 신뢰 통계 API 테스트
func (suite *MinimalProfileTestSuite) TestTrustStatsAPI() {
	// Given: 다양한 활동이 있는 사용자
	user := suite.CreateTestUser("stats@example.com", "statsuser", "통계유저")
	user.Profile.SignalCount = 3
	user.Profile.JoinCount = 7
	user.Profile.NoShowCount = 2
	user.Profile.TotalRatings = 5
	now := time.Now()
	user.Profile.LastActivityAt = &now
	user.Profile.UpdateMannerTemperature()
	suite.db.Save(&user.Profile)
	
	token := suite.GenerateJWTToken(user)
	
	// When: 신뢰 통계 조회
	req := httptest.NewRequest(http.MethodGet, "/api/v1/users/trust-stats", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	
	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
	
	// Then: 상세 통계 반환 확인
	assert.Equal(suite.T(), http.StatusOK, w.Code)
	
	var response map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &response)
	
	data := response["data"].(map[string]interface{})
	assert.Equal(suite.T(), 3.0, data["signal_count"])
	assert.Equal(suite.T(), 7.0, data["join_count"])
	assert.Equal(suite.T(), 10.0, data["total_activities"]) // 3 + 7
	assert.Equal(suite.T(), 2.0, data["no_show_count"])
	assert.Equal(suite.T(), 80.0, data["completion_rate"]) // (10-2)/10 * 100
	assert.Equal(suite.T(), 5.0, data["total_ratings"])
	assert.Equal(suite.T(), true, data["is_recently_active"])
}

// TestRecentActivityCheck - 최근 활동 여부 확인 테스트
func (suite *MinimalProfileTestSuite) TestRecentActivityCheck() {
	user := suite.CreateTestUser("activity@example.com", "activityuser", "활동테스트")
	
	// Case 1: 최근 활동 없음 (LastActivityAt이 nil)
	assert.False(suite.T(), user.Profile.IsRecentlyActive(), "LastActivityAt이 nil일 때 최근 활동 없음으로 판단해야 합니다")
	
	// Case 2: 7일 이내 활동
	recent := time.Now().Add(-3 * 24 * time.Hour) // 3일 전
	user.Profile.LastActivityAt = &recent
	assert.True(suite.T(), user.Profile.IsRecentlyActive(), "3일 전 활동은 최근 활동으로 판단해야 합니다")
	
	// Case 3: 7일 이전 활동
	old := time.Now().Add(-10 * 24 * time.Hour) // 10일 전
	user.Profile.LastActivityAt = &old
	assert.False(suite.T(), user.Profile.IsRecentlyActive(), "10일 전 활동은 최근 활동이 아닙니다")
}

// TestMannerTemperatureBounds - 매너온도 범위 제한 테스트
func (suite *MinimalProfileTestSuite) TestMannerTemperatureBounds() {
	user := suite.CreateTestUser("bounds@example.com", "boundsuser", "범위테스트")
	
	// Case 1: 최대값 제한 (50.0도)
	user.Profile.SignalCount = 1000 // 매우 많은 활동
	user.Profile.JoinCount = 1000
	user.Profile.TotalRatings = 500
	user.Profile.UpdateCompletionRate()
	user.Profile.UpdateMannerTemperature()
	
	assert.LessOrEqual(suite.T(), user.Profile.MannerTemperature, 50.0, "매너온도는 50.0도를 초과할 수 없습니다")
	
	// Case 2: 최소값 제한 (20.0도)
	user.Profile.SignalCount = 0
	user.Profile.JoinCount = 0
	user.Profile.NoShowCount = 1000 // 매우 많은 노쇼
	user.Profile.TotalRatings = 0
	user.Profile.UpdateCompletionRate()
	user.Profile.UpdateMannerTemperature()
	
	assert.GreaterOrEqual(suite.T(), user.Profile.MannerTemperature, 20.0, "매너온도는 20.0도 미만으로 떨어질 수 없습니다")
}

// TestProfileValidation - 프로필 데이터 유효성 검증 테스트
func (suite *MinimalProfileTestSuite) TestProfileValidation() {
	user := suite.CreateTestUser("validation@example.com", "validuser", "검증유저")
	token := suite.GenerateJWTToken(user)
	
	// Case 1: DisplayName 길이 초과
	invalidData := map[string]interface{}{
		"display_name": "이것은매우긴닉네임입니다아마도삼십자가넘을것같은데확인해보겠습니다", // 30자 초과
	}
	
	body, _ := json.Marshal(invalidData)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/quick-setup", bytes.NewBuffer(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	
	w := httptest.NewRecorder()
	suite.router.ServeHTTP(w, req)
	
	assert.Equal(suite.T(), http.StatusBadRequest, w.Code, "30자 초과 닉네임은 거부되어야 합니다")
	
	// Case 2: OneLine 길이 초과
	invalidData2 := map[string]interface{}{
		"display_name": "올바른닉네임",
		"one_line":     "이것은매우긴한줄소개입니다정말로오십자를넘어갈것같은데확인해보겠습니다아마도거부될것입니다", // 50자 초과
	}
	
	body2, _ := json.Marshal(invalidData2)
	req2 := httptest.NewRequest(http.MethodPost, "/api/v1/users/quick-setup", bytes.NewBuffer(body2))
	req2.Header.Set("Authorization", "Bearer "+token)
	req2.Header.Set("Content-Type", "application/json")
	
	w2 := httptest.NewRecorder()
	suite.router.ServeHTTP(w2, req2)
	
	assert.Equal(suite.T(), http.StatusBadRequest, w2.Code, "50자 초과 한줄소개는 거부되어야 합니다")
}

// TestMinimalProfilePerformance - 최소 프로필 성능 테스트
func (suite *MinimalProfileTestSuite) TestMinimalProfilePerformance() {
	// Given: 1000명의 사용자 생성
	users := make([]*models.User, 1000)
	for i := 0; i < 1000; i++ {
		users[i] = suite.CreateTestUser(
			fmt.Sprintf("perf%d@example.com", i),
			fmt.Sprintf("perfuser%d", i),
			fmt.Sprintf("성능테스트%d", i),
		)
		// 다양한 활동 데이터 추가
		users[i].Profile.SignalCount = i % 10
		users[i].Profile.JoinCount = i % 15
		users[i].Profile.NoShowCount = i % 5
		users[i].Profile.UpdateMannerTemperature()
		suite.db.Save(&users[i].Profile)
	}
	
	// When: 매너온도 기준 상위 10명 조회 (성능 측정)
	start := time.Now()
	
	var topUsers []models.UserProfile
	suite.db.Order("manner_temperature DESC").Limit(10).Find(&topUsers)
	
	elapsed := time.Since(start)
	
	// Then: 100ms 이내 응답 확인
	assert.Less(suite.T(), elapsed, 100*time.Millisecond, "1000명 중 상위 10명 조회는 100ms 이내에 완료되어야 합니다")
	assert.Equal(suite.T(), 10, len(topUsers), "정확히 10명이 반환되어야 합니다")
	
	// 매너온도 내림차순 정렬 확인
	for i := 1; i < len(topUsers); i++ {
		assert.GreaterOrEqual(suite.T(), topUsers[i-1].MannerTemperature, topUsers[i].MannerTemperature,
			"매너온도가 내림차순으로 정렬되어야 합니다")
	}
}

func TestMinimalProfileSuite(t *testing.T) {
	suite.Run(t, new(MinimalProfileTestSuite))
}