#!/bin/bash

# Phase 1 데이터베이스 마이그레이션 검증 스크립트
# 목적: 005_minimal_profile_system.sql 마이그레이션의 성공 여부와 데이터 무결성 검증

set -e

# 설정
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-signal_db}"
DB_USER="${DB_USER:-signal_user}"
DB_PASSWORD="${DB_PASSWORD:-signal_password}"

# 색상 설정
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# MySQL 연결 함수
mysql_query() {
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -e "$1" 2>/dev/null
}

# 테이블 존재 여부 확인
check_table_exists() {
    local table_name=$1
    local result=$(mysql_query "SHOW TABLES LIKE '$table_name';" | grep -c "$table_name" || true)
    echo "$result"
}

# 컬럼 존재 여부 확인
check_column_exists() {
    local table_name=$1
    local column_name=$2
    local result=$(mysql_query "SHOW COLUMNS FROM $table_name LIKE '$column_name';" | grep -c "$column_name" || true)
    echo "$result"
}

# 인덱스 존재 여부 확인
check_index_exists() {
    local table_name=$1
    local index_name=$2
    local result=$(mysql_query "SHOW INDEX FROM $table_name WHERE Key_name = '$index_name';" | grep -c "$index_name" || true)
    echo "$result"
}

# 함수 존재 여부 확인
check_function_exists() {
    local function_name=$1
    local result=$(mysql_query "SHOW FUNCTION STATUS WHERE Name = '$function_name';" | grep -c "$function_name" || true)
    echo "$result"
}

# 트리거 존재 여부 확인
check_trigger_exists() {
    local trigger_name=$1
    local result=$(mysql_query "SHOW TRIGGERS WHERE Trigger = '$trigger_name';" | grep -c "$trigger_name" || true)
    echo "$result"
}

echo -e "${BLUE}🔍 Signal Phase 1 마이그레이션 검증 시작${NC}"
echo "=================================="
echo

# 1. 기본 연결 테스트
log "데이터베이스 연결 테스트 중..."
if mysql_query "SELECT 1;" > /dev/null 2>&1; then
    success "데이터베이스 연결 성공"
else
    error "데이터베이스 연결 실패. 연결 정보를 확인해주세요."
    exit 1
fi

# 2. 테이블 존재 확인
log "필요한 테이블 존재 여부 확인 중..."
if [ "$(check_table_exists 'user_profiles')" -eq 1 ]; then
    success "user_profiles 테이블 존재 확인"
else
    error "user_profiles 테이블이 존재하지 않습니다"
    exit 1
fi

if [ "$(check_table_exists 'migration_logs')" -eq 1 ]; then
    success "migration_logs 테이블 존재 확인"
else
    warning "migration_logs 테이블이 없습니다. 마이그레이션 로그를 확인할 수 없습니다."
fi

# 3. 새로운 컬럼들 존재 확인
log "Phase 1에서 추가된 컬럼들 확인 중..."

required_columns=(
    "manner_temperature"
    "signal_count"
    "join_count"
    "completion_rate"
    "last_activity_at"
    "one_line"
    "notifications_enabled"
)

missing_columns=()

for column in "${required_columns[@]}"; do
    if [ "$(check_column_exists 'user_profiles' "$column")" -eq 1 ]; then
        success "컬럼 $column 존재 확인"
    else
        error "필수 컬럼 $column이 존재하지 않습니다"
        missing_columns+=("$column")
    fi
done

