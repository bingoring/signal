# Signal 서비스 기술적 구현 로드맵

## 📊 현재 개발 현황

### ✅ 완료된 구성요소

#### Backend Infrastructure
- [x] **모노레포 구조**: Go 기반 마이크로서비스 아키텍처
- [x] **데이터베이스**: PostgreSQL + PostGIS (지리적 쿼리 지원)
- [x] **캐싱**: Redis (세션, 실시간 데이터)
- [x] **큐 시스템**: Redis 기반 백그라운드 작업 처리
- [x] **인증 시스템**: JWT + Google OAuth 2.0
- [x] **API 구조**: RESTful API + Gin 프레임워크

#### Core Models & Services
- [x] **사용자 관리**: 회원가입, 프로필, 위치 정보
- [x] **시그널 관리**: CRUD, 참여자 관리 기본 구조
- [x] **채팅 시스템**: 기본 메시지 모델 및 저장소
- [x] **Worker/Scheduler**: 백그라운드 작업 처리 구조

#### Mobile Applications
- [x] **Flutter (iOS)**: 기본 네비게이션, 로그인 화면, OAuth 연동
- [x] **Android (Kotlin)**: Jetpack Compose 기반 UI, OAuth 연동
- [x] **공통 기능**: 위치 권한, 네트워킹 설정

---

## 🚧 다음 우선순위 개발 항목

### Phase 1: MVP 핵심 기능 (4주)

#### 1주차: 실시간 지도 및 시그널 표시
```
Backend:
- 시그널 지리적 검색 API 구현
- 실시간 시그널 상태 변경 WebSocket
- Redis 기반 지리적 캐싱

Frontend:
- Google Maps 통합 (Flutter/Android)
- 실시간 시그널 마커 표시
- 카테고리별 필터링 UI
```

**주요 구현 사항:**
```go
// Backend - 지리적 검색 API
func (s *SignalService) GetNearbySignals(lat, lon float64, radius float64, categories []string) ([]Signal, error) {
    query := `
        SELECT s.*, u.username, u.manner_score,
               ST_Distance(s.location::geography, ST_Point(?, ?)::geography) as distance
        FROM signals s
        JOIN users u ON s.user_id = u.id  
        WHERE ST_DWithin(s.location::geography, ST_Point(?, ?)::geography, ?)
          AND s.status = 'active'
          AND s.start_time > NOW()
          AND s.start_time < NOW() + INTERVAL '24 hours'
        ORDER BY distance ASC
    `
    // Implementation...
}
```

#### 2주차: 푸시 알림 시스템
```
Backend:
- FCM/APNS 통합
- 시그널 매칭 알고리즘 구현
- 사용자 관심사 기반 타겟팅

Mobile:
- 푸시 알림 권한 요청
- 알림 설정 UI
- 딥링크 처리
```

**매칭 알고리즘 구현:**
```go
type MatchingCriteria struct {
    Location      Point     `json:"location"`
    Radius        float64   `json:"radius"`
    Categories    []string  `json:"categories"`
    MinMannerScore float64  `json:"min_manner_score"`
    AgeRange      AgeRange  `json:"age_range,omitempty"`
    GenderFilter  string    `json:"gender_filter,omitempty"`
}

func (s *SignalService) FindMatchingUsers(signalID uint, criteria MatchingCriteria) ([]User, error) {
    // 1. 지리적 필터링
    // 2. 관심사 매칭
    // 3. 매너 점수 필터링
    // 4. 최근 활동 사용자 우선
}
```

#### 3주차: WebSocket 실시간 채팅
```
Backend:
- WebSocket 연결 관리
- 채팅방 자동 생성/소멸
- 메시지 실시간 브로드캐스팅

Frontend:
- WebSocket 클라이언트 구현
- 채팅 UI 컴포넌트
- 파일/이미지 전송
```

**WebSocket 구현:**
```go
type ChatHub struct {
    clients    map[*Client]bool
    broadcast  chan []byte
    register   chan *Client
    unregister chan *Client
    rooms      map[string]map[*Client]bool
}

type Message struct {
    ID        uint      `json:"id"`
    RoomID    string    `json:"room_id"`
    UserID    uint      `json:"user_id"`
    Content   string    `json:"content"`
    Type      string    `json:"type"` // text, image, location
    Timestamp time.Time `json:"timestamp"`
}
```

