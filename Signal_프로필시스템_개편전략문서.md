# Signal 프로필 시스템 개편 전략 문서

## 📋 문서 개요

**문서명**: Signal 애플리케이션 프로필 시스템 전면 개편 전략  
**작성일**: 2025년 1월  
**버전**: 1.0  
**담당**: 제품 전략팀, 개발팀  

---

## 🎯 전략적 비전

### 핵심 철학
**"가벼운 신뢰 기반 연결(Lightweight Trust-Based Connections)"**

Signal은 복잡한 프로필 정보나 매칭 알고리즘이 아닌, **최소한의 정보와 실제 활동 기반의 신뢰**를 통해 의미 있는 만남을 연결하는 플랫폼으로 진화합니다.

### 차별화 전략
- **최소주의 접근**: 불필요한 프로필 정보 제거, 핵심 요소에만 집중
- **활동 중심**: 프로필 완성도보다 실제 Signal 참여 이력 중시
- **신뢰 기반**: 매너 점수와 참여 히스토리를 통한 자연스러운 신뢰 구축
- **즉시성**: 복잡한 설정 없이 빠른 시작이 가능한 사용자 경험

---

## 📊 현재 상태 분석

### 기존 프로필 시스템 문제점

#### 1. 데이터 구조적 문제
```go
type UserProfile struct {
    DisplayName string    // 필수
    Avatar      string    // 선택
    Bio         string    // 선택 (500자)
    Age         int       // 선택
    Gender      string    // 선택
    
    // 신뢰도 관련 (현재 잘 활용되지 않음)
    MannerScore      float64  // 36.5 기본값
    TotalRatings     int      // 0 기본값
    CompletedSignals int      // 0 기본값
    NoShowCount      int      // 0 기본값
    
    // 설정 (복잡함)
    PushNotifications bool
    LocationSharing   bool
    ProfilePublic     bool
}
```

**문제 분석**:
- 사용자가 채워야 할 정보가 너무 많음
- Bio 500자는 과도하게 긴 자기소개 유도
- 나이, 성별 등 민감 정보 요구로 진입 장벽 높음
- 신뢰도 관련 데이터가 있지만 제대로 활용되지 않음

#### 2. 사용자 경험 문제
- **높은 온보딩 장벽**: 프로필 완성을 위한 과도한 정보 입력 요구
- **정보 과부하**: 실제로는 사용되지 않는 정보들이 많음
- **신뢰 부족**: 프로필 정보로는 실제 신뢰성을 판단하기 어려움
- **복잡한 설정**: 너무 많은 개인정보 설정 옵션

#### 3. 기술적 부채
- 복잡한 프로필 업데이트 로직
- 불필요한 데이터베이스 필드들
- 관심사 관리의 복잡성 (최대 10개 제한)

---

## 🎯 새로운 프로필 시스템 설계

### 핵심 원칙

1. **최소한의 정보만 수집**: 닉네임 + 매너온도 중심
2. **활동으로 신뢰 구축**: 프로필보다 실제 참여 이력이 중요
3. **점진적 정보 공개**: 필요에 따라 추가 정보 선택적 공유
4. **즉시 시작 가능**: 복잡한 프로필 설정 없이 바로 이용 가능

### 새로운 데이터 모델

```go
// 간소화된 프로필 구조
type MinimalUserProfile struct {
    ID          uint    `json:"id" gorm:"primaryKey"`
    UserID      uint    `json:"user_id" gorm:"uniqueIndex;not null"`
    DisplayName string  `json:"display_name" gorm:"size:30;not null"` // 기존 100자 → 30자
    
    // 핵심 신뢰 지표 (매너온도)
    MannerTemperature float64 `json:"manner_temperature" gorm:"default:36.5"`
    
    // 활동 기반 지표
    SignalCount       int `json:"signal_count" gorm:"default:0"`        // 생성한 Signal 수
    JoinCount         int `json:"join_count" gorm:"default:0"`          // 참여한 Signal 수
    CompletionRate    float64 `json:"completion_rate" gorm:"default:0"`  // 완료율
    RecentActivity    time.Time `json:"recent_activity"`                 // 최근 활동 시간
    
    // 선택적 정보 (초기에는 비어있음)
    Avatar     *string `json:"avatar,omitempty"`
    StatusEmoji *string `json:"status_emoji,omitempty"`  // 🏃‍♂️, 🎯, 😄 등 간단한 상태표현
    
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

// 제거되는 필드들
// - Bio (500자 자기소개)
// - Age (나이 정보)
// - Gender (성별 정보)  
// - 복잡한 설정들 (PushNotifications, LocationSharing, ProfilePublic)
```

