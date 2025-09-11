# Signal 프로덕션 배포 및 DevOps 가이드

## 🎯 배포 전략 개요

**목표**: 안정적이고 확장 가능한 Signal 플랫폼의 프로덕션 배포 및 운영

**접근법**: **Blue-Green Deployment** + **Container Orchestration** + **Infrastructure as Code**

---

## 🏗️ 인프라 아키텍처

### 클라우드 인프라 구성
```yaml
# AWS 기반 인프라 설계
Production_Infrastructure:
  Compute:
    - EKS (Kubernetes): Container orchestration
    - EC2 (t3.large): Worker nodes (3개 이상)
    - Auto Scaling Group: 동적 스케일링
    
  Database:
    - RDS PostgreSQL (Multi-AZ): 메인 데이터베이스
    - ElastiCache Redis: 캐시 및 세션 스토리지
    - S3: 파일 저장소 (이미지, 로그)
    
  Network:
    - VPC: 격리된 네트워크 환경
    - ALB: 로드 밸런서
    - CloudFront: CDN
    - Route53: DNS 관리
    
  Security:
    - IAM: 접근 권한 관리
    - Secrets Manager: 민감 정보 관리
    - WAF: 웹 애플리케이션 방화벽
    - Certificate Manager: SSL/TLS 인증서
```

### Kubernetes 클러스터 구성
```yaml
# EKS 클러스터 설정
apiVersion: v1
kind: Namespace
metadata:
  name: signal-prod

---
# Backend Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: signal-backend
  namespace: signal-prod
spec:
  replicas: 3
  selector:
    matchLabels:
      app: signal-backend
  template:
    metadata:
      labels:
        app: signal-backend
    spec:
      containers:
      - name: backend
        image: signal/backend:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: signal-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: signal-secrets
              key: redis-url
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 30

---
# Backend Service
apiVersion: v1
kind: Service
metadata:
  name: signal-backend-service
  namespace: signal-prod
spec:
  selector:
    app: signal-backend
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP

---
# WebSocket Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: signal-websocket
  namespace: signal-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: signal-websocket
  template:
    metadata:
      labels:
        app: signal-websocket
    spec:
      containers:
      - name: websocket
        image: signal/websocket:latest
        ports:
        - containerPort: 8081
        env:
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: signal-secrets
              key: redis-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

---

## 🚀 CI/CD 파이프라인

### GitHub Actions 워크플로
```yaml
name: Signal Production Deploy
on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]

