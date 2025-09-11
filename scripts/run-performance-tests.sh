#!/bin/bash

# Signal Performance Test Runner
# Orchestrates both k6 and Artillery performance tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/tests/performance"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
ENVIRONMENT="staging"
TEST_TYPE="all"
DURATION="5m"
VUS="100"
OUTPUT_DIR="$PROJECT_ROOT/test-results/performance"
PARALLEL_TESTS="false"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Target environment (staging|production) [default: staging]"
    echo "  -t, --type TYPE         Test type (k6|artillery|websocket|all) [default: all]"
    echo "  -d, --duration DURATION Test duration (e.g., 5m, 10m, 30m) [default: 5m]"
    echo "  -u, --users VUS         Number of virtual users [default: 100]"
    echo "  -o, --output DIR        Output directory for results [default: test-results/performance]"
    echo "  -p, --parallel          Run tests in parallel"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e staging -t k6 -d 10m -u 200"
    echo "  $0 -e production -t websocket -p"
    echo "  $0 --type all --duration 30m --users 500 --parallel"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -u|--users)
            VUS="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL_TESTS="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo "   Supported environments: staging, production"
    exit 1
fi

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
esac

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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

check_dependencies() {
    log "Checking dependencies..."
    
    # Check k6
    if ! command -v k6 &> /dev/null; then
        warning "k6 not found. Installing k6..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install k6
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
            echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
            sudo apt-get update
            sudo apt-get install k6
        else
            error "Unsupported OS for automatic k6 installation. Please install k6 manually."
            exit 1
        fi
    fi
    
    # Check Artillery
    if ! command -v artillery &> /dev/null; then
        warning "Artillery not found. Installing Artillery..."
        npm install -g artillery
    fi
    
    # Check Node.js (for WebSocket tests)
    if ! command -v node &> /dev/null; then
        error "Node.js not found. Please install Node.js to run WebSocket tests."
        exit 1
    fi
    
    success "All dependencies are available"
}

wait_for_services() {
    log "Waiting for services to be ready..."
    
    local retries=30
    local count=0
    
    while [ $count -lt $retries ]; do
        if curl -s -f "$BASE_URL/health" > /dev/null; then
            success "Backend service is ready"
            break
        fi
        
        count=$((count + 1))
        if [ $count -eq $retries ]; then
            error "Backend service not ready after $retries attempts"
            exit 1
        fi
        
        log "Waiting for backend service... ($count/$retries)"
        sleep 2
    done
    
    # Check WebSocket service
    if [[ "$TEST_TYPE" == "websocket" || "$TEST_TYPE" == "all" ]]; then
        count=0
        while [ $count -lt $retries ]; do
            if curl -s -f "${BASE_URL//http/http}/ws/health" > /dev/null 2>&1; then
                success "WebSocket service is ready"
                break
            fi
            
            count=$((count + 1))
            if [ $count -eq $retries ]; then
                error "WebSocket service not ready after $retries attempts"
                exit 1
            fi
            
            log "Waiting for WebSocket service... ($count/$retries)"
            sleep 2
        done
    fi
}

run_k6_tests() {
    log "Running k6 load tests..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local k6_output="$OUTPUT_DIR/k6-results-$(date +%Y%m%d-%H%M%S).json"
    local k6_command="k6 run \
        --vus $VUS \
        --duration $DURATION \
        --out json=$k6_output \
        -e BASE_URL=$BASE_URL \
        -e WS_URL=$WS_URL \
        $TEST_DIR/load-test.js"
    
    log "Command: $k6_command"
    
    if eval $k6_command; then
        success "k6 load tests completed successfully"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Generate summary
        if [[ -f "$k6_output" ]]; then
            log "Generating k6 test summary..."
            node -e "
                const fs = require('fs');
                const data = JSON.parse(fs.readFileSync('$k6_output', 'utf8'));
                const metrics = data.metrics;
                console.log('📊 k6 Test Results Summary:');
                console.log('  Duration:', data.state.testRunDurationMs, 'ms');
                console.log('  HTTP Requests:', metrics.http_reqs?.values?.count || 0);
                console.log('  HTTP Request Duration (avg):', (metrics.http_req_duration?.values?.avg || 0).toFixed(2), 'ms');
                console.log('  HTTP Request Duration (95%):', (metrics.http_req_duration?.values['p(95)'] || 0).toFixed(2), 'ms');
                console.log('  Error Rate:', ((metrics.http_req_failed?.values?.rate || 0) * 100).toFixed(2), '%');
                console.log('  WebSocket Messages:', metrics.websocket_messages_sent?.values?.count || 0);
            " || true
        fi
    else
        error "k6 load tests failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_websocket_tests() {
    log "Running WebSocket performance tests..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local ws_output="$OUTPUT_DIR/websocket-results-$(date +%Y%m%d-%H%M%S).json"
    local ws_command="k6 run \
        --out json=$ws_output \
        -e WS_URL=$WS_URL \
        -e BASE_URL=$BASE_URL \
        -e TEST_TYPE=connection_stress \
        $TEST_DIR/websocket-test.js"
    
    log "Command: $ws_command"
    
    if eval $ws_command; then
        success "WebSocket performance tests completed successfully"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Additional WebSocket-specific tests
        log "Running message throughput test..."
        local throughput_output="$OUTPUT_DIR/websocket-throughput-$(date +%Y%m%d-%H%M%S).json"
        k6 run \
            --out json=$throughput_output \
            -e WS_URL=$WS_URL \
            -e BASE_URL=$BASE_URL \
            -e TEST_TYPE=message_throughput \
            $TEST_DIR/websocket-test.js || warning "WebSocket throughput test had issues"
    else
        error "WebSocket performance tests failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_artillery_tests() {
    log "Running Artillery tests..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local artillery_output="$OUTPUT_DIR/artillery-results-$(date +%Y%m%d-%H%M%S)"
    local artillery_command="artillery run \
        --target $BASE_URL \
        --environment $ENVIRONMENT \
        --output $artillery_output.json \
        $TEST_DIR/artillery-config.yml"
    
    log "Command: $artillery_command"
    
    if eval $artillery_command; then
        success "Artillery tests completed successfully"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Generate HTML report
        if [[ -f "$artillery_output.json" ]]; then
            artillery report --output "$artillery_output.html" "$artillery_output.json" || true
            success "Artillery HTML report generated: $artillery_output.html"
        fi
    else
        error "Artillery tests failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_tests_parallel() {
    log "Running tests in parallel mode..."
    
    local pids=()
    
    case $TEST_TYPE in
        "all")
            run_k6_tests &
            pids+=($!)
            
            run_websocket_tests &
            pids+=($!)
            
            run_artillery_tests &
            pids+=($!)
            ;;
        *)
            warning "Parallel mode only supported for 'all' test type"
            run_tests_sequential
            return
            ;;
    esac
    
    # Wait for all tests to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    success "All parallel tests completed"
}