### 매너온도 시스템 재설계

```go
type MannerTemperatureSystem struct {
    // 기본 온도: 36.5°C
    BaseTemperature   float64 // 36.5
    MaxTemperature    float64 // 50.0 (매우 좋음)
    MinTemperature    float64 // 20.0 (매우 나쁨)
    
    // 온도 변화 요인들
    CompletionBonus   float64 // +0.1 (Signal 완료시)
    NoShowPenalty     float64 // -1.0 (노쇼시)
    PositiveRating    float64 // +0.2 (좋은 평가시)
    NegativeRating    float64 // -0.3 (나쁜 평가시)
}

// 온도 계산 로직 (기존보다 단순화)
func (m *MannerTemperatureSystem) CalculateTemperature(
    baseTemp float64,
    completions int,
    noShows int,
    avgRating float64,
    totalRatings int,
) float64 {
    temperature := baseTemp
    
    // Signal 완료 보너스
    temperature += float64(completions) * m.CompletionBonus
    
    // 노쇼 페널티
    temperature -= float64(noShows) * m.NoShowPenalty
    
    // 평가 반영 (5점 만점을 온도로 변환)
    if totalRatings > 0 {
        ratingImpact := (avgRating - 3.0) * 2.0 // 3점 기준으로 -4~+4도 범위
        temperature += ratingImpact
    }
    
    // 최대/최소 온도 제한
    if temperature > m.MaxTemperature {
        temperature = m.MaxTemperature
    } else if temperature < m.MinTemperature {
        temperature = m.MinTemperature
    }
    
    return math.Round(temperature*10) / 10 // 소수점 첫째자리까지
}
```

---

## 📅 3단계 구현 로드맵

### Phase 1: 기반 구조 마이그레이션 (4주)

**목표**: 기존 프로필 데이터를 새로운 최소화된 구조로 마이그레이션

#### 1주차: 데이터베이스 스키마 업데이트
```sql
-- 새로운 테이블 구조
CREATE TABLE minimal_user_profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL,
    display_name VARCHAR(30) NOT NULL,
    manner_temperature DECIMAL(4,1) DEFAULT 36.5,
    signal_count INTEGER DEFAULT 0,
    join_count INTEGER DEFAULT 0,
    completion_rate DECIMAL(5,2) DEFAULT 0.00,
    recent_activity TIMESTAMP,
    avatar TEXT,
    status_emoji VARCHAR(10),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 기존 데이터 마이그레이션 스크립트
INSERT INTO minimal_user_profiles (
    user_id, display_name, manner_temperature, 
    signal_count, join_count, completion_rate, avatar
)
SELECT 
    up.user_id,
    SUBSTR(up.display_name, 1, 30) as display_name,
    up.manner_score as manner_temperature,
    up.completed_signals as signal_count,
    0 as join_count, -- 새로 계산 필요
    CASE 
        WHEN up.completed_signals + up.no_show_count > 0 
        THEN (up.completed_signals * 100.0 / (up.completed_signals + up.no_show_count))
        ELSE 0 
    END as completion_rate,
    up.avatar
FROM user_profiles up;
```

#### 2주차: 백엔드 API 업데이트
```go
// 새로운 서비스 로직
func (s *UserService) GetMinimalProfile(userID uint) (*models.MinimalUserProfile, error) {
    profile, err := s.userRepo.GetMinimalProfile(userID)
    if err != nil {
        return nil, err
    }
    
    // 실시간 활동 점수 계산
    profile.CompletionRate = s.calculateCompletionRate(userID)
    profile.RecentActivity = s.getLastActivity(userID)
    
    return profile, nil
}

func (s *UserService) UpdateMinimalProfile(userID uint, req *models.UpdateMinimalProfileRequest) error {
    // 검증 로직 (매우 단순화)
    if len(req.DisplayName) < 2 || len(req.DisplayName) > 30 {
        return fmt.Errorf("닉네임은 2-30자여야 합니다")
    }
    
    profile := &models.MinimalUserProfile{
        UserID:      userID,
        DisplayName: req.DisplayName,
        StatusEmoji: req.StatusEmoji,
    }
    
    return s.userRepo.UpdateMinimalProfile(profile)
}
```

