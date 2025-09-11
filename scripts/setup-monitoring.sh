#!/bin/bash

# Signal Monitoring Stack Setup Script
# Sets up Prometheus, Grafana, AlertManager, and ELK Stack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MONITORING_DIR="$PROJECT_ROOT/monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="development"
STACK_TYPE="full"
DATA_RETENTION="30d"
MEMORY_LIMIT="2g"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environment (development|staging|production) [default: development]"
    echo "  -s, --stack TYPE        Stack type (prometheus|grafana|elk|full) [default: full]"
    echo "  -r, --retention TIME    Data retention period [default: 30d]"
    echo "  -m, --memory LIMIT      Memory limit for services [default: 2g]"
    echo "  --clean                 Clean existing data before setup"
    echo "  --no-data              Skip data volume creation"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e production -s full -r 90d -m 4g"
    echo "  $0 -e staging -s prometheus --clean"
    echo "  $0 -s elk --no-data"
}

# Parse command line arguments
CLEAN_DATA="false"
SKIP_VOLUMES="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -s|--stack)
            STACK_TYPE="$2"
            shift 2
            ;;
        -r|--retention)
            DATA_RETENTION="$2"
            shift 2
            ;;
        -m|--memory)
            MEMORY_LIMIT="$2"
            shift 2
            ;;
        --clean)
            CLEAN_DATA="true"
            shift
            ;;
        --no-data)
            SKIP_VOLUMES="true"
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
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info > /dev/null 2>&1; then
        error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    success "All dependencies are available"
}

create_directories() {
    log "Creating monitoring directories..."
    
    mkdir -p "$MONITORING_DIR"/{prometheus,grafana/{dashboards,provisioning/{dashboards,datasources}},alertmanager,elk,logstash/{config,pipeline},blackbox,loki,promtail}
    
    success "Monitoring directories created"
}

setup_prometheus() {
    log "Setting up Prometheus..."
    
    # Update Prometheus config with environment-specific settings
    cat > "$MONITORING_DIR/prometheus/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'signal-monitor'
    environment: '$ENVIRONMENT'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'signal-backend'
    metrics_path: '/metrics'
    scrape_interval: 15s
    static_configs:
      - targets: ['signal-backend:8080']

  - job_name: 'signal-websocket'
    metrics_path: '/metrics'
    scrape_interval: 15s
    static_configs:
      - targets: ['signal-websocket:8081']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
EOF
    
    success "Prometheus configuration created"
}

setup_grafana() {
    log "Setting up Grafana..."
    
    # Create Grafana provisioning configs
    mkdir -p "$MONITORING_DIR/grafana/provisioning/datasources"
    mkdir -p "$MONITORING_DIR/grafana/provisioning/dashboards"
    
    # Datasource configuration
    cat > "$MONITORING_DIR/grafana/provisioning/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    access: proxy
    isDefault: true
    editable: true
    
  - name: Loki
    type: loki
    url: http://loki:3100
    access: proxy
    
  - name: Elasticsearch
    type: elasticsearch
    url: http://elasticsearch:9200
    access: proxy
    database: "signal-logs-*"
    interval: Daily
    timeField: "@timestamp"
EOF

    # Dashboard provider configuration
    cat > "$MONITORING_DIR/grafana/provisioning/dashboards/dashboards.yml" << EOF
apiVersion: 1

providers:
  - name: 'Signal Dashboards'
    orgId: 1
    folder: 'Signal'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF
    
    success "Grafana provisioning configured"
}

