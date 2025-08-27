.PHONY: setup dev build test clean docker-up docker-down

# 환경 설정
setup:
	@echo "🚀 Setting up Signal development environment..."
	@cp -n be/.env.example be/.env 2>/dev/null || true
	@cp -n worker/.env.example worker/.env 2>/dev/null || true
	@cp -n scheduler/.env.example scheduler/.env 2>/dev/null || true
	@echo "✅ Environment files created. Please configure them."

# 개발 환경 실행
dev:
	@echo "🔄 Starting Signal services in development mode..."
	docker-compose -f docker-compose.dev.yml up --build

# 프로덕션 빌드
build:
	@echo "🏗️ Building Signal services..."
	docker-compose build

# 테스트 실행
test:
	@echo "🧪 Running tests..."
	cd be && go test ./...
	cd worker && go test ./...
	cd scheduler && go test ./...
	cd module && go test ./...

# 린터 실행
lint:
	@echo "🔍 Running linters..."
	cd be && golangci-lint run
	cd worker && golangci-lint run
	cd scheduler && golangci-lint run
	cd module && golangci-lint run

# 클린업
clean:
	@echo "🧹 Cleaning up..."
	docker-compose down -v
	docker system prune -f

# Docker 환경
docker-up:
	@echo "🐳 Starting Docker services..."
	docker-compose up -d

docker-down:
	@echo "🛑 Stopping Docker services..."
	docker-compose down

# 데이터베이스 마이그레이션
migrate-up:
	cd be && go run cmd/migrate/main.go up

migrate-down:
	cd be && go run cmd/migrate/main.go down

# 개발용 데이터 생성
seed:
	cd be && go run cmd/seed/main.go

# iOS 앱 실행
ios:
	cd ios && flutter run -d ios

# Android 앱 실행
android:
	cd android && ./gradlew installDebug