#### 3-4주차: 프론트엔드 UI 업데이트
```dart
// Flutter - 새로운 프로필 위젯
class MinimalProfileCard extends StatelessWidget {
  final MinimalUserProfile profile;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 아바타 (선택사항)
                if (profile.avatar != null)
                  CircleAvatar(backgroundImage: NetworkImage(profile.avatar!))
                else
                  CircleAvatar(child: Text(profile.displayName[0])),
                  
                SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(profile.displayName, 
                               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (profile.statusEmoji != null) ...[
                            SizedBox(width: 8),
                            Text(profile.statusEmoji!, style: TextStyle(fontSize: 16)),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      _buildTemperatureIndicator(profile.mannerTemperature),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // 활동 지표 (간단하게)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("생성", profile.signalCount.toString()),
                _buildStatItem("참여", profile.joinCount.toString()),
                _buildStatItem("완료율", "${profile.completionRate.toStringAsFixed(0)}%"),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTemperatureIndicator(double temperature) {
    Color tempColor = _getTemperatureColor(temperature);
    return Row(
      children: [
        Icon(Icons.thermostat, color: tempColor, size: 16),
        Text("${temperature}°C", 
             style: TextStyle(color: tempColor, fontWeight: FontWeight.w600)),
      ],
    );
  }
  
  Color _getTemperatureColor(double temp) {
    if (temp >= 40) return Colors.green;
    if (temp >= 37) return Colors.blue;
    if (temp >= 30) return Colors.orange;
    return Colors.red;
  }
}
```

### Phase 2: 스마트 매칭 시스템 (3주)

**목표**: 프로필 정보 대신 활동 패턴과 매너온도 기반 매칭 시스템 구현

#### 5주차: 매칭 알고리즘 개발
```go
type SmartMatchingService struct {
    userRepo    repositories.UserRepositoryInterface
    signalRepo  repositories.SignalRepositoryInterface
}

func (s *SmartMatchingService) FindCompatibleUsers(signal *models.Signal, requesterID uint) ([]models.User, error) {
    baseQuery := s.userRepo.GetDB().
        Table("users u").
        Joins("JOIN minimal_user_profiles mup ON u.id = mup.user_id").
        Where("u.id != ? AND u.is_active = true AND u.is_blocked = false", requesterID)
    
    // 매너온도 필터링 (최소 32도 이상)
    baseQuery = baseQuery.Where("mup.manner_temperature >= ?", 32.0)
    
    // 활동 점수 기반 우선순위 (최근 7일 내 활동한 사용자 우선)
    baseQuery = baseQuery.Where("mup.recent_activity >= ?", time.Now().AddDate(0, 0, -7))
    
    // 완료율이 70% 이상인 사용자 우선
    baseQuery = baseQuery.Where("mup.completion_rate >= ?", 70.0)
    
    // 관심사 매칭 (기존과 동일하지만 가중치 조정)
    if signal.Category != "" {
        baseQuery = baseQuery.
            Joins("JOIN user_interests ui ON u.id = ui.user_id").
            Where("ui.category = ?", signal.Category)
    }
    
    // 지리적 근접성 (기존 10km → 5km로 축소)
    baseQuery = baseQuery.Where(`
        ST_DWithin(
            ST_SetSRID(ST_MakePoint(ul.longitude, ul.latitude), 4326)::geography,
            ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
            5000
        )
    `, signal.Longitude, signal.Latitude)
    
    // 정렬: 매너온도 + 완료율 + 최근활동 순
    baseQuery = baseQuery.
        Order("(mup.manner_temperature * 0.4 + mup.completion_rate * 0.4 + CASE WHEN mup.recent_activity >= NOW() - INTERVAL '24 hours' THEN 20 ELSE 0 END) DESC").
        Limit(20) // 기존 50명 → 20명으로 축소
    
    var users []models.User
    err := baseQuery.Find(&users).Error
    return users, err
}
```