setup_alertmanager() {
    log "Setting up AlertManager..."
    
    cat > "$MONITORING_DIR/alertmanager/alertmanager.yml" << EOF
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@signal.com'
  smtp_auth_username: 'alerts@signal.com'
  smtp_auth_password: 'app_password'

route:
  group_by: ['alertname', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'signal-alerts'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
      group_wait: 10s
      repeat_interval: 1h
    - match:
        severity: warning
      receiver: 'warning-alerts'
      repeat_interval: 6h

receivers:
  - name: 'signal-alerts'
    email_configs:
      - to: 'team@signal.com'
        subject: 'Signal Alert: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Labels: {{ range .Labels.SortedPairs }}{{ .Name }}={{ .Value }} {{ end }}
          {{ end }}
    
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#signal-alerts'
        title: 'Signal Production Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
  
  - name: 'critical-alerts'
    email_configs:
      - to: 'oncall@signal.com'
        subject: '🚨 CRITICAL: Signal Alert'
        body: |
          CRITICAL ALERT TRIGGERED
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          Service: {{ .Labels.service }}
          Time: {{ .StartsAt }}
          {{ end }}
    
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#signal-critical'
        title: '🚨 CRITICAL: Signal Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
        color: 'danger'
  
  - name: 'warning-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#signal-alerts'
        title: '⚠️ WARNING: Signal Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
        color: 'warning'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'service']
EOF
    
    success "AlertManager configuration created"
}

setup_elk() {
    log "Setting up ELK Stack..."
    
    # Create Elasticsearch configuration
    cat > "$MONITORING_DIR/elk/elasticsearch.yml" << EOF
cluster.name: signal-logs
node.name: signal-es-node-1
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node
xpack.security.enabled: false
xpack.monitoring.collection.enabled: true
EOF
    
    # Create Kibana configuration
    cat > "$MONITORING_DIR/elk/kibana.yml" << EOF
server.name: signal-kibana
server.host: 0.0.0.0
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
elasticsearch.pingTimeout: 1500
elasticsearch.requestTimeout: 30000
logging.level: info
EOF
    
    success "ELK Stack configuration created"
}

setup_volumes() {
    if [[ "$SKIP_VOLUMES" == "true" ]]; then
        log "Skipping volume creation"
        return
    fi
    
    log "Setting up Docker volumes..."
    
    if [[ "$CLEAN_DATA" == "true" ]]; then
        warning "Cleaning existing monitoring data..."
        docker volume rm signal_prometheus_data signal_grafana_data signal_alertmanager_data signal_elasticsearch_data signal_loki_data 2>/dev/null || true
    fi
    
    # Create volumes
    docker volume create signal_prometheus_data
    docker volume create signal_grafana_data
    docker volume create signal_alertmanager_data
    docker volume create signal_elasticsearch_data
    docker volume create signal_loki_data
    
    success "Docker volumes created"
}

start_monitoring_stack() {
    log "Starting monitoring stack ($STACK_TYPE)..."
    
    cd "$MONITORING_DIR"
    
    case $STACK_TYPE in
        "prometheus")
            docker-compose -f docker-compose.monitoring.yml up -d prometheus alertmanager node-exporter
            ;;
        "grafana")
            docker-compose -f docker-compose.monitoring.yml up -d grafana prometheus
            ;;
        "elk")
            docker-compose -f docker-compose.monitoring.yml up -d elasticsearch kibana logstash
            ;;
        "full")
            docker-compose -f docker-compose.monitoring.yml up -d
            ;;
        *)
            error "Unknown stack type: $STACK_TYPE"
            exit 1
            ;;
    esac
    
    success "Monitoring stack started"
}

wait_for_services() {
    log "Waiting for services to be ready..."
    
    case $STACK_TYPE in
        "prometheus"|"full")
            log "Waiting for Prometheus..."
            timeout 300 bash -c 'until curl -f http://localhost:9090/-/ready; do sleep 5; done'
            success "Prometheus is ready"
            ;;
    esac
    
    case $STACK_TYPE in
        "grafana"|"full")
            log "Waiting for Grafana..."
            timeout 300 bash -c 'until curl -f http://localhost:3000/api/health; do sleep 5; done'
            success "Grafana is ready"
            ;;
    esac
    
    case $STACK_TYPE in
        "elk"|"full")
            log "Waiting for Elasticsearch..."
            timeout 300 bash -c 'until curl -f http://localhost:9200/_cluster/health; do sleep 10; done'
            success "Elasticsearch is ready"
            
            log "Waiting for Kibana..."
            timeout 300 bash -c 'until curl -f http://localhost:5601/api/status; do sleep 10; done'
            success "Kibana is ready"
            ;;
    esac
}

