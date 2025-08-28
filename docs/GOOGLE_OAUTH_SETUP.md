# Google OAuth 설정 가이드

Signal 서비스에 Google OAuth 인증을 설정하는 방법을 안내합니다.

## 1. Google Cloud Console 설정

1. [Google Cloud Console](https://console.cloud.google.com/)에 접속
2. 새 프로젝트를 생성하거나 기존 프로젝트 선택
3. "API 및 서비스" > "OAuth 동의 화면"으로 이동
4. 애플리케이션 정보 입력:
   - 애플리케이션 이름: Signal
   - 사용자 지원 이메일
   - 개발자 연락처 정보
5. "사용자 인증 정보" > "사용자 인증 정보 만들기" > "OAuth 클라이언트 ID"
6. 애플리케이션 유형: "웹 애플리케이션"
7. 승인된 리다이렉션 URI 추가:
   - 개발환경: `http://localhost:8080/api/v1/auth/google/callback`
   - 프로덕션: `https://yourdomain.com/api/v1/auth/google/callback`

## 2. 환경변수 설정

`.env` 파일을 생성하고 다음 환경변수를 추가:

```bash
# Google OAuth Configuration
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REDIRECT_URL=http://localhost:8080/api/v1/auth/google/callback
```

## 3. 테스트 방법

### Backend API 테스트

1. 서버 실행:
```bash
cd be
go run cmd/server/main.go
```

2. OAuth URL 생성 테스트:
```bash
curl "http://localhost:8080/api/v1/auth/google/login"
```

3. 지원되는 OAuth 제공업체 확인:
```bash
curl "http://localhost:8080/api/v1/auth/oauth/providers"
```

### Flutter 앱 테스트

1. Flutter 앱 실행:
```bash
cd ios
flutter run
```

2. 로그인 페이지에서 "Google로 계속하기" 버튼 클릭
3. 브라우저에서 Google OAuth 로그인 진행
4. 콜백 URL로 토큰이 전달되는지 확인

### Android 앱 테스트

1. Android 앱 실행:
```bash
cd android
./gradlew installDebug
```

2. 로그인 화면에서 Google 로그인 버튼 클릭
3. Chrome 브라우저에서 Google OAuth 진행

## 4. API 엔드포인트

### Google OAuth 로그인 시작
```
GET /api/v1/auth/google/login
```

### Google OAuth 콜백 처리
```
GET /api/v1/auth/google/callback?code=...&state=...
```

### 지원되는 OAuth 제공업체 조회
```
GET /api/v1/auth/oauth/providers
```

## 5. 데이터베이스 스키마

User 테이블에 추가된 OAuth 관련 필드:
- `provider`: 인증 제공업체 (google, apple, local)
- `google_id`: Google 사용자 ID
- `apple_id`: Apple 사용자 ID (향후 추가)

## 6. 보안 고려사항

1. **State 토큰**: CSRF 공격 방지를 위해 state 토큰 사용
2. **토큰 만료**: State 토큰은 10분 후 자동 만료
3. **HTTPS**: 프로덕션에서는 반드시 HTTPS 사용
4. **환경변수**: OAuth 클라이언트 시크릿은 환경변수로 관리

## 7. 트러블슈팅

### 일반적인 오류

1. **invalid_client**: 클라이언트 ID/시크릿 확인
2. **redirect_uri_mismatch**: Google Console의 리다이렉션 URI 확인
3. **access_denied**: 사용자가 권한 거부
4. **state_mismatch**: State 토큰 불일치 (재시도 필요)

### 로그 확인

서버 로그에서 OAuth 관련 오류 확인:
```bash
# Backend 로그
tail -f be/server.log

# Worker 로그  
tail -f worker/worker.log
```

## 8. 향후 확장

- Apple OAuth 추가
- 소셜 계정 연결/해제 기능
- OAuth 토큰 갱신
- 다중 OAuth 제공업체 지원