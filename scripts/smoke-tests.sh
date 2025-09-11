#!/bin/bash

# Signal Smoke Tests
# Quick validation that core services are operational after deployment

set -e

ENVIRONMENT=${1:-"staging"}
BASE_URL=""
WS_URL=""
TIMEOUT=30

# Set environment URLs
case $ENVIRONMENT in
    "staging")
        BASE_URL="http://localhost:8081"
        WS_URL="ws://localhost:8082"
        ;;
    "production")
        BASE_URL="https://api.signal.com"
        WS_URL="wss://ws.signal.com"
        ;;
    *)
        echo "❌ Unknown environment: $ENVIRONMENT"
        echo "Usage: $0 [staging|production]"
        exit 1
        ;;
esac

echo "🚀 Running smoke tests for $ENVIRONMENT environment"
echo "Base URL: $BASE_URL"
echo "WebSocket URL: $WS_URL"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Helper functions
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "🧪 $test_name... "
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if timeout $TIMEOUT bash -c "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_test_with_retry() {
    local test_name="$1"
    local test_command="$2"
    local retries=${3:-3}
    
    for i in $(seq 1 $retries); do
        if run_test "$test_name (attempt $i/$retries)" "$test_command"; then
            return 0
        fi
        sleep 2
    done
    return 1
}

# Core Health Checks
echo "=== 🏥 Core Health Checks ==="

run_test "Backend Health Check" "
    curl -f -s $BASE_URL/health | grep -q 'status.*ok'
"

run_test "Database Connection" "
    curl -f -s $BASE_URL/health/db | grep -q 'database.*connected'
"

run_test "Redis Connection" "
    curl -f -s $BASE_URL/health/redis | grep -q 'redis.*connected'
"

run_test "WebSocket Health Check" "
    curl -f -s $WS_URL/ws/health | grep -q 'websocket.*ok'
"

echo

# API Endpoint Tests
echo "=== 🔌 API Endpoint Tests ==="

# Test user registration (with cleanup)
TEST_EMAIL="smoketest-$(date +%s)@signal.com"

run_test "User Registration API" "
    response=\$(curl -s -X POST $BASE_URL/auth/register \
        -H 'Content-Type: application/json' \
        -d '{
            \"email\": \"$TEST_EMAIL\",
            \"name\": \"Smoke Test User\",
            \"latitude\": 37.4981,
            \"longitude\": 127.0276
        }')
    echo \$response | grep -q '\"token\"' && echo \$response | grep -q '\"user\"'
"

# Get auth token for subsequent tests
AUTH_TOKEN=$(curl -s -X POST $BASE_URL/auth/register \
    -H 'Content-Type: application/json' \
    -d '{
        "email": "smoketest-auth-'$(date +%s)'@signal.com",
        "name": "Auth Test User",
        "latitude": 37.4981,
        "longitude": 127.0276
    }' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -n "$AUTH_TOKEN" ]; then
    run_test "Signal Creation API" "
        curl -f -s -X POST $BASE_URL/signals \
            -H 'Content-Type: application/json' \
            -H 'Authorization: Bearer $AUTH_TOKEN' \
            -d '{
                \"title\": \"Smoke Test Signal\",
                \"description\": \"Automated smoke test\",
                \"category\": \"테스트\",
                \"latitude\": 37.4981,
                \"longitude\": 127.0276,
                \"max_count\": 5,
                \"meet_time\": \"$(date -d '+2 hours' --iso-8601=seconds)\"
            }' | grep -q '\"id\"'
    "
    
    run_test "Signal Search API" "
        curl -f -s '$BASE_URL/signals/search?lat=37.4981&lng=127.0276&radius=1000' \
            -H 'Authorization: Bearer $AUTH_TOKEN' | grep -q '\[\]' || grep -q '\"id\"'
    "
    
    run_test "User Profile API" "
        curl -f -s $BASE_URL/users/profile \
            -H 'Authorization: Bearer $AUTH_TOKEN' | grep -q '\"email\"'
    "
else
    echo "⚠️  Skipping authenticated API tests (no auth token)"
    TESTS_TOTAL=$((TESTS_TOTAL + 3))
    TESTS_FAILED=$((TESTS_FAILED + 3))
fi

echo

# WebSocket Connection Tests
echo "=== 🔌 WebSocket Connection Tests ==="