#### 6-7주차: A/B 테스트 시스템
```go
type ABTestService struct {
    variants map[string]MatchingVariant
}

type MatchingVariant struct {
    Name                string
    TemperatureWeight   float64
    CompletionWeight    float64
    RecentActivityWeight float64
    MinTemperature      float64
    MaxDistance         float64
    MaxResults          int
}

func (s *ABTestService) GetVariantForUser(userID uint) MatchingVariant {
    // 사용자 ID 기반 일관된 변형 할당
    variants := []MatchingVariant{
        {
            Name: "strict_trust", // 엄격한 신뢰 기반
            TemperatureWeight: 0.5,
            CompletionWeight: 0.4,
            MinTemperature: 35.0,
            MaxDistance: 3000,
            MaxResults: 10,
        },
        {
            Name: "activity_focused", // 활동 중심
            TemperatureWeight: 0.3,
            CompletionWeight: 0.3,
            RecentActivityWeight: 0.4,
            MinTemperature: 30.0,
            MaxDistance: 7000,
            MaxResults: 15,
        },
        {
            Name: "balanced", // 균형잡힌 접근
            TemperatureWeight: 0.4,
            CompletionWeight: 0.4,
            RecentActivityWeight: 0.2,
            MinTemperature: 32.0,
            MaxDistance: 5000,
            MaxResults: 20,
        },
    }
    
    return variants[userID % uint(len(variants))]
}
```

### Phase 3: 고도화 및 최적화 (3주)

**목표**: 사용자 피드백 반영 및 성능 최적화

#### 8주차: 실시간 피드백 시스템
```go
type ProfileFeedbackService struct {
    redisClient *redis.Client
    dbRepo      repositories.UserRepositoryInterface
}

// 실시간 매너온도 업데이트
func (s *ProfileFeedbackService) UpdateTemperatureRealTime(userID uint, event string, impact float64) error {
    // Redis에서 현재 온도 조회
    currentTemp, err := s.redisClient.Get(fmt.Sprintf("temp:%d", userID)).Float64()
    if err != nil {
        // DB에서 조회
        profile, err := s.dbRepo.GetMinimalProfile(userID)
        if err != nil {
            return err
        }
        currentTemp = profile.MannerTemperature
    }
    
    // 새 온도 계산
    newTemp := s.calculateNewTemperature(currentTemp, event, impact)
    
    // Redis에 즉시 업데이트
    s.redisClient.Set(fmt.Sprintf("temp:%d", userID), newTemp, time.Hour*24)
    
    // 비동기적으로 DB 업데이트
    go s.updateDBAsync(userID, newTemp)
    
    return nil
}

// 이벤트별 온도 변화
var temperatureEvents = map[string]float64{
    "signal_completed": +0.1,
    "signal_no_show":   -1.0,
    "positive_rating":  +0.2,
    "negative_rating":  -0.3,
    "report_resolved":  -2.0,
    "first_week_bonus": +0.5, // 신규 사용자 보너스
}
```

#### 9-10주차: 성능 최적화 및 모니터링
```go
// 캐싱 전략
type ProfileCacheService struct {
    redisClient  *redis.Client
    profileRepo  repositories.UserRepositoryInterface
}

func (s *ProfileCacheService) GetCachedProfile(userID uint) (*models.MinimalUserProfile, error) {
    // L1: Redis 캐시 확인
    cached, err := s.redisClient.Get(fmt.Sprintf("profile:%d", userID)).Result()
    if err == nil {
        var profile models.MinimalUserProfile
        json.Unmarshal([]byte(cached), &profile)
        return &profile, nil
    }
    
    // L2: 데이터베이스 조회
    profile, err := s.profileRepo.GetMinimalProfile(userID)
    if err != nil {
        return nil, err
    }
    
    // 캐시에 저장 (TTL: 1시간)
    profileJSON, _ := json.Marshal(profile)
    s.redisClient.Set(fmt.Sprintf("profile:%d", userID), profileJSON, time.Hour)
    
    return profile, nil
}

// 배치 업데이트 (매일 오전 2시)
func (s *ProfileCacheService) BatchUpdateStatistics() error {
    // 모든 사용자의 완료율, 활동 점수 재계산
    users, err := s.profileRepo.GetAllActiveUsers()
    if err != nil {
        return err
    }
    
    for _, user := range users {
        // 병렬 처리로 성능 향상
        go func(u models.User) {
            completionRate := s.calculateCompletionRate(u.ID)
            recentActivity := s.getLastActivity(u.ID)
            
            s.profileRepo.UpdateStatistics(u.ID, completionRate, recentActivity)
            s.invalidateCache(u.ID)
        }(user)
    }
    
    return nil
}
```

---

## 📈 성공 지표 (KPI)