env:
  AWS_REGION: ap-northeast-2
  EKS_CLUSTER_NAME: signal-prod
  ECR_REPOSITORY: signal

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgis/postgis:13-3.1
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Go
      uses: actions/setup-go@v3
      with:
        go-version: 1.21
    
    - name: Run Backend Tests
      run: |
        cd be
        go test -v ./... -race -coverprofile=coverage.out
        go tool cover -html=coverage.out -o coverage.html
    
    - name: Set up Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
    
    - name: Run iOS Tests
      run: |
        cd ios
        flutter test
        flutter analyze
    
    - name: Run Android Tests
      run: |
        cd android
        ./gradlew test
        ./gradlew lint

  security_scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Run CodeQL Analysis
      uses: github/codeql-action/init@v2
      with:
        languages: go, java, javascript

  build:
    needs: [test, security_scan]
    runs-on: ubuntu-latest
    outputs:
      backend_image: ${{ steps.backend.outputs.image }}
      websocket_image: ${{ steps.websocket.outputs.image }}
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build and push backend image
      id: backend
      run: |
        IMAGE_TAG=${GITHUB_SHA::7}
        IMAGE_URI=${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:backend-$IMAGE_TAG
        docker build -t $IMAGE_URI -f be/Dockerfile be/
        docker push $IMAGE_URI
        echo "image=$IMAGE_URI" >> $GITHUB_OUTPUT
    
    - name: Build and push WebSocket image
      id: websocket
      run: |
        IMAGE_TAG=${GITHUB_SHA::7}
        IMAGE_URI=${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:websocket-$IMAGE_TAG
        docker build -t $IMAGE_URI -f be/Dockerfile.websocket be/
        docker push $IMAGE_URI
        echo "image=$IMAGE_URI" >> $GITHUB_OUTPUT

  deploy_staging:
    needs: build
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Update kubeconfig
      run: |
        aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name signal-staging
    
    - name: Deploy to Staging
      run: |
        sed -i 's|signal/backend:latest|${{ needs.build.outputs.backend_image }}|g' k8s/staging/backend-deployment.yaml
        sed -i 's|signal/websocket:latest|${{ needs.build.outputs.websocket_image }}|g' k8s/staging/websocket-deployment.yaml
        kubectl apply -f k8s/staging/
    
    - name: Run Smoke Tests
      run: |
        sleep 60  # Wait for deployment
        ./scripts/smoke-tests.sh staging

  deploy_production:
    needs: [build, deploy_staging]
    runs-on: ubuntu-latest
    environment: production
    if: startsWith(github.ref, 'refs/tags/v')
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Update kubeconfig
      run: |
        aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.EKS_CLUSTER_NAME }}
    
    - name: Blue-Green Deployment
      run: |
        ./scripts/blue-green-deploy.sh \
          "${{ needs.build.outputs.backend_image }}" \
          "${{ needs.build.outputs.websocket_image }}"
    
    - name: Health Check
      run: |
        ./scripts/health-check.sh production
    
    - name: Rollback on Failure
      if: failure()
      run: |
        ./scripts/rollback.sh

  mobile_deploy:
    needs: [test]
    runs-on: macos-latest
    if: startsWith(github.ref, 'refs/tags/v')
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
    
    - name: Build iOS App
      run: |
        cd ios
        flutter build ipa --release
    
    - name: Upload to TestFlight
      uses: apple-actions/upload-testflight-build@v1
      with:
        app-path: ios/build/ios/ipa/signal.ipa
        issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
        api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
        api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}
    
    - name: Build Android App
      run: |
        cd android
        flutter build appbundle --release
    
    - name: Upload to Play Console
      uses: r0adkll/upload-google-play@v1
      with:
        serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
        packageName: com.signal.app
        releaseFiles: android/build/app/outputs/bundle/release/app-release.aab
        track: internal
```

---

## 🔧 Infrastructure as Code

### Terraform 설정
```hcl
# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  
  backend "s3" {
    bucket = "signal-terraform-state"
    key    = "production/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC 설정
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "signal-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  
  tags = {
    Environment = "production"
    Project     = "signal"
  }
}

# EKS 클러스터
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = "signal-prod"
  cluster_version = "1.27"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  node_groups = {
    main = {
      desired_capacity = 3
      max_capacity     = 10
      min_capacity     = 3
      
      instance_types = ["t3.large"]
      
      k8s_labels = {
        Environment = "production"
        Application = "signal"
      }
    }
  }
  
  tags = {
    Environment = "production"
    Project     = "signal"
  }
}

