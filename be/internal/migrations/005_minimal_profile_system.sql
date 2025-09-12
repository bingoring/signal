-- Phase 1: 최소주의 프로필 시스템 마이그레이션
-- 작성일: 2025-01-01
-- 목적: 복잡한 프로필 시스템을 최소주의 신뢰 기반 시스템으로 전환

-- ============================================
-- 1. 새로운 컬럼 추가 (하위 호환성 유지)
-- ============================================

-- MannerScore를 MannerTemperature로 마이그레이션 준비
ALTER TABLE user_profiles 
ADD COLUMN manner_temperature DECIMAL(4,1) DEFAULT 36.5 COMMENT '매너온도 (20.0-50.0도)';

-- 활동 기반 신뢰 지표 추가
ALTER TABLE user_profiles 
ADD COLUMN signal_count INT DEFAULT 0 COMMENT '생성한 Signal 수',
ADD COLUMN join_count INT DEFAULT 0 COMMENT '참여한 Signal 수',
ADD COLUMN completion_rate DECIMAL(5,2) DEFAULT 0 COMMENT '완료율 (0-100)',
ADD COLUMN last_activity_at TIMESTAMP NULL COMMENT '최근 활동 시간';

-- 선택적 정보 필드 추가 (기존 필드 축소 대비)
ALTER TABLE user_profiles 
ADD COLUMN one_line VARCHAR(50) NULL COMMENT '한 줄 소개 (Bio 대체)',
ADD COLUMN notifications_enabled BOOLEAN DEFAULT TRUE COMMENT '알림 설정 (기존 복수 설정 통합)';

-- ============================================
-- 2. 기존 데이터 마이그레이션
-- ============================================

-- MannerScore → MannerTemperature 데이터 이전
UPDATE user_profiles 
SET manner_temperature = COALESCE(manner_score, 36.5)
WHERE manner_temperature = 36.5;

-- 기존 CompleteSignals 데이터를 SignalCount + JoinCount로 분배 (임시 로직)
UPDATE user_profiles 
SET signal_count = FLOOR(completed_signals / 2),
    join_count = CEIL(completed_signals / 2)
WHERE completed_signals > 0;

-- 완료율 초기 계산
UPDATE user_profiles 
SET completion_rate = CASE 
    WHEN (signal_count + join_count) = 0 THEN 0
    ELSE ((signal_count + join_count - no_show_count) * 100.0 / (signal_count + join_count))
END;

-- Bio → OneLine 마이그레이션 (첫 50자만)
UPDATE user_profiles 
SET one_line = SUBSTRING(bio, 1, 50)
WHERE bio IS NOT NULL AND bio != '';

-- 복수 알림 설정을 하나로 통합
UPDATE user_profiles 
SET notifications_enabled = CASE 
    WHEN push_notifications = TRUE OR location_sharing = TRUE THEN TRUE
    ELSE FALSE
END;

-- DisplayName 길이 제한 (30자 초과 시 자르기)
UPDATE user_profiles 
SET display_name = SUBSTRING(display_name, 1, 30)
WHERE LENGTH(display_name) > 30;

-- ============================================
-- 3. 매너온도 계산 로직을 애플리케이션으로 이동
-- ============================================
-- 기존 MySQL 함수와 트리거를 Go 백엔드로 이동:
-- - calculate_manner_temperature() → UserService.CalculateMannerTemperature()
-- - update_manner_temperature_on_profile_change → 비동기 워커에서 일괄 처리
-- 
-- 이유:
-- 1. 복잡한 비즈니스 로직을 Go 코드로 관리하여 유지보수성 향상
-- 2. 단위 테스트 가능
-- 3. 트리거로 인한 데이터 일관성 문제 방지
-- 4. 성능 모니터링과 디버깅 용이

-- ============================================
-- 5. 인덱스 추가 (성능 최적화)
-- ============================================

-- 매너온도 기반 검색을 위한 인덱스
CREATE INDEX idx_user_profiles_manner_temperature ON user_profiles(manner_temperature DESC);

-- 최근 활동 기반 검색을 위한 인덱스
CREATE INDEX idx_user_profiles_last_activity ON user_profiles(last_activity_at DESC);

-- 완료율 기반 검색을 위한 인덱스
CREATE INDEX idx_user_profiles_completion_rate ON user_profiles(completion_rate DESC);

-- 복합 인덱스 (매너온도 + 최근활동)
CREATE INDEX idx_user_profiles_temp_activity ON user_profiles(manner_temperature DESC, last_activity_at DESC);

-- ============================================
-- 6. 데이터 검증 및 정리
-- ============================================

-- 기존 데이터의 매너온도는 애플리케이션 시작 시 일괄 재계산
-- 또는 별도 마이그레이션 스크립트에서 처리

-- 데이터 일관성 검증
SELECT 
    COUNT(*) as total_profiles,
    MIN(manner_temperature) as min_temp,
    MAX(manner_temperature) as max_temp,
    AVG(manner_temperature) as avg_temp,
    COUNT(CASE WHEN manner_temperature >= 40.0 THEN 1 END) as high_trust_users
FROM user_profiles;

-- ============================================
-- 7. 뷰 생성 (편의성)
-- ============================================

-- 사용자 신뢰도 레벨 뷰
CREATE VIEW user_trust_levels AS
SELECT 
    up.user_id,
    up.display_name,
    up.manner_temperature,
    CASE 
        WHEN up.manner_temperature >= 45.0 THEN '매우 높음'
        WHEN up.manner_temperature >= 40.0 THEN '높음'
        WHEN up.manner_temperature >= 37.0 THEN '보통'
        WHEN up.manner_temperature >= 32.0 THEN '낮음'
        ELSE '매우 낮음'
    END as trust_level,
    up.completion_rate,
    up.signal_count + up.join_count as total_activities,
    up.last_activity_at,
    CASE 
        WHEN up.last_activity_at IS NULL THEN FALSE
        WHEN up.last_activity_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN TRUE
        ELSE FALSE
    END as is_recently_active
FROM user_profiles up
WHERE up.display_name IS NOT NULL;

-- ============================================
-- 8. 마이그레이션 완료 로그
-- ============================================

-- 마이그레이션 로그 테이블이 없다면 생성
CREATE TABLE IF NOT EXISTS migration_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    migration_name VARCHAR(100) NOT NULL,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('SUCCESS', 'FAILED') NOT NULL,
    notes TEXT
);

-- 마이그레이션 완료 기록
INSERT INTO migration_logs (migration_name, status, notes)
VALUES ('005_minimal_profile_system', 'SUCCESS', 
        'Successfully migrated to minimal profile system with manner temperature calculation');

-- ============================================
-- 주의사항 및 다음 단계
-- ============================================

/*
주의사항:
1. 이 마이그레이션은 기존 데이터를 유지하면서 새 시스템을 추가합니다
2. 기존 컬럼들(age, gender, bio 등)은 Phase 2에서 제거될 예정입니다
3. 애플리케이션 코드 배포 후 안정화되면 구 컬럼들을 제거하세요

다음 단계:
1. 백엔드 API 핸들러 업데이트
2. 프론트엔드 UI 수정
3. 기존 컬럼 제거 (Phase 2)
4. 이모지 아바타 시스템 구현 (Phase 2)

검증 쿼리:
SELECT 
    display_name,
    manner_temperature,
    signal_count,
    join_count,
    completion_rate,
    one_line
FROM user_profiles 
ORDER BY manner_temperature DESC 
LIMIT 10;
*/