### 1. 사용자 참여 지표
- **프로필 완성 시간**: 현재 평균 15분 → 목표 2분 이하
- **첫 Signal 생성까지 시간**: 현재 평균 3일 → 목표 30분 이하
- **앱 재방문율**: 7일 기준 현재 35% → 목표 50%
- **세션 길이**: 현재 평균 8분 → 목표 12분

### 2. 매칭 품질 지표
- **Signal 완료율**: 현재 45% → 목표 65%
- **사용자 만족도** (5점 척도): 현재 3.2점 → 목표 4.0점 이상
- **노쇼율**: 현재 25% → 목표 15% 이하
- **재참여율**: 현재 60% → 목표 75%

### 3. 신뢰도 지표
- **평균 매너온도**: 목표 37.5도 유지 (건전한 커뮤니티)
- **신고 건수**: 현재 주당 50건 → 목표 30건 이하
- **매너온도 35도 이상 사용자 비율**: 목표 80%

### 4. 기술적 성능 지표
- **프로필 로딩 시간**: 목표 200ms 이하
- **매칭 API 응답시간**: 목표 500ms 이하
- **데이터베이스 쿼리 최적화**: 평균 쿼리 시간 50ms 이하

---

## 🔧 기술적 구현 세부사항

### 데이터베이스 마이그레이션 스크립트

```sql
-- Phase 1: 새 테이블 생성
CREATE TABLE minimal_user_profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(30) NOT NULL,
    manner_temperature DECIMAL(4,1) DEFAULT 36.5 CHECK (manner_temperature BETWEEN 20.0 AND 50.0),
    signal_count INTEGER DEFAULT 0 CHECK (signal_count >= 0),
    join_count INTEGER DEFAULT 0 CHECK (join_count >= 0),
    completion_rate DECIMAL(5,2) DEFAULT 0.00 CHECK (completion_rate BETWEEN 0.00 AND 100.00),
    recent_activity TIMESTAMP DEFAULT NOW(),
    avatar TEXT,
    status_emoji VARCHAR(10),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 인덱스 생성
CREATE INDEX idx_minimal_profiles_user_id ON minimal_user_profiles(user_id);
CREATE INDEX idx_minimal_profiles_temperature ON minimal_user_profiles(manner_temperature);
CREATE INDEX idx_minimal_profiles_activity ON minimal_user_profiles(recent_activity);
CREATE INDEX idx_minimal_profiles_completion ON minimal_user_profiles(completion_rate);

-- 기존 데이터 마이그레이션
INSERT INTO minimal_user_profiles (
    user_id, display_name, manner_temperature, 
    signal_count, completion_rate, avatar, created_at, updated_at
)
SELECT 
    up.user_id,
    SUBSTR(TRIM(up.display_name), 1, 30) as display_name,
    COALESCE(up.manner_score, 36.5) as manner_temperature,
    COALESCE(up.completed_signals, 0) as signal_count,
    CASE 
        WHEN (up.completed_signals + up.no_show_count) > 0 
        THEN (up.completed_signals * 100.0 / (up.completed_signals + up.no_show_count))
        ELSE 0.00 
    END as completion_rate,
    up.avatar,
    up.created_at,
    up.updated_at
FROM user_profiles up
WHERE up.user_id IS NOT NULL;

-- Phase 2: 기존 테이블 백업 및 정리 (롤백 대비)
CREATE TABLE user_profiles_backup AS SELECT * FROM user_profiles;

-- Phase 3: 불필요한 컬럼 제거 (충분한 테스트 후)
-- ALTER TABLE user_profiles DROP COLUMN bio;
-- ALTER TABLE user_profiles DROP COLUMN age;
-- ALTER TABLE user_profiles DROP COLUMN gender;
```

### API 엔드포인트 변경사항

