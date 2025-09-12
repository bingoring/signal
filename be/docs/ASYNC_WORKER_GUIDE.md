# 비동기 워커 처리 가이드

Signal 백엔드에서 비동기적으로 처리할 수 있는 작업들과 구현 방법을 정리합니다.

## 🔄 비동기 처리 대상 작업

### 1. 매너온도 계산 및 업데이트
**기존**: MySQL 트리거로 실시간 업데이트  
**변경**: 주기적 배치 작업으로 처리

```go
// 주기: 5분마다 실행
func RecalculateMannerTemperatures() {
    // 1. 모든 사용자 프로필 조회
    // 2. signal_count, join_count, no_show_count, completion_rate 기반으로 매너온도 계산
    // 3. 일괄 업데이트
}
```

### 2. 아바타 사용 통계 업데이트
**기존**: MySQL 트리거로 실시간 업데이트  
**변경**: 이벤트 큐 기반 비동기 처리

```go
// 아바타 설정 시 이벤트 발생
type AvatarUsageEvent struct {
    UserID   uint
    AvatarID uint
    Action   string // "set", "favorite", "unfavorite"
}

// 워커에서 처리
func ProcessAvatarUsageEvent(event AvatarUsageEvent) {
    // 1. avatars.usage_count 증가
    // 2. user_avatars.last_used 업데이트
    // 3. user_profiles.last_activity_at 업데이트
}
```

### 3. 단골 관계 통계 업데이트
**기존**: MySQL 트리거로 buddy_count 실시간 관리  
**변경**: 실시간 COUNT 쿼리로 계산 (캐시 활용)

```go
// BuddyService에서 실시간 계산
func (s *BuddyService) GetBuddyCount(userID uint) int {
    // Redis 캐시 먼저 확인 (TTL: 10분)
    // 캐시 없으면 COUNT 쿼리 실행 후 캐시에 저장
}
```

### 4. 인기 아바타 순위 계산
**기존**: 없음  
**새로 추가**: 시간별/일별 인기 아바타 순위 계산

```go
// 주기: 1시간마다 실행
func UpdatePopularAvatarRankings() {
    // 1. 최근 24시간/7일/30일 사용 통계 집계
    // 2. 카테고리별 인기 순위 계산
    // 3. Redis에 순위 데이터 캐시
}
```

## 🏗️ 워커 시스템 아키텍처

### 1. 이벤트 기반 아키텍처
```go
// 이벤트 발행
type EventPublisher interface {
    PublishAvatarUsage(userID, avatarID uint, action string)
    PublishMannerUpdate(userID uint, eventType string)
    PublishBuddyEvent(user1ID, user2ID uint, action string)
}

// 워커 시스템
type WorkerSystem struct {
    redisClient *redis.Client
    db         *gorm.DB
    logger     *logger.Logger
}
```

### 2. Redis 기반 작업 큐
```go
// 작업 큐 구조
type JobQueue struct {
    client *redis.Client
}

func (jq *JobQueue) EnqueueAvatarUpdate(userID, avatarID uint) {
    job := map[string]interface{}{
        "type": "avatar_usage",
        "user_id": userID,
        "avatar_id": avatarID,
        "timestamp": time.Now().Unix(),
    }
    jq.client.LPush("avatar_jobs", toJSON(job))
}
```

### 3. 배치 작업 스케줄러
```go
// Cron 기반 스케줄러
func SetupWorkerSchedules() {
    c := cron.New()
    
    // 매 5분: 매너온도 재계산
    c.AddFunc("*/5 * * * *", RecalculateMannerTemperatures)
    
    // 매 시간: 인기 아바타 순위 업데이트
    c.AddFunc("0 * * * *", UpdatePopularAvatarRankings)
    
    // 매일 새벽 2시: 전체 통계 재계산
    c.AddFunc("0 2 * * *", RecalculateAllStatistics)
    
    c.Start()
}
```

## ⚡ 성능 최적화 전략

### 1. 배치 처리
```go
// 개별 업데이트 대신 배치 업데이트
func BatchUpdateAvatarUsage(updates []AvatarUsageUpdate) {
    tx := db.Begin()
    
    // 1000개씩 배치로 처리
    for i := 0; i < len(updates); i += 1000 {
        end := min(i+1000, len(updates))
        batch := updates[i:end]
        
        // SQL의 ON DUPLICATE KEY UPDATE 또는 UPSERT 활용
        tx.Clauses(clause.OnConflict{
            UpdateAll: true,
        }).CreateInBatches(batch, 1000)
    }
    
    tx.Commit()
}
```

### 2. Redis 캐시 활용
```go
// 자주 조회되는 데이터 캐시
func (s *BuddyService) GetBuddyStats(userID uint) (*BuddyStats, error) {
    // 캐시 키 생성
    cacheKey := fmt.Sprintf("buddy_stats:%d", userID)
    
    // Redis에서 조회
    if cached, err := s.redis.Get(cacheKey).Result(); err == nil {
        var stats BuddyStats
        json.Unmarshal([]byte(cached), &stats)
        return &stats, nil
    }
    
    // DB에서 조회
    stats := s.calculateBuddyStats(userID)
    
    // 캐시에 저장 (TTL: 10분)
    statsJSON, _ := json.Marshal(stats)
    s.redis.SetEX(cacheKey, statsJSON, 10*time.Minute)
    
    return stats, nil
}
```

### 3. 점진적 마이그레이션
```go
// 트리거 → 워커 점진적 전환
func (s *AvatarService) SetUserAvatar(userID, avatarID uint) error {
    // 1. 메인 로직 처리
    if err := s.repo.SetUserAvatar(userID, avatarID); err != nil {
        return err
    }
    
    // 2. 통계 업데이트 (기존 동기 방식)
    s.repo.UpdateAvatarUsage(avatarID)
    
    // 3. 이벤트 발행 (새로운 비동기 방식)
    s.eventPublisher.PublishAvatarUsage(userID, avatarID, "set")
    
    return nil
}
```

## 🚨 주의사항

### 1. 데이터 일관성
- 중요한 비즈니스 로직은 동기적으로 처리 유지
- 통계/분석 데이터만 비동기 처리
- 이벤트 순서 보장 필요시 파티셔닝 활용

### 2. 에러 처리
- 재시도 로직 구현 (지수 백오프)
- Dead Letter Queue 활용
- 모니터링 및 알림 시스템 구축

### 3. 리소스 관리
- 워커 수 동적 조절 (부하에 따라)
- 메모리 사용량 모니터링
- DB 커넥션 풀 관리

## 📊 모니터링

### 1. 메트릭
- 작업 큐 길이
- 처리 시간 (P50, P95, P99)
- 에러율
- 재시도 횟수

### 2. 대시보드
- Grafana + Prometheus 활용
- 실시간 워커 상태 모니터링
- 성능 지표 시각화

## 🔄 구현 단계

1. **Phase 1**: 이벤트 시스템 구축 + 기존 동기 방식 병행
2. **Phase 2**: 워커 구현 + 점진적 전환
3. **Phase 3**: 트리거 완전 제거 + 성능 최적화
4. **Phase 4**: 모니터링 및 운영 체계 구축