# RDS PostgreSQL
resource "aws_db_instance" "signal_db" {
  identifier = "signal-prod-db"
  
  engine         = "postgres"
  engine_version = "13.7"
  instance_class = "db.t3.medium"
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  
  db_name  = "signal"
  username = "signal_user"
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.signal.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Sun:04:00-Sun:05:00"
  
  multi_az = true
  
  tags = {
    Environment = "production"
    Project     = "signal"
  }
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "signal" {
  name       = "signal-cache-subnet"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_replication_group" "signal_redis" {
  replication_group_id         = "signal-redis"
  description                  = "Redis cluster for Signal"
  port                        = 6379
  parameter_group_name        = "default.redis6.x"
  node_type                   = "cache.t3.medium"
  num_cache_clusters          = 2
  
  subnet_group_name = aws_elasticache_subnet_group.signal.name
  security_group_ids = [aws_security_group.redis.id]
  
  tags = {
    Environment = "production"
    Project     = "signal"
  }
}

# Application Load Balancer
resource "aws_lb" "signal" {
  name               = "signal-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets
  
  enable_deletion_protection = false
  
  tags = {
    Environment = "production"
    Project     = "signal"
  }
}
```

---

## 📊 모니터링 및 로깅

### Prometheus + Grafana 설정
```yaml
# prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      
    scrape_configs:
    - job_name: 'signal-backend'
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names: ['signal-prod']
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: signal-backend-service
        
    - job_name: 'signal-websocket'
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names: ['signal-prod']
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: signal-websocket-service

    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

---
# Grafana Dashboard
apiVersion: v1
kind: ConfigMap
metadata:
  name: signal-dashboard
  namespace: monitoring
data:
  signal-dashboard.json: |
    {
      "dashboard": {
        "title": "Signal Production Metrics",
        "panels": [
          {
            "title": "API Response Time",
            "type": "stat",
            "targets": [{
              "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
            }]
          },
          {
            "title": "WebSocket Connections",
            "type": "graph",
            "targets": [{
              "expr": "websocket_connections_active"
            }]
          },
          {
            "title": "Database Connections",
            "type": "stat",
            "targets": [{
              "expr": "db_connections_active"
            }]
          },
          {
            "title": "Error Rate",
            "type": "stat",
            "targets": [{
              "expr": "rate(http_requests_total{status=~\"5..\"}[5m])"
            }]
          }
        ]
      }
    }
```

### ELK Stack 로깅
```yaml
# elasticsearch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticsearch
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.17.0
        ports:
        - containerPort: 9200
        env:
        - name: discovery.type
          value: single-node
        - name: ES_JAVA_OPTS
          value: "-Xms512m -Xmx512m"

---
# logstash.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logstash
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logstash
  template:
    metadata:
      labels:
        app: logstash
    spec:
      containers:
      - name: logstash
        image: docker.elastic.co/logstash/logstash:7.17.0
        ports:
        - containerPort: 5044
        volumeMounts:
        - name: logstash-config
          mountPath: /usr/share/logstash/pipeline
      volumes:
      - name: logstash-config
        configMap:
          name: logstash-config

---
# kibana.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:7.17.0
        ports:
        - containerPort: 5601
        env:
        - name: ELASTICSEARCH_HOSTS
          value: "http://elasticsearch:9200"
```

---

## 🚨 알림 및 장애 대응

### AlertManager 설정
```yaml
# alertmanager-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      slack_api_url: '${{ secrets.SLACK_WEBHOOK_URL }}'
      
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'signal-alerts'
      
    receivers:
    - name: 'signal-alerts'
      slack_configs:
      - channel: '#signal-alerts'
        title: 'Signal Production Alert'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Severity:* {{ .Labels.severity }}
          {{ end }}

---
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: signal-alerts
  namespace: monitoring
spec:
  groups:
  - name: signal.rules
    rules:
    - alert: HighResponseTime
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High response time detected"
        description: "95th percentile response time is {{ $value }}s"
        
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} requests/second"
        
    - alert: DatabaseConnectionHigh
      expr: db_connections_active > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Database connection pool utilization high"
        description: "{{ $value }} active connections"
        
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} is restarting frequently"
```

---

## 🔐 보안 설정

### Network Security
```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: signal-network-policy
  namespace: signal-prod
spec:
  podSelector:
    matchLabels:
      app: signal-backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  - from:
    - podSelector:
        matchLabels:
          app: signal-websocket
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 6379  # Redis
  - to: []
    ports:
    - protocol: TCP
      port: 443   # HTTPS
    - protocol: TCP
      port: 53    # DNS
    - protocol: UDP
      port: 53    # DNS
```

### Secret Management
```yaml
# sealed-secrets.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: signal-secrets
  namespace: signal-prod
spec:
  encryptedData:
    database-url: "encrypted-database-url"
    redis-url: "encrypted-redis-url"
    jwt-secret: "encrypted-jwt-secret"
    s3-access-key: "encrypted-s3-key"
    s3-secret-key: "encrypted-s3-secret"
```

---

## 📈 스케일링 전략

### Horizontal Pod Autoscaler
```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: signal-backend-hpa
  namespace: signal-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: signal-backend
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80

---
# Cluster Autoscaler
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/signal-prod
```

---

## 🔄 백업 및 복구

### 데이터베이스 백업
```bash
#!/bin/bash
# backup-database.sh

# 환경 변수 설정
DB_HOST="signal-prod-db.xxx.ap-northeast-2.rds.amazonaws.com"
DB_NAME="signal"
DB_USER="signal_user"
BACKUP_S3_BUCKET="signal-backups"
DATE=$(date +%Y%m%d_%H%M%S)

# PostgreSQL 백업
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME --no-password | gzip > "signal_backup_${DATE}.sql.gz"

# S3 업로드
aws s3 cp "signal_backup_${DATE}.sql.gz" "s3://${BACKUP_S3_BUCKET}/database/"