```go
// 기존 API 유지 + 새 API 추가 (하위 호환성)
type UserHandler struct {
    userService    services.UserServiceInterface
    profileService services.MinimalProfileService // 새 서비스
}

// 새로운 간소화된 엔드포인트들
func (h *UserHandler) GetMinimalProfile(c *gin.Context) {
    userID := c.GetUint("user_id")
    
    profile, err := h.profileService.GetMinimalProfile(userID)
    if err != nil {
        utils.NotFoundResponse(c, "프로필을 찾을 수 없습니다")
        return
    }
    
    // 민감한 정보 필터링
    response := models.MinimalProfileResponse{
        DisplayName:       profile.DisplayName,
        MannerTemperature: profile.MannerTemperature,
        ActivityStats: models.ActivityStats{
            SignalCount:    profile.SignalCount,
            JoinCount:      profile.JoinCount,
            CompletionRate: profile.CompletionRate,
        },
        StatusEmoji: profile.StatusEmoji,
        Avatar:      profile.Avatar,
    }
    
    utils.SuccessResponse(c, "프로필 조회 완료", response)
}

func (h *UserHandler) UpdateMinimalProfile(c *gin.Context) {
    userID := c.GetUint("user_id")
    
    var req models.UpdateMinimalProfileRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.BadRequestResponse(c, "잘못된 요청 데이터입니다")
        return
    }
    
    // 간단한 검증
    if err := h.validateMinimalProfileRequest(&req); err != nil {
        utils.BadRequestResponse(c, err.Error())
        return
    }
    
    if err := h.profileService.UpdateMinimalProfile(userID, &req); err != nil {
        utils.InternalServerErrorResponse(c, "프로필 업데이트에 실패했습니다")
        return
    }
    
    utils.SuccessResponse(c, "프로필이 업데이트되었습니다", nil)
}

func (h *UserHandler) validateMinimalProfileRequest(req *models.UpdateMinimalProfileRequest) error {
    if len(req.DisplayName) < 2 || len(req.DisplayName) > 30 {
        return fmt.Errorf("닉네임은 2-30자여야 합니다")
    }
    
    if req.StatusEmoji != nil && len(*req.StatusEmoji) > 10 {
        return fmt.Errorf("상태 이모지가 너무 깁니다")
    }
    
    // 부적절한 닉네임 필터링
    if h.containsInappropriateContent(req.DisplayName) {
        return fmt.Errorf("부적절한 닉네임입니다")
    }
    
    return nil
}
```

### 프론트엔드 상태 관리

```dart
// Flutter - 프로필 상태 관리
class MinimalProfileProvider extends ChangeNotifier {
  MinimalUserProfile? _profile;
  bool _isLoading = false;
  String? _error;
  
  MinimalUserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // 프로필 로드 (캐싱 포함)
  Future<void> loadProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _profile != null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // 로컬 캐시 확인
      final cachedProfile = await _profileCache.get('my_profile');
      if (!forceRefresh && cachedProfile != null) {
        _profile = cachedProfile;
        _isLoading = false;
        notifyListeners();
        
        // 백그라운드에서 최신 데이터 확인
        _refreshProfileInBackground();
        return;
      }
      
      // API에서 최신 데이터 로드
      _profile = await ProfileService.getMinimalProfile();
      
      // 로컬 캐시 업데이트
      await _profileCache.set('my_profile', _profile!, 
                             duration: Duration(minutes: 30));
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 프로필 업데이트 (낙관적 업데이트)
  Future<void> updateProfile(UpdateMinimalProfileRequest request) async {
    if (_profile == null) return;
    
    // 낙관적 업데이트
    final originalProfile = _profile!.copyWith();
    _profile = _profile!.copyWith(
      displayName: request.displayName,
      statusEmoji: request.statusEmoji,
    );
    notifyListeners();
    
    try {
      await ProfileService.updateMinimalProfile(request);
      
      // 캐시 업데이트
      await _profileCache.set('my_profile', _profile!);
      
    } catch (e) {
      // 실패시 원본 복구
      _profile = originalProfile;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  // 매너온도 실시간 업데이트
  void updateTemperatureRealTime(double newTemperature) {
    if (_profile == null) return;
    
    _profile = _profile!.copyWith(mannerTemperature: newTemperature);
    notifyListeners();
    
    // 캐시 즉시 업데이트
    _profileCache.set('my_profile', _profile!);
  }
}

// 온보딩 플로우 간소화
class SimplifiedOnboardingFlow extends StatefulWidget {
  @override
  _SimplifiedOnboardingFlowState createState() => _SimplifiedOnboardingFlowState();
}

class _SimplifiedOnboardingFlowState extends State<SimplifiedOnboardingFlow> {
  final _displayNameController = TextEditingController();
  String? _selectedEmoji;
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('간단한 프로필 설정')),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '어떻게 불러드릴까요?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            
            SizedBox(height: 8),
            
            Text(
              '닉네임만 있으면 바로 시작할 수 있어요!',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            
            SizedBox(height: 32),
            
            // 닉네임 입력
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: '닉네임',
                hintText: '2-30자로 입력해주세요',
                border: OutlineInputBorder(),
                suffixIcon: _displayNameController.text.isNotEmpty 
                    ? Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
              maxLength: 30,
              onChanged: (value) => setState(() {}),
            ),
            
            SizedBox(height: 24),
            
            // 선택적 상태 이모지
            Text('상태 표현 (선택사항)', 
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            
            SizedBox(height: 12),
            
            Wrap(
              spacing: 12,
              children: ['🏃‍♂️', '🎯', '😄', '🤝', '🌟', '☕', '🎵', '📚'].map((emoji) {
                final isSelected = _selectedEmoji == emoji;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedEmoji = isSelected ? null : emoji;
                  }),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(emoji, style: TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            
            Spacer(),
            
            // 완료 버튼
            ElevatedButton(
              onPressed: _canComplete() ? _completeOnboarding : null,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('시작하기', style: TextStyle(fontSize: 18)),
            ),
            
            SizedBox(height: 16),
            
            Text(
              '나머지 설정은 나중에 언제든 변경할 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
  
  bool _canComplete() {
    return _displayNameController.text.length >= 2 && !_isLoading;
  }
  
  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);
    
    try {
      final request = UpdateMinimalProfileRequest(
        displayName: _displayNameController.text.trim(),
        statusEmoji: _selectedEmoji,
      );
      
      await Provider.of<MinimalProfileProvider>(context, listen: false)
          .updateProfile(request);
      
      // 온보딩 완료 표시
      await SharedPreferences.getInstance()
          .then((prefs) => prefs.setBool('onboarding_completed', true));
      
      // 메인 화면으로 이동
      Navigator.of(context).pushReplacementNamed('/main');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 설정에 실패했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
```

