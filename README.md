# Signal - 실시간 취미 연결 플랫폼

"지금, 여기서, 우리" - 내 주변에서 지금 당장 나와 같은 것을 하고 싶은 사람을 찾아주는 실시간 취미 연결 플랫폼

## 🏗️ 아키텍처

```
signal/
├── be/          # Backend API Server (Go + Gin)
├── worker/      # Background Worker (Go) 
├── scheduler/   # Task Scheduler (Go)
├── module/      # 공통 모듈 (Go)
├── ios/         # iOS 앱 (Flutter)
├── android/     # Android 앱 (Kotlin + Jetpack Compose)
├── docker-compose.yml
└── Makefile
```

## 🌟 핵심 기능

### 📱 모바일 앱
1. **시그널 보내기**: 24시간 이내 즉흥 모임 생성
2. **실시간 지도**: 주변 활성 시그널들을 지도에서 확인
3. **푸시 알림**: 관심사 기반 실시간 매칭 알림
4. **임시 채팅방**: 모임 성사 시 자동 생성, 24시간 후 자동 소멸
5. **매너 평가**: 상호 평가를 통한 신뢰도 시스템

### 🔧 백엔드 서비스
- **API Server**: REST API, WebSocket 실시간 통신
- **Worker**: 푸시 알림, 이메일 발송, 채팅방 정리
- **Scheduler**: 시그널 만료, 매칭 관리, 점수 계산
- **Module**: 공통 기능(데이터베이스, Redis, 큐 시스템)

## 🛠️ 기술 스택

### Backend
- **Language**: Go 1.21
- **Framework**: Gin (REST API)
- **Database**: PostgreSQL + PostGIS
- **Cache**: Redis
- **Queue**: Redis 기반 작업 큐
- **Architecture**: Clean Architecture + CQRS

### Mobile
- **iOS**: Flutter (Cross-platform)
- **Android**: Kotlin + Jetpack Compose
- **State Management**: BLoC (Flutter), Hilt + ViewModel (Android)
- **Maps**: Google Maps
- **Push**: Firebase Cloud Messaging

### Infrastructure
- **Containers**: Docker + Docker Compose
- **Database**: PostgreSQL 15 + PostGIS (지리적 검색)
- **Cache**: Redis 7 (실시간 데이터, 큐)

## 🚀 개발 환경 설정

### 전체 서비스 실행
```bash
# 환경 설정
make setup

# 개발 환경 실행
make dev

# 테스트 실행
make test

# 린터 실행
make lint
```

### 개별 서비스 실행

#### Backend API
```bash
cd be
go run cmd/server/main.go
```

#### Worker
```bash
cd worker
go run cmd/worker/main.go
```

#### Scheduler
```bash
cd scheduler
go run cmd/scheduler/main.go
```

#### iOS 앱 (Flutter)
```bash
cd ios
flutter run -d ios
```

#### Android 앱 (Kotlin)
```bash
cd android
./gradlew installDebug
```

## 🗃️ 데이터베이스 설계

### 핵심 테이블
- **users**: 사용자 정보
- **user_profiles**: 프로필, 매너점수
- **user_locations**: 사용자 위치 (PostGIS)
- **signals**: 시그널 정보
- **signal_participants**: 참여자 관리
- **chat_rooms**: 채팅방
- **chat_messages**: 채팅 메시지
- **user_ratings**: 사용자 평가

### 지리적 검색
- PostGIS 확장을 사용한 위치 기반 검색
- 반경 검색, 거리 계산
- Redis GEO 명령어로 실시간 위치 캐싱

## 📊 시스템 플로우

### 1. 시그널 생성 → 알림
```
사용자가 시그널 생성 → 주변 사용자들에게 푸시 알림 → 참여 요청 → 승인/거부
```

### 2. 채팅방 생성 → 자동 소멸
```
정원 달성 → 채팅방 자동 생성 → 24시간 후 자동 소멸 스케줄링 → 데이터 정리
```

### 3. 매너 점수 시스템
```
모임 후 상호 평가 → 점수 계산 → 노쇼 패널티 → 신뢰도 반영
```

## 🔐 보안 및 인증

- **JWT**: Access Token (1시간) + Refresh Token (7일)
- **위치 권한**: 필수 권한, 사용자 동의 기반
- **데이터 보호**: 채팅방 24시간 자동 소멸
- **신고 시스템**: 부적절한 사용자 신고 및 관리

## 📈 주요 API 엔드포인트

```
# 인증
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh

# 시그널
POST /api/v1/signals          # 시그널 생성
GET  /api/v1/signals          # 시그널 검색
POST /api/v1/signals/:id/join # 시그널 참여

# 채팅
GET  /api/v1/chat/rooms               # 채팅방 목록
GET  /api/v1/chat/rooms/:id/messages  # 메시지 조회
POST /api/v1/chat/rooms/:id/messages  # 메시지 전송
GET  /api/v1/chat/ws/:room_id         # WebSocket 연결
```

## 🧪 테스트

```bash
# 모든 서비스 테스트
make test

# 개별 서비스 테스트
cd be && go test ./...
cd worker && go test ./...
cd scheduler && go test ./...
```

## 📱 모바일 앱 특징

### Flutter (iOS)
- **상태 관리**: BLoC 패턴
- **네비게이션**: GoRouter
- **지도**: Google Maps Flutter
- **실시간 통신**: WebSocket

### Kotlin (Android)  
- **UI**: Jetpack Compose
- **아키텍처**: MVVM + Clean Architecture
- **DI**: Hilt
- **네트워킹**: Retrofit + OkHttp

## 🐳 Docker 배포

```bash
# 프로덕션 빌드
docker-compose build

# 서비스 실행
docker-compose up -d

# 로그 확인
docker-compose logs -f
```

## 📋 개발 상태

✅ **완료된 기능**
- [x] 모노레포 구조 설계
- [x] 공통 모듈 (데이터베이스, Redis, 큐)
- [x] Backend API (인증, 시그널, 채팅)
- [x] Worker 서비스 (푸시 알림, 채팅방 정리)
- [x] Scheduler 서비스 (만료 처리, 점수 계산)
- [x] Flutter iOS 앱 기본 구조
- [x] Kotlin Android 앱 기본 구조

🚧 **개발 예정**
- [ ] 실제 푸시 알림 연동 (FCM/APNS)
- [ ] 실시간 채팅 구현 (WebSocket)
- [ ] 지도 기반 UI 완성
- [ ] 이미지 업로드 기능
- [ ] 소셜 로그인 (Google, Apple)

## 💡 핵심 차별점

1. **극단적 실시간성**: 24시간 이내 약속만 생성 가능
2. **자동 소멸 채팅방**: 관계의 부담 없이 깔끔한 마무리
3. **위치 기반 매칭**: PostGIS를 활용한 정확한 거리 계산
4. **신뢰도 시스템**: 매너 평가로 건전한 커뮤니티 유지

---

**개발**: Blueprint 구조를 참고하되, 더 체계적이고 확장 가능한 아키텍처로 구현
**목표**: 계획의 부담 없이 원할 때 바로 즐기는 가벼운 소셜 라이프