# 로컬 백업 파일 정리 (7일 이상된 파일 삭제)
find /backup/database -name "signal_backup_*.sql.gz" -mtime +7 -delete

echo "Database backup completed: signal_backup_${DATE}.sql.gz"
```

### Redis 백업
```bash
#!/bin/bash
# backup-redis.sh

REDIS_HOST="signal-redis.xxx.cache.amazonaws.com"
REDIS_PORT=6379
BACKUP_S3_BUCKET="signal-backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Redis RDB 백업
redis-cli -h $REDIS_HOST -p $REDIS_PORT --rdb "redis_backup_${DATE}.rdb"

# S3 업로드
aws s3 cp "redis_backup_${DATE}.rdb" "s3://${BACKUP_S3_BUCKET}/redis/"

# 로컬 백업 파일 정리
find /backup/redis -name "redis_backup_*.rdb" -mtime +3 -delete

echo "Redis backup completed: redis_backup_${DATE}.rdb"
```

### 복구 스크립트
```bash
#!/bin/bash
# restore-database.sh

if [ $# -ne 1 ]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

BACKUP_FILE=$1
DB_HOST="signal-prod-db.xxx.ap-northeast-2.rds.amazonaws.com"
DB_NAME="signal"
DB_USER="signal_user"

echo "Restoring database from $BACKUP_FILE"
echo "WARNING: This will overwrite the current database!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    # 백업에서 복구
    gunzip -c "$BACKUP_FILE" | psql -h $DB_HOST -U $DB_USER -d $DB_NAME
    echo "Database restored successfully"
else
    echo "Restore cancelled"
fi
```

---

## 📋 배포 체크리스트

### 프로덕션 배포 전 체크리스트
```markdown
## 배포 전 준비사항
- [ ] 모든 테스트 통과 확인
- [ ] 보안 스캔 결과 확인
- [ ] 성능 테스트 결과 검토
- [ ] 데이터베이스 마이그레이션 준비
- [ ] 백업 시스템 작동 확인
- [ ] 모니터링 대시보드 설정
- [ ] 알람 시스템 테스트

## 배포 과정
- [ ] Blue-Green 환경 준비
- [ ] 트래픽 차단 설정
- [ ] 새 버전 배포
- [ ] 헬스체크 통과 확인
- [ ] 스모크 테스트 실행
- [ ] 트래픽 점진적 전환
- [ ] 모니터링 지표 확인

## 배포 후 확인사항
- [ ] 모든 API 엔드포인트 정상 작동
- [ ] WebSocket 연결 정상
- [ ] 데이터베이스 연결 정상
- [ ] 로그 수집 정상
- [ ] 알람 시스템 정상
- [ ] 사용자 트래픽 정상
- [ ] 롤백 계획 준비
```

---

## 🎯 운영 매뉴얼

### 일상 운영 작업
```bash
# 일일 헬스체크
kubectl get pods -n signal-prod
kubectl top nodes
kubectl top pods -n signal-prod

# 로그 확인
kubectl logs -f deployment/signal-backend -n signal-prod
kubectl logs -f deployment/signal-websocket -n signal-prod

# 데이터베이스 상태 확인
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT count(*) FROM users;"
redis-cli -h $REDIS_HOST -p 6379 info memory

# 백업 상태 확인
aws s3 ls s3://signal-backups/database/ --human-readable
aws s3 ls s3://signal-backups/redis/ --human-readable
```

### 장애 대응 절차
```markdown
## 1. 서비스 장애 감지
- Slack 알림 수신
- Grafana 대시보드 확인
- 장애 범위 파악

## 2. 긴급 대응
- 트래픽 차단 또는 우회
- 롤백 실행 (필요시)
- 스케일 업 (부하 급증시)

## 3. 원인 분석
- 로그 분석
- 메트릭 분석
- 에러 트래킹

## 4. 복구 작업
- 근본 원인 수정
- 테스트 실행
- 점진적 트래픽 복구

## 5. 사후 검토
- 장애 보고서 작성
- 개선사항 도출
- 모니터링 강화
```

---

**🚀 이 DevOps 가이드를 통해 Signal 플랫폼의 안정적이고 확장 가능한 프로덕션 운영을 보장합니다! 🎯**