---

## ⚠️ 리스크 관리

### 기술적 리스크

1. **데이터 마이그레이션 실패**
   - **완화 방안**: 단계적 마이그레이션, 완전한 백업, 롤백 시나리오 준비
   - **모니터링**: 마이그레이션 진행 상황 실시간 추적
   - **복구 계획**: 1시간 내 이전 상태 복구 가능한 백업 시스템

2. **성능 저하**
   - **완화 방안**: 충분한 로드 테스트, Redis 캐싱, 데이터베이스 인덱스 최적화
   - **모니터링**: APM 도구를 통한 실시간 성능 추적
   - **임계점**: API 응답 시간 1초 초과시 즉시 대응

3. **사용자 데이터 손실**
   - **완화 방안**: 다중 백업, 실시간 복제, 테스트 환경에서 충분한 검증
   - **보험**: 기존 프로필 데이터 6개월간 보관

### 사용자 경험 리스크

1. **사용자 반발**
   - **완화 방안**: 사전 공지, 점진적 롤아웃, A/B 테스트
   - **소통**: 변경 사유와 이익에 대한 명확한 설명
   - **선택권**: 초기에는 기존 프로필 정보 유지 옵션 제공

2. **매칭 품질 저하**
   - **완화 방안**: 다양한 매칭 알고리즘 변형 동시 테스트
   - **피드백**: 사용자 만족도 실시간 수집 및 대응
   - **롤백**: 매칭 성공률 20% 이상 하락시 즉시 이전 버전 복구

### 비즈니스 리스크

1. **사용자 이탈**
   - **완화 방안**: 단계적 출시, 피드백 수렴, 신속한 개선
   - **지표 모니터링**: DAU, 세션 길이, 재방문율 실시간 추적
   - **임계점**: DAU 15% 하락시 전면 재검토

2. **경쟁사 대비 차별화 실패**
   - **완화 방안**: 명확한 USP 설정, 지속적인 사용자 피드백 수렴
   - **모니터링**: 경쟁사 대비 사용자 만족도, 기능 선호도 조사

---

## 📊 모니터링 및 분석

### 실시간 대시보드