#### 4주차: 매너 점수 시스템
```
Backend:
- 평가 시스템 구현
- 자동 점수 계산
- 제재 시스템

Frontend:
- 평가 UI
- 매너 점수 표시
- 신고 기능
```

### Phase 2: 고급 기능 (6주)

#### 5-6주차: 이미지 및 파일 처리
```
Backend:
- AWS S3/CloudFlare R2 연동
- 이미지 리사이징 및 최적화
- 프로필 사진 AI 검증

Frontend:
- 이미지 선택/촬영 UI
- 압축 및 업로드 진행률
- 이미지 뷰어
```

#### 7-8주차: 고급 검색 및 필터링
```
Backend:
- ElasticSearch 연동 (선택사항)
- 복합 필터 쿼리 최적화
- 개인화 추천 알고리즘

Frontend:
- 고급 필터 UI
- 검색 기록 및 즐겨찾기
- 추천 시그널 섹션
```

#### 9-10주차: 단골 시스템 구현
```
Backend:
- 단골 관계 모델링
- 프라이빗 시그널 로직
- 단골 자동 만료 스케줄러

Frontend:
- 단골 관리 UI
- 프라이빗 시그널 생성
- 단골 현황 대시보드
```

### Phase 3: 최적화 및 안정성 (4주)

#### 11-12주차: 성능 최적화
```
- 데이터베이스 쿼리 최적화
- Redis 캐싱 전략 개선  
- CDN 및 정적 자원 최적화
- 모바일 앱 메모리 최적화
```

#### 13-14주차: 보안 강화 및 테스트
```
- 보안 취약점 점검
- API Rate Limiting
- 통합 테스트 작성
- 부하 테스트 및 스트레스 테스트
```

---

## 🏗️ 세부 기술 구현 명세

### Database Schema Extensions

#### 1. 시그널 테이블 확장
```sql
ALTER TABLE signals ADD COLUMN location GEOMETRY(POINT, 4326);
ALTER TABLE signals ADD COLUMN search_radius INTEGER DEFAULT 5000;
ALTER TABLE signals ADD COLUMN auto_accept BOOLEAN DEFAULT false;
ALTER TABLE signals ADD COLUMN is_private BOOLEAN DEFAULT false;

CREATE INDEX idx_signals_location ON signals USING GIST (location);
CREATE INDEX idx_signals_start_time ON signals (start_time);
CREATE INDEX idx_signals_category ON signals (category);
```

#### 2. 단골 관계 테이블
```sql
CREATE TABLE user_buddies (
    id SERIAL PRIMARY KEY,
    user1_id INTEGER REFERENCES users(id),
    user2_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    last_interaction TIMESTAMP DEFAULT NOW(),
    interaction_count INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active',
    UNIQUE(user1_id, user2_id)
);

CREATE INDEX idx_user_buddies_user1 ON user_buddies (user1_id);
CREATE INDEX idx_user_buddies_user2 ON user_buddies (user2_id);
```

#### 3. 매너 점수 이력 테이블
```sql
CREATE TABLE manner_score_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    evaluator_id INTEGER REFERENCES users(id),
    signal_id INTEGER REFERENCES signals(id),
    score_change DECIMAL(3,1),
    reason VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);
```

### API Endpoints Specification

#### 시그널 관련 API
```
POST   /api/v1/signals                    # 시그널 생성
GET    /api/v1/signals/nearby             # 주변 시그널 조회
POST   /api/v1/signals/:id/join           # 참여 요청
PUT    /api/v1/signals/:id/approve/:uid   # 참여 승인
DELETE /api/v1/signals/:id                # 시그널 취소

# 지리적 검색
GET /api/v1/signals/nearby?lat={lat}&lon={lon}&radius={radius}&categories={cat1,cat2}
```

#### 실시간 WebSocket
```
WS /ws/signals                            # 시그널 상태 실시간 업데이트
WS /ws/chat/:room_id                      # 채팅방 실시간 메시지
```

#### 단골 시스템 API
```
POST   /api/v1/buddies/request/:user_id   # 단골 요청
GET    /api/v1/buddies                    # 내 단골 목록
POST   /api/v1/signals/private            # 프라이빗 시그널 생성
DELETE /api/v1/buddies/:user_id           # 단골 해제
```

### Mobile App Architecture

#### Flutter (iOS) 구조
```
lib/
├── core/
│   ├── constants/
│   ├── error/
│   ├── network/
│   ├── utils/
│   └── location/
├── features/
│   ├── auth/
│   ├── signal/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── chat/
│   ├── map/
│   └── profile/
├── shared/
│   ├── widgets/
│   ├── theme/
│   └── services/
└── main.dart
```