if [ ${#missing_columns[@]} -ne 0 ]; then
    error "누락된 컬럼들: ${missing_columns[*]}"
    exit 1
fi

# 4. 인덱스 존재 확인
log "성능 최적화 인덱스들 확인 중..."

required_indexes=(
    "idx_user_profiles_manner_temperature"
    "idx_user_profiles_last_activity"
    "idx_user_profiles_completion_rate"
    "idx_user_profiles_temp_activity"
)

for index in "${required_indexes[@]}"; do
    if [ "$(check_index_exists 'user_profiles' "$index")" -gt 0 ]; then
        success "인덱스 $index 존재 확인"
    else
        warning "인덱스 $index가 존재하지 않습니다. 성능에 영향을 줄 수 있습니다."
    fi
done

# 5. MySQL 함수 존재 확인
log "매너온도 계산 함수 확인 중..."
if [ "$(check_function_exists 'calculate_manner_temperature')" -eq 1 ]; then
    success "calculate_manner_temperature 함수 존재 확인"
else
    error "calculate_manner_temperature 함수가 존재하지 않습니다"
    exit 1
fi

# 6. 트리거 존재 확인
log "자동 업데이트 트리거 확인 중..."
if [ "$(check_trigger_exists 'update_manner_temperature_on_profile_change')" -eq 1 ]; then
    success "update_manner_temperature_on_profile_change 트리거 존재 확인"
else
    error "매너온도 자동 업데이트 트리거가 존재하지 않습니다"
    exit 1
fi

# 7. 뷰 존재 확인
log "신뢰도 레벨 뷰 확인 중..."
if [ "$(check_table_exists 'user_trust_levels')" -eq 1 ]; then
    success "user_trust_levels 뷰 존재 확인"
else
    warning "user_trust_levels 뷰가 존재하지 않습니다"
fi

# 8. 데이터 무결성 검증
log "데이터 무결성 검증 중..."

# 매너온도 범위 확인 (20.0 ~ 50.0)
invalid_temp_count=$(mysql_query "SELECT COUNT(*) FROM user_profiles WHERE manner_temperature < 20.0 OR manner_temperature > 50.0;" | tail -n 1)
if [ "$invalid_temp_count" -eq 0 ]; then
    success "모든 매너온도가 유효한 범위(20.0~50.0) 내에 있습니다"
else
    error "$invalid_temp_count 개의 프로필에서 매너온도가 유효 범위를 벗어났습니다"
fi

# DisplayName 길이 확인 (30자 이하)
long_name_count=$(mysql_query "SELECT COUNT(*) FROM user_profiles WHERE LENGTH(display_name) > 30;" | tail -n 1)
if [ "$long_name_count" -eq 0 ]; then
    success "모든 DisplayName이 30자 이하입니다"
else
    warning "$long_name_count 개의 프로필에서 DisplayName이 30자를 초과합니다"
fi

# OneLine 길이 확인 (50자 이하)
long_oneline_count=$(mysql_query "SELECT COUNT(*) FROM user_profiles WHERE LENGTH(one_line) > 50;" | tail -n 1)
if [ "$long_oneline_count" -eq 0 ]; then
    success "모든 OneLine이 50자 이하입니다"
else
    warning "$long_oneline_count 개의 프로필에서 OneLine이 50자를 초과합니다"
fi

# 완료율 범위 확인 (0 ~ 100)
invalid_rate_count=$(mysql_query "SELECT COUNT(*) FROM user_profiles WHERE completion_rate < 0 OR completion_rate > 100;" | tail -n 1)
if [ "$invalid_rate_count" -eq 0 ]; then
    success "모든 완료율이 유효한 범위(0~100) 내에 있습니다"
else
    error "$invalid_rate_count 개의 프로필에서 완료율이 유효 범위를 벗어났습니다"
fi

# 9. 매너온도 계산 함수 테스트
log "매너온도 계산 함수 동작 테스트 중..."
test_result=$(mysql_query "SELECT calculate_manner_temperature(5, 10, 2, 8, 80.0) as test_temp;" | tail -n 1)
expected_temp="37.15"  # 36.5 + (13*0.1) + (8*0.05) - (2*0.3) = 36.5 + 1.3 + 0.4 - 0.6 = 37.6

if [[ "$test_result" == *"37"* ]]; then
    success "매너온도 계산 함수가 정상적으로 동작합니다 (결과: $test_result)"
else
    error "매너온도 계산 함수 동작에 문제가 있습니다 (결과: $test_result)"
fi

# 10. 마이그레이션 로그 확인
log "마이그레이션 실행 로그 확인 중..."
if [ "$(check_table_exists 'migration_logs')" -eq 1 ]; then
    migration_status=$(mysql_query "SELECT status FROM migration_logs WHERE migration_name = '005_minimal_profile_system' ORDER BY executed_at DESC LIMIT 1;" | tail -n 1)
    if [ "$migration_status" = "SUCCESS" ]; then
        success "마이그레이션이 성공적으로 완료되었습니다"
    else
        warning "마이그레이션 상태: $migration_status"
    fi
else
    warning "마이그레이션 로그를 확인할 수 없습니다"
fi

# 11. 성능 테스트
log "기본 성능 테스트 중..."
start_time=$(date +%s%N)
mysql_query "SELECT * FROM user_profiles ORDER BY manner_temperature DESC LIMIT 10;" > /dev/null
end_time=$(date +%s%N)
duration=$(( (end_time - start_time) / 1000000 ))  # 밀리초로 변환

if [ "$duration" -lt 100 ]; then
    success "매너온도 기준 상위 10명 조회 성능: ${duration}ms (목표: <100ms)"
else
    warning "매너온도 기준 상위 10명 조회 성능: ${duration}ms (목표 100ms 초과)"
fi

# 12. 통계 정보 출력
echo
log "Phase 1 마이그레이션 통계 정보"
echo "=============================="

total_profiles=$(mysql_query "SELECT COUNT(*) FROM user_profiles;" | tail -n 1)
avg_temp=$(mysql_query "SELECT ROUND(AVG(manner_temperature), 2) FROM user_profiles;" | tail -n 1)
max_temp=$(mysql_query "SELECT MAX(manner_temperature) FROM user_profiles;" | tail -n 1)
min_temp=$(mysql_query "SELECT MIN(manner_temperature) FROM user_profiles;" | tail -n 1)
high_trust_count=$(mysql_query "SELECT COUNT(*) FROM user_profiles WHERE manner_temperature >= 40.0;" | tail -n 1)
active_users=$(mysql_query "SELECT COUNT(*) FROM user_profiles WHERE last_activity_at >= DATE_SUB(NOW(), INTERVAL 7 DAY);" | tail -n 1)

echo "총 프로필 수: $total_profiles"
echo "평균 매너온도: ${avg_temp}도"
echo "최고 매너온도: ${max_temp}도"
echo "최저 매너온도: ${min_temp}도"
echo "고신뢰 사용자(40도 이상): $high_trust_count명"
echo "최근 7일 활성 사용자: $active_users명"

# 최종 결과
echo
if [ ${#missing_columns[@]} -eq 0 ] && [ "$invalid_temp_count" -eq 0 ] && [ "$invalid_rate_count" -eq 0 ]; then
    success "🎉 Phase 1 마이그레이션 검증이 성공적으로 완료되었습니다!"
    echo
    echo -e "${GREEN}다음 단계를 진행할 수 있습니다:${NC}"
    echo "1. 백엔드 API 테스트"
    echo "2. 프론트엔드 UI 업데이트"
    echo "3. Phase 2 구현 시작"
else
    error "마이그레이션 검증 중 문제가 발견되었습니다. 위의 오류를 수정한 후 다시 시도해주세요."
    exit 1
fi