```go
// 모니터링 지표 수집
type ProfileMetricsCollector struct {
    prometheus *prometheus.Registry
    redis      *redis.Client
}

// 핵심 지표 정의
var (
    profileUpdateCount = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "profile_updates_total",
            Help: "Total number of profile updates",
        },
        []string{"type", "result"},
    )
    
    temperatureDistribution = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "manner_temperature_distribution",
            Help: "Distribution of manner temperatures",
            Buckets: []float64{20, 25, 30, 32, 35, 37, 40, 45, 50},
        },
        []string{"user_type"},
    )
    
    onboardingTimeMetric = prometheus.NewHistogram(
        prometheus.HistogramOpts{
            Name: "onboarding_completion_seconds",
            Help: "Time taken to complete onboarding",
            Buckets: []float64{30, 60, 120, 300, 600, 1200},
        },
    )
)

func (c *ProfileMetricsCollector) RecordTemperatureUpdate(userID uint, oldTemp, newTemp float64, reason string) {
    temperatureDistribution.WithLabelValues("active").Observe(newTemp)
    
    // 실시간 알림 (극단적 변화시)
    if math.Abs(newTemp - oldTemp) > 5.0 {
        c.sendAlert("extreme_temperature_change", map[string]interface{}{
            "user_id": userID,
            "old_temp": oldTemp,
            "new_temp": newTemp,
            "reason": reason,
        })
    }
}
```

### 사용자 행동 분석

```typescript
// 프론트엔드 분석 코드
interface UserBehaviorEvent {
  event_name: string;
  user_id: string;
  timestamp: number;
  properties: {
    screen: string;
    duration?: number;
    success?: boolean;
    error_message?: string;
  };
}

class ProfileAnalytics {
  // 온보딩 완료 시간 측정
  static trackOnboardingFlow(step: string, duration?: number) {
    const event: UserBehaviorEvent = {
      event_name: 'onboarding_step_completed',
      user_id: UserStore.currentUserId,
      timestamp: Date.now(),
      properties: {
        screen: step,
        duration: duration,
      }
    };
    
    this.sendEvent(event);
  }
  
  // 프로필 업데이트 성공률 추적
  static trackProfileUpdate(type: 'display_name' | 'emoji' | 'avatar', success: boolean, errorMessage?: string) {
    const event: UserBehaviorEvent = {
      event_name: 'profile_update_attempted',
      user_id: UserStore.currentUserId,
      timestamp: Date.now(),
      properties: {
        screen: `profile_${type}`,
        success: success,
        error_message: errorMessage,
      }
    };
    
    this.sendEvent(event);
  }
  
  // 매칭 품질 피드백 수집
  static trackMatchingFeedback(signalId: string, satisfaction: number, reason?: string) {
    const event: UserBehaviorEvent = {
      event_name: 'matching_feedback',
      user_id: UserStore.currentUserId,
      timestamp: Date.now(),
      properties: {
        screen: 'signal_completion',
        satisfaction: satisfaction,
        reason: reason,
      }
    };
    
    this.sendEvent(event);
  }
}
```

---

## 🎯 결론

Signal의 프로필 시스템 개편은 단순한 기능 변경이 아닌, **사용자 중심의 신뢰 기반 플랫폼**으로의 전략적 전환입니다.

### 핵심 성공 요인

1. **사용자 중심 설계**: 복잡한 프로필 대신 실제 활동과 신뢰도 중심
2. **점진적 구현**: 리스크를 최소화하면서 단계적으로 개선
3. **지속적 최적화**: 데이터 기반 의사결정과 사용자 피드백 반영
4. **기술적 안정성**: 충분한 테스트와 모니터링으로 서비스 품질 유지

### 기대 효과

- **사용자 경험 향상**: 온보딩 시간 90% 단축, 첫 Signal 참여율 150% 증가
- **매칭 품질 개선**: Signal 완료율 45% → 65% 향상
- **커뮤니티 건전성**: 매너온도 기반 자연스러운 신뢰 시스템 구축
- **개발 효율성**: 간소화된 시스템으로 유지보수 비용 30% 절감

Signal의 새로운 프로필 시스템은 **"복잡함을 통한 완벽함"**이 아닌 **"단순함을 통한 본질"**을 추구합니다. 사용자들이 프로필 작성에 시간을 소비하는 대신, 실제 사람들과의 의미 있는 연결에 집중할 수 있는 환경을 만드는 것이 우리의 목표입니다.

---

**문서 승인**: 제품 전략팀, 개발팀장, CTO  
**다음 검토일**: 구현 완료 후 1개월 (성과 리뷰)  
**연락처**: product@signal.app

---

*이 문서는 Signal의 전략적 방향성을 제시하는 살아있는 문서입니다. 구현 과정에서의 인사이트와 사용자 피드백을 반영하여 지속적으로 업데이트될 예정입니다.*