run_tests_sequential() {
    case $TEST_TYPE in
        "k6")
            run_k6_tests
            ;;
        "websocket")
            run_websocket_tests
            ;;
        "artillery")
            run_artillery_tests
            ;;
        "all")
            run_k6_tests
            run_websocket_tests
            run_artillery_tests
            ;;
        *)
            error "Unknown test type: $TEST_TYPE"
            echo "Supported types: k6, websocket, artillery, all"
            exit 1
            ;;
    esac
}

generate_final_report() {
    log "Generating final performance report..."
    
    local report_file="$OUTPUT_DIR/performance-summary-$(date +%Y%m%d-%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Signal Performance Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f5f5f5; padding: 20px; border-radius: 5px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { background: #fff; border: 1px solid #ddd; padding: 15px; border-radius: 5px; text-align: center; }
        .passed { color: #28a745; }
        .failed { color: #dc3545; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Signal Performance Test Report</h1>
        <p><strong>Environment:</strong> $ENVIRONMENT</p>
        <p><strong>Test Type:</strong> $TEST_TYPE</p>
        <p><strong>Duration:</strong> $DURATION</p>
        <p><strong>Virtual Users:</strong> $VUS</p>
        <p><strong>Generated:</strong> $(date)</p>
    </div>
    
    <div class="summary">
        <div class="metric">
            <h3>Tests Run</h3>
            <div style="font-size: 2em;">$TESTS_RUN</div>
        </div>
        <div class="metric">
            <h3>Tests Passed</h3>
            <div style="font-size: 2em;" class="passed">$TESTS_PASSED</div>
        </div>
        <div class="metric">
            <h3>Tests Failed</h3>
            <div style="font-size: 2em;" class="failed">$TESTS_FAILED</div>
        </div>
        <div class="metric">
            <h3>Success Rate</h3>
            <div style="font-size: 2em;">$(( TESTS_RUN > 0 ? TESTS_PASSED * 100 / TESTS_RUN : 0 ))%</div>
        </div>
    </div>
    
    <h2>📁 Test Results</h2>
    <ul>
EOF

    # List all generated files
    find "$OUTPUT_DIR" -name "*$(date +%Y%m%d)*" -type f | while read -r file; do
        echo "        <li><a href=\"file://$file\">$(basename "$file")</a></li>" >> "$report_file"
    done

    cat >> "$report_file" << EOF
    </ul>
    
    <h2>🎯 Next Steps</h2>
    <ul>
        <li>Review individual test results for detailed metrics</li>
        <li>Compare results with previous test runs</li>
        <li>Identify performance bottlenecks and optimization opportunities</li>
        <li>Update performance baselines if necessary</li>
    </ul>
</body>
</html>
EOF

    success "Final report generated: $report_file"
    
    # Open report in browser on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$report_file"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Signal Performance Test Runner${NC}"
    echo "=================================="
    echo
    
    log "Configuration:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Test Type: $TEST_TYPE"
    echo "  Duration: $DURATION"
    echo "  Virtual Users: $VUS"
    echo "  Output Directory: $OUTPUT_DIR"
    echo "  Parallel Tests: $PARALLEL_TESTS"
    echo
    
    check_dependencies
    wait_for_services
    
    local start_time=$(date +%s)
    
    if [[ "$PARALLEL_TESTS" == "true" ]]; then
        run_tests_parallel
    else
        run_tests_sequential
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo
    log "Test execution completed in ${duration}s"
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    
    generate_final_report
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        success "All performance tests passed! 🎉"
        exit 0
    else
        error "Some performance tests failed"
        exit 1
    fi
}

# Run main function
main