#### State Management (BLoC 패턴)
```dart
class SignalBloc extends Bloc<SignalEvent, SignalState> {
  final SignalRepository repository;
  final LocationService locationService;
  final WebSocketService wsService;
  
  SignalBloc({
    required this.repository,
    required this.locationService,
    required this.wsService,
  }) : super(SignalInitial()) {
    on<LoadNearbySignals>(_onLoadNearbySignals);
    on<CreateSignal>(_onCreateSignal);
    on<JoinSignal>(_onJoinSignal);
  }
}
```

### Performance Optimization Strategies

#### 1. 데이터베이스 최적화
```sql
-- 복합 인덱스로 지리적 + 시간 쿼리 최적화
CREATE INDEX idx_signals_location_time ON signals 
USING GIST (location, start_time);

-- 매너 점수별 사용자 조회 최적화
CREATE INDEX idx_users_manner_score ON users (manner_score DESC)
WHERE is_active = true AND is_blocked = false;
```

#### 2. Redis 캐싱 전략
```go
// 활성 시그널 지리적 캐싱
func (s *SignalService) CacheActiveSignals() {
    key := "active_signals:geo"
    signals := s.GetActiveSignals()
    
    for _, signal := range signals {
        redis.GeoAdd(key, &redis.GeoLocation{
            Name:      fmt.Sprintf("signal:%d", signal.ID),
            Longitude: signal.Longitude,
            Latitude:  signal.Latitude,
        })
    }
    redis.Expire(key, 5*time.Minute)
}

// 지리적 범위 내 시그널 빠른 조회
func (s *SignalService) GetNearbySignalsFromCache(lat, lon, radius float64) []Signal {
    key := "active_signals:geo"
    results := redis.GeoRadius(key, lon, lat, &redis.GeoRadiusQuery{
        Radius: radius,
        Unit:   "m",
        Count:  50,
    })
    // Convert results to Signal objects...
}
```

#### 3. 모바일 최적화
```dart
// 지도 성능 최적화
class OptimizedGoogleMap extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      markers: _visibleMarkers, // 화면에 보이는 마커만 표시
      onCameraMove: _onCameraMove,
      onCameraIdle: _loadVisibleSignals, // 카메라 정지 시 신호 로드
    );
  }
  
  void _loadVisibleSignals() {
    final bounds = _controller.getVisibleRegion();
    context.read<SignalBloc>().add(
      LoadSignalsInBounds(bounds)
    );
  }
}
```

---

## 🔧 개발 환경 및 도구

### Development Tools
- **IDE**: VS Code, Android Studio
- **Version Control**: Git + GitHub
- **CI/CD**: GitHub Actions
- **Testing**: Go test, Flutter test, Detox (E2E)

### Infrastructure
- **Cloud Provider**: AWS / Google Cloud
- **Container**: Docker + Docker Compose
- **Monitoring**: Prometheus + Grafana
- **Logging**: ELK Stack
- **Error Tracking**: Sentry

### Third-party Services
- **Maps**: Google Maps API
- **Push Notifications**: Firebase Cloud Messaging
- **Image Storage**: AWS S3 / CloudFlare R2
- **Email/SMS**: SendGrid / Twilio
- **Analytics**: Google Analytics / Mixpanel

---

## 📋 다음 즉시 착수 항목

### 1. 실시간 지도 구현 (1주)
```bash
# Backend 작업
cd be/internal/handlers
# signal_handler.go에 지리적 검색 API 추가

cd module/pkg/models  
# signal.go에 PostGIS 지원 필드 추가

# Frontend 작업 (Flutter)
cd ios
flutter pub add google_maps_flutter
flutter pub add geolocator

# Frontend 작업 (Android)
cd android
# build.gradle에 Google Maps 의존성 추가
```

### 2. 푸시 알림 기초 설정 (3일)
```bash
# Firebase 프로젝트 생성
# FCM 서버 키 발급
# iOS/Android 앱에 Firebase SDK 추가
```

### 3. WebSocket 채팅 기반 구조 (1주)
```bash
cd be/internal/services
# websocket_service.go 채팅 허브 구현

cd worker/internal/services  
# chat_cleanup_service.go 자동 소멸 로직 추가
```

이 로드맵을 따라 단계별로 개발하면 약 14주 후에 완전한 Signal 서비스 MVP를 출시할 수 있습니다!