# Create a simple WebSocket test
run_test_with_retry "WebSocket Connection" "
    timeout 10 bash -c '
        # Create a simple WebSocket test script
        cat > /tmp/ws_test.js << EOF
const WebSocket = require(\"ws\");
const ws = new WebSocket(\"$WS_URL/ws/test\");
ws.on(\"open\", () => {
    console.log(\"Connected\");
    ws.close();
    process.exit(0);
});
ws.on(\"error\", (err) => {
    console.error(\"Error:\", err.message);
    process.exit(1);
});
setTimeout(() => {
    console.error(\"Timeout\");
    process.exit(1);
}, 5000);
EOF
        node /tmp/ws_test.js 2>/dev/null
    '" 2

echo

# Performance Tests
echo "=== ⚡ Basic Performance Tests ==="

run_test "API Response Time (< 1s)" "
    start=\$(date +%s%N)
    curl -f -s $BASE_URL/health > /dev/null
    end=\$(date +%s%N)
    duration=\$(( (end - start) / 1000000 ))  # Convert to milliseconds
    [ \$duration -lt 1000 ]  # Less than 1 second
"

run_test "Concurrent API Requests (10 users)" "
    for i in {1..10}; do
        curl -f -s $BASE_URL/health > /dev/null &
    done
    wait
"

echo

# Resource Usage Tests
echo "=== 📊 Resource Usage Tests ==="

if command -v docker &> /dev/null && [ "$ENVIRONMENT" = "staging" ]; then
    run_test "Backend Container Memory Usage" "
        memory_usage=\$(docker stats --no-stream --format 'table {{.MemPerc}}' signal-test-backend | tail -n 1 | sed 's/%//')
        [ \$(echo \"\$memory_usage < 80\" | bc -l) -eq 1 ]
    "
    
    run_test "Backend Container CPU Usage" "
        cpu_usage=\$(docker stats --no-stream --format 'table {{.CPUPerc}}' signal-test-backend | tail -n 1 | sed 's/%//')
        [ \$(echo \"\$cpu_usage < 90\" | bc -l) -eq 1 ]
    "
else
    echo "ℹ️  Skipping container resource tests (Docker not available or not staging)"
fi

echo

# Security Tests
echo "=== 🔒 Basic Security Tests ==="

run_test "HTTPS Redirect (prod only)" "
    if [ '$ENVIRONMENT' = 'production' ]; then
        response=\$(curl -s -I http://api.signal.com/health)
        echo \$response | grep -q '301' || echo \$response | grep -q 'https'
    else
        exit 0  # Skip for staging
    fi
"

run_test "Security Headers" "
    headers=\$(curl -s -I $BASE_URL/health)
    echo \$headers | grep -q 'X-Content-Type-Options' || 
    echo \$headers | grep -q 'X-Frame-Options' || 
    echo \$headers | grep -q 'X-XSS-Protection'
"

run_test "No Sensitive Info Exposure" "
    response=\$(curl -s $BASE_URL/health)
    ! echo \$response | grep -iE '(password|secret|key|token)' | grep -v '\"token\":'
"

echo

# Cleanup
echo "=== 🧹 Cleanup ==="

if [ -n "$AUTH_TOKEN" ]; then
    echo "🗑️  Cleaning up test data..."
    # Delete test signals and users created during smoke tests
    curl -s -X DELETE "$BASE_URL/admin/cleanup-tests" \
        -H "Authorization: Bearer $AUTH_TOKEN" > /dev/null || true
fi

# Remove temporary files
rm -f /tmp/ws_test.js

echo

# Summary
echo "=== 📊 Test Summary ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $TESTS_TOTAL"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All smoke tests passed!${NC}"
    echo "✅ $ENVIRONMENT environment is healthy and ready"
    exit 0
else
    success_rate=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
    echo -e "${RED}❌ Some smoke tests failed${NC}"
    echo "Success Rate: $success_rate%"
    
    if [ $success_rate -lt 80 ]; then
        echo -e "${RED}💥 Critical: Success rate below 80%${NC}"
        echo "🚨 $ENVIRONMENT environment may not be ready for production traffic"
        exit 2
    else
        echo -e "${YELLOW}⚠️  Warning: Some non-critical tests failed${NC}"
        echo "🟡 $ENVIRONMENT environment has minor issues but may be usable"
        exit 1
    fi
fi