import_dashboards() {
    if [[ "$STACK_TYPE" != "grafana" && "$STACK_TYPE" != "full" ]]; then
        return
    fi
    
    log "Importing Grafana dashboards..."
    
    # Wait a bit more for Grafana to be fully ready
    sleep 30
    
    # Import Signal overview dashboard
    if [[ -f "$MONITORING_DIR/grafana/signal-overview-dashboard.json" ]]; then
        curl -X POST \
            -H "Content-Type: application/json" \
            -d @"$MONITORING_DIR/grafana/signal-overview-dashboard.json" \
            http://admin:admin_password_change_me@localhost:3000/api/dashboards/db || warning "Failed to import Signal overview dashboard"
    fi
    
    success "Grafana dashboards imported"
}

setup_index_templates() {
    if [[ "$STACK_TYPE" != "elk" && "$STACK_TYPE" != "full" ]]; then
        return
    fi
    
    log "Setting up Elasticsearch index templates..."
    
    # Wait for Elasticsearch to be ready
    sleep 30
    
    # Create index template
    if [[ -f "$MONITORING_DIR/elk/elasticsearch-template.json" ]]; then
        curl -X PUT \
            -H "Content-Type: application/json" \
            -d @"$MONITORING_DIR/elk/elasticsearch-template.json" \
            "http://localhost:9200/_index_template/signal-logs" || warning "Failed to create index template"
    fi
    
    # Import Kibana dashboards
    if [[ -f "$MONITORING_DIR/elk/kibana-dashboard-export.ndjson" ]]; then
        curl -X POST \
            -H "Content-Type: application/json" \
            -H "kbn-xsrf: true" \
            --form file=@"$MONITORING_DIR/elk/kibana-dashboard-export.ndjson" \
            "http://localhost:5601/api/saved_objects/_import" || warning "Failed to import Kibana dashboards"
    fi
    
    success "Elasticsearch and Kibana configured"
}

print_access_info() {
    echo
    success "Monitoring stack setup completed!"
    echo
    log "Access Information:"
    
    case $STACK_TYPE in
        "prometheus"|"full")
            echo "📊 Prometheus: http://localhost:9090"
            echo "🚨 AlertManager: http://localhost:9093"
            ;;
    esac
    
    case $STACK_TYPE in
        "grafana"|"full")
            echo "📈 Grafana: http://localhost:3000 (admin/admin_password_change_me)"
            ;;
    esac
    
    case $STACK_TYPE in
        "elk"|"full")
            echo "🔍 Elasticsearch: http://localhost:9200"
            echo "📋 Kibana: http://localhost:5601"
            ;;
    esac
    
    echo
    log "Next Steps:"
    echo "1. Change default passwords"
    echo "2. Configure alert notifications (Slack, email)"
    echo "3. Customize dashboards for your needs"
    echo "4. Set up SSL/TLS for production"
    echo "5. Configure backup for monitoring data"
    echo
    
    warning "Remember to secure your monitoring stack before using in production!"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Signal Monitoring Stack Setup${NC}"
    echo "=================================="
    echo
    
    log "Configuration:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Stack Type: $STACK_TYPE"
    echo "  Data Retention: $DATA_RETENTION"
    echo "  Memory Limit: $MEMORY_LIMIT"
    echo "  Clean Data: $CLEAN_DATA"
    echo
    
    check_dependencies
    create_directories
    
    case $STACK_TYPE in
        "prometheus"|"full")
            setup_prometheus
            setup_alertmanager
            ;;
    esac
    
    case $STACK_TYPE in
        "grafana"|"full")
            setup_grafana
            ;;
    esac
    
    case $STACK_TYPE in
        "elk"|"full")
            setup_elk
            ;;
    esac
    
    setup_volumes
    start_monitoring_stack
    wait_for_services
    
    case $STACK_TYPE in
        "grafana"|"full")
            import_dashboards
            ;;
    esac
    
    case $STACK_TYPE in
        "elk"|"full")
            setup_index_templates
            ;;
    esac
    
    print_access_info
}

# Run main function
main