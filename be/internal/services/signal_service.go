package services

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"signal-be/internal/repositories"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/queue"
	"signal-module/pkg/redis"
	"signal-module/pkg/utils"
)

type SignalServiceInterface interface {
	CreateSignal(creatorID uint, req *models.CreateSignalRequest) (*models.Signal, error)
	GetSignal(signalID uint) (*models.Signal, error)
	SearchSignals(req *models.SearchSignalRequest) ([]models.SignalWithDistance, *utils.Pagination, error)
	JoinSignal(signalID, userID uint, req *models.JoinSignalRequest) error
	LeaveSignal(signalID, userID uint) error
	ApproveParticipant(signalID, creatorID, userID uint) error
	RejectParticipant(signalID, creatorID, userID uint) error
	GetMySignals(userID uint, page, limit int) ([]models.Signal, *utils.Pagination, error)
	GetNearbySignals(lat, lon, radius float64, categories []models.InterestCategory) ([]models.SignalWithDistance, error)
}

type SignalService struct {
	signalRepo      repositories.SignalRepositoryInterface
	userRepo        repositories.UserRepositoryInterface
	redisClient     *redis.Client
	queue           *queue.Queue
	logger          *logger.Logger
	websocketService *WebSocketService
	chatService     *ChatService
}

func NewSignalService(
	signalRepo repositories.SignalRepositoryInterface,
	userRepo repositories.UserRepositoryInterface,
	redisClient *redis.Client,
	queue *queue.Queue,
	logger *logger.Logger,
	websocketService *WebSocketService,
	chatService *ChatService,
) SignalServiceInterface {
	service := &SignalService{
		signalRepo:       signalRepo,
		userRepo:         userRepo,
		redisClient:      redisClient,
		queue:            queue,
		logger:           logger,
		websocketService: websocketService,
		chatService:      chatService,
	}
	
	// 서비스 시작 시 활성 시그널들을 캐시에 로드
	go service.initializeSignalCache()
	
	return service
}

func (s *SignalService) CreateSignal(creatorID uint, req *models.CreateSignalRequest) (*models.Signal, error) {
	ctx := context.Background()

	// 1. 사용자 권한 및 자격 확인
	user, err := s.userRepo.GetByID(creatorID)
	if err != nil {
		return nil, fmt.Errorf("사용자 정보를 찾을 수 없습니다")
	}

	if !user.IsActive {
		return nil, fmt.Errorf("비활성 사용자는 시그널을 생성할 수 없습니다")
	}

	// Enhanced manner score validation with detailed feedback
	if user.Profile != nil {
		if user.Profile.MannerScore < 32.0 {
			return nil, fmt.Errorf("매너 점수가 부족하여 시그널을 생성할 수 없습니다 (현재: %.1f점, 최소: 32.0점)", user.Profile.MannerScore)
		}
		// Additional validation for high-quality signals
		if user.Profile.MannerScore >= 80.0 {
			s.logger.Info(fmt.Sprintf("고품질 사용자 시그널 생성: 사용자 %d, 매너점수 %.1f", creatorID, user.Profile.MannerScore))
		}
	} else {
		return nil, fmt.Errorf("프로필 정보가 완성되지 않아 시그널을 생성할 수 없습니다")
	}

	// 2. 시간 유효성 검사
	now := time.Now()
	if req.ScheduledAt.Before(now.Add(10 * time.Minute)) {
		return nil, fmt.Errorf("최소 10분 후 시간으로 설정해야 합니다")
	}

	if req.ScheduledAt.After(now.Add(168 * time.Hour)) { // 1주일
		return nil, fmt.Errorf("1주일 이후의 시그널은 생성할 수 없습니다")
	}

	// 3. 위치 유효성 검사
	if !utils.IsValidCoordinate(req.Latitude, req.Longitude) {
		return nil, fmt.Errorf("유효하지 않은 좌표입니다")
	}

	// 한국 내 위치인지 확인 (대략적)
	if !utils.IsWithinKorea(req.Latitude, req.Longitude) {
		return nil, fmt.Errorf("한국 내 위치만 지원됩니다")
	}

	// 4. Enhanced rate limiting with dynamic limits based on manner score
	dailyCount, err := s.signalRepo.GetDailySignalCount(creatorID, now)
	if err != nil {
		return nil, fmt.Errorf("일일 시그널 생성 횟수 확인 실패")
	}
	
	// Dynamic daily limit based on manner score
	dailyLimit := 5 // Base limit
	if user.Profile.MannerScore >= 50.0 {
		dailyLimit = 8
	}
	if user.Profile.MannerScore >= 70.0 {
		dailyLimit = 12
	}
	if user.Profile.MannerScore >= 90.0 {
		dailyLimit = 20
	}
	
	if dailyCount >= int64(dailyLimit) {
		return nil, fmt.Errorf("일일 시그널 생성 한도에 도달했습니다 (%d/%d)", dailyCount, dailyLimit)
	}
	
	// Additional hourly rate limiting for new users
	if user.Profile.MannerScore < 40.0 {
		hourlyCount, err := s.signalRepo.GetHourlySignalCount(creatorID, now)
		if err == nil && hourlyCount >= 2 {
			return nil, fmt.Errorf("시간당 시그널 생성 한도에 도달했습니다 (신규 사용자: 2개/시간)")
		}
	}

	// 5. 동일 위치/시간대 중복 시그널 확인
	exists, err := s.signalRepo.CheckDuplicateSignal(creatorID, req.Latitude, req.Longitude, req.ScheduledAt)
	if err != nil {
		return nil, fmt.Errorf("중복 시그널 확인 실패")
	}
	if exists {
		return nil, fmt.Errorf("같은 위치와 시간대에 이미 시그널이 있습니다")
	}

	// 6. 카테고리 및 설정 유효성 검사
	if err := s.validateSignalSettings(req); err != nil {
		return nil, err
	}

	// 만료 시간 설정 (예정 시간 + 2시간)
	expiresAt := req.ScheduledAt.Add(2 * time.Hour)

	signal := &models.Signal{
		CreatorID:           creatorID,
		Title:              req.Title,
		Description:        req.Description,
		Category:           req.Category,
		Latitude:           req.Latitude,
		Longitude:          req.Longitude,
		Address:            req.Address,
		PlaceName:          req.PlaceName,
		ScheduledAt:        req.ScheduledAt,
		ExpiresAt:          expiresAt,
		MaxParticipants:    req.MaxParticipants,
		CurrentParticipants: 1, // 생성자 포함
		MinAge:             req.MinAge,
		MaxAge:             req.MaxAge,
		AllowInstantJoin:   req.AllowInstantJoin,
		RequireApproval:    req.RequireApproval,
		GenderPreference:   req.GenderPreference,
		Status:             models.SignalActive,
	}

	// 7. 트랜잭션으로 시그널 생성
	if err := s.signalRepo.CreateWithTransaction(func(tx interface{}) error {
		if err := s.signalRepo.CreateTx(tx, signal); err != nil {
			return err
		}

		// 생성자를 자동으로 참여자로 추가
		participant := &models.SignalParticipant{
			SignalID: signal.ID,
			UserID:   creatorID,
			Status:   models.ParticipantApproved,
			Message:  "시그널 생성자",
		}
		now := time.Now()
		participant.JoinedAt = &now

		return s.signalRepo.CreateParticipantTx(tx, participant)
	}); err != nil {
		s.logger.Error("시그널 생성 트랜잭션 실패", err)
		return nil, fmt.Errorf("시그널 생성에 실패했습니다")
	}

	// 8. Redis에 활성 시그널 등록
	if err := s.redisClient.AddActiveSignal(ctx, signal.ID, signal.Latitude, signal.Longitude); err != nil {
		s.logger.Warn(fmt.Sprintf("Redis 시그널 등록 실패: %v", err))
	}

	// 9. 시그널 만료 작업 스케줄링
	if err := s.queue.ScheduleSignalExpiration(ctx, signal.ID, expiresAt); err != nil {
		s.logger.Warn(fmt.Sprintf("시그널 만료 스케줄링 실패: %v", err))
	}

	// 10. 시그널 시작 알림 스케줄링 (30분 전) - TODO: 큐 서비스에서 구현 예정
	notifyTime := req.ScheduledAt.Add(-30 * time.Minute)
	if notifyTime.After(now) {
		s.logger.Info(fmt.Sprintf("시그널 %d 알림이 %v에 스케줄링됩니다", signal.ID, notifyTime))
	}

	// 11. 채팅방 자동 생성
	go func() {
		if err := s.createSignalChatRoom(signal.ID); err != nil {
			s.logger.Error("채팅방 생성 실패", err)
		}
	}()

	// 12. Redis GEO 캐시에 추가
	if err := s.AddSignalToGeoCache(*signal); err != nil {
		s.logger.Error("시그널 GEO 캐시 추가 실패", err)
	}

	// 13. 근처 시그널 캐시 무효화 (주변 위치의 캐시들)
	go s.invalidateNearbyCache(signal.Latitude, signal.Longitude)

	// 14. 실시간 시그널 업데이트 브로드캐스트
	go s.broadcastSignalUpdate(signal, "new_signal")

	// 15. 주변 사용자들에게 푸시 알림 발송 (매칭 기반)
	go s.notifyMatchedUsers(signal)

	s.logger.LogSignalCreated(ctx, signal.ID, creatorID)

	return signal, nil
}

func (s *SignalService) GetSignal(signalID uint) (*models.Signal, error) {
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return nil, fmt.Errorf("시그널을 찾을 수 없습니다")
	}
	return signal, nil
}

func (s *SignalService) SearchSignals(req *models.SearchSignalRequest) ([]models.SignalWithDistance, *utils.Pagination, error) {
	// 기본값 설정
	if req.Page <= 0 {
		req.Page = 1
	}
	if req.Limit <= 0 {
		req.Limit = 20
	}
	if req.Radius == 0 {
		req.Radius = 5000 // 기본 5km
	}

	signals, total, err := s.signalRepo.Search(req)
	if err != nil {
		s.logger.Error("시그널 검색 실패", err)
		return nil, nil, fmt.Errorf("시그널 검색에 실패했습니다")
	}

	pagination := utils.CalculatePagination(req.Page, req.Limit, total)

	return signals, &pagination, nil
}

func (s *SignalService) JoinSignal(signalID, userID uint, req *models.JoinSignalRequest) error {
	ctx := context.Background()

	// 1. 시그널 정보 조회
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	// 2. 사용자 정보 조회 및 자격 확인
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return fmt.Errorf("사용자 정보를 찾을 수 없습니다")
	}

	if !user.IsActive {
		return fmt.Errorf("비활성 사용자는 시그널에 참여할 수 없습니다")
	}

	// Enhanced manner score validation
	if user.Profile != nil {
		minMannerScore := 30.0
		if signal.Category == "study" || signal.Category == "culture" {
			minMannerScore = 35.0 // Higher requirements for quality activities
		}
		if user.Profile.MannerScore < minMannerScore {
			return fmt.Errorf("매너 점수가 부족하여 참여할 수 없습니다 (현재: %.1f점, 필요: %.1f점)", 
				user.Profile.MannerScore, minMannerScore)
		}
	}

	// 3. 시그널 참여 가능 여부 검사
	if signal.Status != models.SignalActive {
		return fmt.Errorf("참여할 수 없는 시그널입니다")
	}

	if signal.CreatorID == userID {
		return fmt.Errorf("자신이 생성한 시그널에는 참여할 수 없습니다")
	}

	if signal.CurrentParticipants >= signal.MaxParticipants {
		return fmt.Errorf("정원이 마감되었습니다")
	}

	// 시그널 시작 시간이 지났는지 확인
	if time.Now().After(signal.ScheduledAt) {
		return fmt.Errorf("이미 시작된 시그널입니다")
	}

	// 4. 사용자 자격 확인 (연령, 성별)
	if err := s.validateUserEligibility(user, signal); err != nil {
		return err
	}

	// 5. 이미 참여했는지 확인
	participants, err := s.signalRepo.GetParticipants(signalID)
	if err != nil {
		return fmt.Errorf("참여자 조회에 실패했습니다")
	}

	for _, p := range participants {
		if p.UserID == userID {
			switch p.Status {
			case models.ParticipantApproved:
				return fmt.Errorf("이미 승인된 참여자입니다")
			case models.ParticipantPending:
				return fmt.Errorf("이미 참여 요청을 보냈습니다")
			case models.ParticipantRejected:
				// 거절된 경우 24시간 후 재신청 가능
				if time.Since(p.UpdatedAt) < 24*time.Hour {
					return fmt.Errorf("거절된 후 24시간 후에 재신청 가능합니다")
				}
			}
		}
	}

	// 6. 일일 참여 제한 확인 (하루 최대 10개)
	dailyJoinCount, err := s.signalRepo.GetDailyJoinCount(userID, time.Now())
	if err != nil {
		return fmt.Errorf("일일 참여 횟수 확인 실패")
	}
	if dailyJoinCount >= 10 {
		return fmt.Errorf("하루에 최대 10개의 시그널에만 참여할 수 있습니다")
	}

	// 7. 참여 상태 결정
	status := models.ParticipantPending
	if signal.AllowInstantJoin && !signal.RequireApproval {
		status = models.ParticipantApproved
	}

	// 8. 참여자 생성
	participant := &models.SignalParticipant{
		SignalID: signalID,
		UserID:   userID,
		Status:   status,
		Message:  req.Message,
	}

	if status == models.ParticipantApproved {
		now := time.Now()
		participant.JoinedAt = &now
	}

	// 9. 데이터베이스에 저장
	if err := s.signalRepo.JoinSignal(participant); err != nil {
		s.logger.Error("시그널 참여 실패", err)
		return fmt.Errorf("시그널 참여에 실패했습니다")
	}

	// 10. 승인된 경우 즉시 채팅방 초대
	if status == models.ParticipantApproved {
		go func() {
			if err := s.inviteUserToChatRoom(signalID, userID); err != nil {
				s.logger.Error("채팅방 초대 실패", err)
			}
		}()
	}

	// 11. Enhanced notification system with preferences
	go func() {
		if status == models.ParticipantPending {
			s.notifyCreatorOfJoinRequest(signal.CreatorID, signal, user)
			// Auto-notification for high-priority signals
			if signal.Category == "emergency" || signal.ScheduledAt.Sub(time.Now()) <= 30*time.Minute {
				s.notifyUrgentJoinRequest(signal.CreatorID, signal, user)
			}
		} else {
			s.notifyCreatorOfJoinApproval(signal.CreatorID, signal, user)
			// Send welcome message to auto-approved participant
			s.sendWelcomeMessage(signalID, userID)
		}
	}()

	// 시그널 참여자 변경 실시간 알림
	go s.NotifySignalParticipantChange(signalID)

	s.logger.LogSignalJoined(ctx, signalID, userID)

	return nil
}

func (s *SignalService) LeaveSignal(signalID, userID uint) error {
	if err := s.signalRepo.LeaveSignal(signalID, userID); err != nil {
		s.logger.Error("시그널 나가기 실패", err)
		return fmt.Errorf("시그널 나가기에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("시그널 나가기: 사용자 %d, 시그널 %d", userID, signalID))

	return nil
}

func (s *SignalService) ApproveParticipant(signalID, creatorID, userID uint) error {
	// 생성자인지 확인
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	if signal.CreatorID != creatorID {
		return fmt.Errorf("시그널 생성자만 승인할 수 있습니다")
	}

	if err := s.signalRepo.UpdateParticipantStatus(signalID, userID, models.ParticipantApproved); err != nil {
		s.logger.Error("참여자 승인 실패", err)
		return fmt.Errorf("참여자 승인에 실패했습니다")
	}

	// 첫 번째 참여자 승인 시 채팅방 자동 생성
	go func() {
		if err := s.createSignalChatRoom(signalID); err != nil {
			s.logger.Error("첫 참여자 승인 후 채팅방 생성 실패", err)
		}
	}()

	// 시그널 참여자 변경 실시간 알림
	go s.NotifySignalParticipantChange(signalID)

	s.logger.Info(fmt.Sprintf("참여자 승인: 시그널 %d, 사용자 %d", signalID, userID))

	return nil
}

func (s *SignalService) GetMySignals(userID uint, page, limit int) ([]models.Signal, *utils.Pagination, error) {
	signals, total, err := s.signalRepo.GetByUserID(userID, nil, page, limit)
	if err != nil {
		s.logger.Error("내 시그널 조회 실패", err)
		return nil, nil, fmt.Errorf("시그널 조회에 실패했습니다")
	}

	pagination := utils.CalculatePagination(page, limit, total)

	return signals, &pagination, nil
}

func (s *SignalService) RejectParticipant(signalID, creatorID, userID uint) error {
	// 생성자인지 확인
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	if signal.CreatorID != creatorID {
		return fmt.Errorf("시그널 생성자만 거절할 수 있습니다")
	}

	if err := s.signalRepo.UpdateParticipantStatus(signalID, userID, models.ParticipantRejected); err != nil {
		s.logger.Error("참여자 거절 실패", err)
		return fmt.Errorf("참여자 거절에 실패했습니다")
	}

	s.logger.Info(fmt.Sprintf("참여자 거절: 시그널 %d, 사용자 %d", signalID, userID))

	return nil
}

func (s *SignalService) GetNearbySignals(lat, lon, radius float64, categories []models.InterestCategory) ([]models.SignalWithDistance, error) {
	// 유효성 검사
	if !utils.IsValidCoordinate(lat, lon) {
		return nil, fmt.Errorf("유효하지 않은 좌표입니다")
	}

	if radius <= 0 || radius > 50000 {
		return nil, fmt.Errorf("반경은 0보다 크고 50km 이하여야 합니다")
	}

	// Redis 캐시 키 생성 (좌표를 그리드로 반올림하여 캐시 효율성 증대)
	gridLat := s.roundToGrid(lat, 0.01) // 약 1km 그리드
	gridLon := s.roundToGrid(lon, 0.01)
	cacheKey := fmt.Sprintf("nearby_signals:%s:%s:%s", 
		strconv.FormatFloat(gridLat, 'f', -1, 64),
		strconv.FormatFloat(gridLon, 'f', -1, 64),
		strconv.FormatFloat(radius, 'f', -1, 64))

	// Redis에서 캐시된 데이터 조회
	ctx := context.Background()
	cachedData, err := s.redisClient.Get(ctx, cacheKey)
	if err == nil {
		var cachedSignals []models.SignalWithDistance
		if err := json.Unmarshal([]byte(cachedData), &cachedSignals); err == nil {
			s.logger.Info(fmt.Sprintf("Redis 캐시에서 근처 시그널 조회: %d개", len(cachedSignals)))
			return s.filterSignalsByCategory(cachedSignals, categories), nil
		}
	}

	// 캐시 미스 - 데이터베이스에서 조회
	dbSignals, err := s.signalRepo.GetActiveSignalsInRadius(lat, lon, radius)
	if err != nil {
		s.logger.Error("근처 시그널 데이터베이스 조회 실패", err)
		return nil, fmt.Errorf("근처 시그널 조회에 실패했습니다")
	}

	var signals []models.SignalWithDistance

	// 거리 계산하여 SignalWithDistance로 변환
	for _, signal := range dbSignals {
		distance := utils.CalculateDistance(lat, lon, signal.Latitude, signal.Longitude)
		signals = append(signals, models.SignalWithDistance{
			Signal:   signal,
			Distance: distance,
		})
	}

	// Redis에 캐시 저장 (5분 TTL)
	if signalsJSON, err := json.Marshal(signals); err == nil {
		s.redisClient.Set(ctx, cacheKey, signalsJSON, 5*time.Minute)
		s.logger.Info(fmt.Sprintf("근처 시그널을 Redis에 캐시 저장: %d개", len(signals)))
	}

	return s.filterSignalsByCategory(signals, categories), nil
}

// roundToGrid rounds coordinates to grid boundaries for cache efficiency
func (s *SignalService) roundToGrid(coord, gridSize float64) float64 {
	return float64(int(coord/gridSize)) * gridSize
}

// filterSignalsByCategory filters signals by categories if provided
func (s *SignalService) filterSignalsByCategory(signals []models.SignalWithDistance, categories []models.InterestCategory) []models.SignalWithDistance {
	if len(categories) == 0 {
		return signals
	}

	filteredSignals := []models.SignalWithDistance{}
	categorySet := make(map[models.InterestCategory]bool)
	for _, cat := range categories {
		categorySet[cat] = true
	}

	for _, signal := range signals {
		if categorySet[signal.Category] {
			filteredSignals = append(filteredSignals, signal)
		}
	}
	return filteredSignals
}

// invalidateNearbyCache invalidates nearby signal cache for a location
func (s *SignalService) invalidateNearbyCache(lat, lon float64) {
	ctx := context.Background()
	// 주변 그리드들의 캐시 무효화 (현재 그리드 + 인접 그리드들)
	gridSize := 0.01
	for dlat := -1.0; dlat <= 1.0; dlat++ {
		for dlon := -1.0; dlon <= 1.0; dlon++ {
			gridLat := s.roundToGrid(lat, gridSize) + dlat*gridSize
			gridLon := s.roundToGrid(lon, gridSize) + dlon*gridSize
			
			// 다양한 반경에 대한 캐시 키들 무효화
			radiuses := []float64{1000, 3000, 5000, 10000}
			for _, radius := range radiuses {
				cacheKey := fmt.Sprintf("nearby_signals:%s:%s:%s",
					strconv.FormatFloat(gridLat, 'f', -1, 64),
					strconv.FormatFloat(gridLon, 'f', -1, 64),
					strconv.FormatFloat(radius, 'f', -1, 64))
				s.redisClient.Delete(ctx, cacheKey)
			}
		}
	}
	s.logger.Info("근처 시그널 캐시 무효화 완료")
}

// validateSignalSettings 시그널 설정 유효성 검사
func (s *SignalService) validateSignalSettings(req *models.CreateSignalRequest) error {
	// 제목 길이 확인
	if len(req.Title) < 5 || len(req.Title) > 100 {
		return fmt.Errorf("제목은 5자 이상 100자 이하로 입력해주세요")
	}

	// 설명 길이 확인
	if len(req.Description) > 500 {
		return fmt.Errorf("설명은 500자 이하로 입력해주세요")
	}

	// 참여자 수 확인
	if req.MaxParticipants < 2 || req.MaxParticipants > 20 {
		return fmt.Errorf("참여자 수는 2명 이상 20명 이하로 설정해주세요")
	}

	// 연령대 확인
	if req.MinAge > 0 && req.MaxAge > 0 {
		if req.MinAge > req.MaxAge {
			return fmt.Errorf("최소 연령이 최대 연령보다 클 수 없습니다")
		}
		if req.MinAge < 14 || req.MaxAge > 100 {
			return fmt.Errorf("연령은 14세 이상 100세 이하로 설정해주세요")
		}
	}

	// 성별 제한 확인
	if req.GenderPreference != "" {
		validGenders := []string{"any", "male", "female"}
		isValid := false
		for _, valid := range validGenders {
			if req.GenderPreference == valid {
				isValid = true
				break
			}
		}
		if !isValid {
			return fmt.Errorf("올바른 성별 선호도를 선택해주세요")
		}
	}

	// 카테고리 유효성 확인
	validCategories := []models.InterestCategory{
		"sports", "food", "culture", "study", "hobby", "travel", "shopping", "entertainment",
	}
	isValidCategory := false
	for _, valid := range validCategories {
		if req.Category == valid {
			isValidCategory = true
			break
		}
	}
	if !isValidCategory {
		return fmt.Errorf("올바른 카테고리를 선택해주세요")
	}

	return nil
}

// createSignalChatRoom 시그널 채팅방 자동 생성
func (s *SignalService) createSignalChatRoom(signalID uint) error {
	if s.chatService == nil {
		s.logger.Warn("ChatService가 초기화되지 않아 채팅방 생성을 건너뜁니다")
		return nil
	}

	// 시그널 정보 확인
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널 조회 실패: %v", err)
	}

	// 이미 채팅방이 존재하는지 확인
	existingRoom, _ := s.chatService.GetChatRoomBySignalID(signalID)
	if existingRoom != nil {
		s.logger.Info(fmt.Sprintf("시그널 %d의 채팅방이 이미 존재합니다", signalID))
		return nil
	}

	// 채팅방 생성
	room, err := s.chatService.CreateChatRoom(signalID)
	if err != nil {
		return fmt.Errorf("채팅방 생성 실패: %v", err)
	}

	s.logger.Info(fmt.Sprintf("시그널 %d 채팅방 생성 완료 (ID: %d)", signalID, room.ID))
	return nil
}

// validateUserEligibility 사용자 자격 확인
func (s *SignalService) validateUserEligibility(user *models.User, signal *models.Signal) error {
	if user.Profile == nil {
		return fmt.Errorf("프로필 정보가 필요합니다")
	}

	profile := user.Profile

	// 연령대 확인
	if signal.MinAge > 0 && profile.Age < signal.MinAge {
		return fmt.Errorf("최소 연령 요건을 충족하지 않습니다")
	}

	if signal.MaxAge > 0 && profile.Age > signal.MaxAge {
		return fmt.Errorf("최대 연령 요건을 충족하지 않습니다")
	}

	// 성별 확인
	if signal.GenderPreference != "" && signal.GenderPreference != "any" {
		if profile.Gender != signal.GenderPreference {
			genderText := "남성"
			if signal.GenderPreference == "female" {
				genderText = "여성"
			}
			return fmt.Errorf("%s만 참여 가능한 시그널입니다", genderText)
		}
	}

	return nil
}

// inviteUserToChatRoom 사용자를 채팅방에 초대
func (s *SignalService) inviteUserToChatRoom(signalID, userID uint) error {
	// TODO: 채팅 서비스 구현 시 연동
	s.logger.Info(fmt.Sprintf("사용자 %d를 시그널 %d 채팅방에 초대", userID, signalID))
	return nil
}

// notifyCreatorOfJoinRequest 생성자에게 참여 요청 알림
func (s *SignalService) notifyCreatorOfJoinRequest(creatorID uint, signal *models.Signal, user *models.User) {
	title := fmt.Sprintf("📝 %s 참여 요청", signal.Title)
	body := fmt.Sprintf("%s님이 참여를 요청했습니다", user.Profile.DisplayName)
	data := map[string]string{
		"type":      "join_request",
		"signal_id": fmt.Sprintf("%d", signal.ID),
		"user_id":   fmt.Sprintf("%d", user.ID),
	}

	if err := s.queue.PushNotification(nil, []uint{creatorID}, title, body, data); err != nil {
		s.logger.Error("참여 요청 알림 발송 실패", err)
	}
}

// notifyCreatorOfJoinApproval 생성자에게 즉시 참여 알림
func (s *SignalService) notifyCreatorOfJoinApproval(creatorID uint, signal *models.Signal, user *models.User) {
	title := fmt.Sprintf("✅ %s 새 참여자", signal.Title)
	body := fmt.Sprintf("%s님이 참여했습니다", user.Profile.DisplayName)
	data := map[string]string{
		"type":      "participant_joined",
		"signal_id": fmt.Sprintf("%d", signal.ID),
		"user_id":   fmt.Sprintf("%d", user.ID),
	}

	if err := s.queue.PushNotification(nil, []uint{creatorID}, title, body, data); err != nil {
		s.logger.Error("참여 알림 발송 실패", err)
	}
}

// notifyMatchedUsers 매칭된 사용자들에게 알림 발송
func (s *SignalService) notifyMatchedUsers(signal *models.Signal) {
	// 사용자의 관심사와 위치를 기반으로 매칭된 사용자들에게만 알림
	users, err := s.userRepo.GetMatchedUsersForSignal(signal)
	if err != nil {
		s.logger.Error("매칭 사용자 조회 실패", err)
		return
	}

	if len(users) == 0 {
		return
	}

	userIDs := make([]uint, len(users))
	for i, user := range users {
		userIDs[i] = user.ID
	}

	title := fmt.Sprintf("🎯 새로운 시그널: %s", signal.Title)
	body := fmt.Sprintf("%s에서 %s 함께하실 분을 찾고 있어요!", signal.Address, signal.Category)
	data := map[string]string{
		"type":      "new_signal_matched",
		"signal_id": fmt.Sprintf("%d", signal.ID),
		"category":  string(signal.Category),
		"latitude":  fmt.Sprintf("%f", signal.Latitude),
		"longitude": fmt.Sprintf("%f", signal.Longitude),
	}

	// 푸시 알림 큐에 추가
	if err := s.queue.PushNotification(nil, userIDs, title, body, data); err != nil {
		s.logger.Error("매칭 사용자 푸시 알림 큐 추가 실패", err)
	} else {
		s.logger.Info(fmt.Sprintf("매칭 사용자 %d명에게 알림 발송", len(userIDs)))
	}
}

func (s *SignalService) notifyNearbyUsers(signal *models.Signal) {
	// 주변 사용자 조회 (5km 반경)
	users, err := s.userRepo.GetUsersInRadius(signal.Latitude, signal.Longitude, 5000, signal.CreatorID)
	if err != nil {
		s.logger.Error("주변 사용자 조회 실패", err)
		return
	}

	if len(users) == 0 {
		return
	}

	userIDs := make([]uint, len(users))
	for i, user := range users {
		userIDs[i] = user.ID
	}

	title := fmt.Sprintf("새로운 시그널: %s", signal.Title)
	body := fmt.Sprintf("%s에서 %s 활동을 함께 하실 분을 찾고 있어요!", signal.Address, signal.Category)
	data := map[string]string{
		"type":      "new_signal",
		"signal_id": fmt.Sprintf("%d", signal.ID),
		"category":  string(signal.Category),
	}

	// 푸시 알림 큐에 추가
	if err := s.queue.PushNotification(nil, userIDs, title, body, data); err != nil {
		s.logger.Error("푸시 알림 큐 추가 실패", err)
	}
}

// initializeSignalCache 서버 시작 시 활성 시그널들을 Redis GEO에 캐시
func (s *SignalService) initializeSignalCache() {
	ctx := context.Background()
	
	s.logger.Info("활성 시그널 Redis GEO 캐시 초기화 시작")
	
	// 기존 캐시 삭제
	s.redisClient.Delete(ctx, "active_signals:geo")
	
	// 모든 활성 시그널 조회 (전체 영역)
	signals, err := s.signalRepo.GetActiveSignalsInRadius(0, 0, 99999999) // 매우 큰 반경으로 모든 시그널 조회
	if err != nil {
		s.logger.Error("활성 시그널 조회 실패", err)
		return
	}
	
	// Redis GEO에 저장
	for _, signal := range signals {
		err := s.AddSignalToGeoCache(signal)
		if err != nil {
			s.logger.Error(fmt.Sprintf("시그널 %d GEO 캐시 추가 실패", signal.ID), err)
			continue
		}
	}
	
	s.logger.Info(fmt.Sprintf("활성 시그널 %d개 Redis GEO 캐시 초기화 완료", len(signals)))
}

// AddSignalToGeoCache 시그널을 Redis GEO 캐시에 추가
func (s *SignalService) AddSignalToGeoCache(signal models.Signal) error {
	ctx := context.Background()
	
	// 기존의 AddActiveSignal 메서드 사용
	err := s.redisClient.AddActiveSignal(ctx, signal.ID, signal.Latitude, signal.Longitude)
	if err != nil {
		return err
	}
	
	// 시그널 상세 정보도 별도 캐싱 (5분 TTL)
	signalKey := fmt.Sprintf("signal:%d:details", signal.ID)
	signalJSON, err := json.Marshal(signal)
	if err != nil {
		return err
	}
	
	return s.redisClient.Set(ctx, signalKey, signalJSON, 5*time.Minute)
}

// RemoveSignalFromGeoCache 시그널을 Redis GEO 캐시에서 제거
func (s *SignalService) RemoveSignalFromGeoCache(signalID uint) error {
	ctx := context.Background()
	
	// RemoveActiveSignal 메서드 사용
	err := s.redisClient.RemoveActiveSignal(ctx, signalID)
	if err != nil {
		return err
	}
	
	// 시그널 상세 정보 캐시도 삭제
	signalKey := fmt.Sprintf("signal:%d:details", signalID)
	return s.redisClient.Delete(ctx, signalKey)
}

// GetNearbySignalsFromGeoCache Redis GEO를 사용하여 근처 시그널들을 빠르게 조회
func (s *SignalService) GetNearbySignalsFromGeoCache(lat, lon, radius float64) ([]models.Signal, error) {
	ctx := context.Background()
	
	// FindNearbySignals 메서드 사용
	results, err := s.redisClient.FindNearbySignals(ctx, lon, lat, radius)
	if err != nil {
		return nil, err
	}
	
	var signals []models.Signal
	
	// 각 시그널의 상세 정보를 캐시에서 조회
	for _, result := range results {
		signalKey := fmt.Sprintf("%s:details", result.Name)
		
		signalData, err := s.redisClient.Get(ctx, signalKey)
		if err != nil {
			// 캐시 미스 시 데이터베이스에서 조회
			signalIDStr := strings.TrimPrefix(result.Name, "signal:")
			signalID, parseErr := strconv.ParseUint(signalIDStr, 10, 32)
			if parseErr != nil {
				continue
			}
			
			signal, dbErr := s.signalRepo.GetByID(uint(signalID))
			if dbErr != nil {
				continue
			}
			
			// 다시 캐시에 저장
			s.AddSignalToGeoCache(*signal)
			signals = append(signals, *signal)
		} else {
			var signal models.Signal
			if json.Unmarshal([]byte(signalData), &signal) == nil {
				signals = append(signals, signal)
			}
		}
	}
	
	return signals, nil
}

// CacheActiveSignals 모든 활성 시그널들을 Redis GEO에 캐시
func (s *SignalService) CacheActiveSignals() error {
	ctx := context.Background()
	key := "active_signals:geo"
	
	s.logger.Info("활성 시그널 Redis GEO 캐시 업데이트 시작")
	
	// 기존 캐시 삭제
	s.redisClient.Delete(ctx, key)
	
	// 활성 시그널들 조회
	signals, err := s.signalRepo.GetActiveSignalsInRadius(0, 0, 99999999) // 전체 조회
	if err != nil {
		return err
	}
	
	// Redis GEO에 저장
	for _, signal := range signals {
		err := s.redisClient.AddActiveSignal(ctx, signal.ID, signal.Latitude, signal.Longitude)
		if err != nil {
			s.logger.Error(fmt.Sprintf("시그널 %d GEO 추가 실패", signal.ID), err)
			continue
		}
		
		// 시그널 상세 정보도 별도 캐싱
		signalKey := fmt.Sprintf("signal:%d:details", signal.ID)
		if signalJSON, jsonErr := json.Marshal(signal); jsonErr == nil {
			s.redisClient.Set(ctx, signalKey, signalJSON, 5*time.Minute)
		}
	}
	
	s.logger.Info(fmt.Sprintf("활성 시그널 %d개 Redis GEO 캐시 업데이트 완료", len(signals)))
	
	return nil
}

// broadcastSignalUpdate 시그널 생성/업데이트/삭제 시 실시간 브로드캐스트
func (s *SignalService) broadcastSignalUpdate(signal *models.Signal, updateType string) {
	if s.websocketService == nil {
		return
	}

	// SignalWithDistance로 변환 (거리는 0으로 설정)
	signalWithDistance := &models.SignalWithDistance{
		Signal:   *signal,
		Distance: 0, // 브로드캐스트에서는 거리 계산 불필요
	}

	// WebSocket을 통해 브로드캐스트
	s.websocketService.BroadcastSignalUpdate(signalWithDistance, updateType)
	
	s.logger.Info(fmt.Sprintf("시그널 %d 실시간 업데이트 브로드캐스트: %s", signal.ID, updateType))
}

// BroadcastSignalStatusUpdate 시그널 상태 변경 시 실시간 브로드캐스트
func (s *SignalService) BroadcastSignalStatusUpdate(signalID uint, status models.SignalStatus) {
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		s.logger.Error("시그널 상태 브로드캐스트용 조회 실패", err)
		return
	}

	var updateType string
	switch status {
	case models.SignalFull:
		updateType = "signal_full"
	case models.SignalClosed:
		updateType = "signal_closed"
	case models.SignalCancelled:
		updateType = "signal_cancelled"
	case models.SignalCompleted:
		updateType = "signal_completed"
	default:
		updateType = "signal_updated"
	}

	s.broadcastSignalUpdate(signal, updateType)
	
	// Redis GEO에서 제거 (비활성 상태가 된 경우)
	if status != models.SignalActive {
		go s.RemoveSignalFromGeoCache(signalID)
	}
}

// NotifySignalParticipantChange 시그널 참여자 변경 시 실시간 알림
func (s *SignalService) NotifySignalParticipantChange(signalID uint) {
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		s.logger.Error("시그널 참여자 변경 브로드캐스트용 조회 실패", err)
		return
	}

	// 정원이 찬 경우 별도 처리
	if signal.CurrentParticipants >= signal.MaxParticipants {
		signal.Status = models.SignalFull
		s.signalRepo.Update(signal)
		s.BroadcastSignalStatusUpdate(signalID, models.SignalFull)
	} else {
		s.broadcastSignalUpdate(signal, "signal_updated")
	}
}

// ============================================================================
// ENHANCED JOIN REQUEST SYSTEM - Sprint 2 Implementation
// ============================================================================

// CreateJoinRequest creates a new join request with enhanced validation and rate limiting
func (s *SignalService) CreateJoinRequest(signalID, userID uint, req *models.CreateJoinRequestRequest, userIP, userAgent string) (*models.SignalJoinRequest, error) {
	ctx := context.Background()

	// 1. Validate signal and user
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return nil, fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return nil, fmt.Errorf("사용자 정보를 찾을 수 없습니다")
	}

	// 2. Enhanced eligibility validation
	if err := s.ValidateSignalEligibility(userID, signal); err != nil {
		return nil, err
	}

	// 3. Rate limiting checks
	if err := s.CheckRateLimits(userID, "join_request"); err != nil {
		return nil, err
	}

	// 4. Check for existing join requests
	existingRequests, err := s.signalRepo.GetUserJoinRequests(signalID, userID)
	if err != nil {
		return nil, fmt.Errorf("기존 참여 요청 확인 실패")
	}

	for _, existing := range existingRequests {
		switch existing.Status {
		case models.JoinRequestPending:
			return nil, fmt.Errorf("이미 참여 요청을 보냈습니다")
		case models.JoinRequestApproved:
			return nil, fmt.Errorf("이미 승인된 참여자입니다")
		case models.JoinRequestRejected:
			// Allow retry after 24 hours
			if time.Since(existing.UpdatedAt) < 24*time.Hour {
				return nil, fmt.Errorf("거절된 후 24시간 후에 재신청 가능합니다")
			}
		}
	}

	// 5. Create join request with expiration
	now := time.Now()
	expiresAt := now.Add(72 * time.Hour) // 72 hours to respond
	if signal.ScheduledAt.Before(expiresAt) {
		expiresAt = signal.ScheduledAt.Add(-1 * time.Hour) // Expire 1 hour before signal
	}

	joinRequest := &models.SignalJoinRequest{
		SignalID:    signalID,
		UserID:      userID,
		Status:      models.JoinRequestPending,
		Message:     req.Message,
		UserIP:      userIP,
		UserAgent:   userAgent,
		ExpiresAt:   expiresAt,
	}

	// 6. Save to database
	if err := s.signalRepo.CreateJoinRequest(joinRequest); err != nil {
		s.logger.Error("참여 요청 생성 실패", err)
		return nil, fmt.Errorf("참여 요청 생성에 실패했습니다")
	}

	// 7. Auto-approve for instant join signals
	if signal.AllowInstantJoin && !signal.RequireApproval {
		approveReq := &models.ApproveJoinRequestRequest{
			UserID:  userID,
			Message: "자동 승인됨",
		}
		if err := s.ApproveJoinRequest(signalID, signal.CreatorID, userID, approveReq); err != nil {
			s.logger.Error("자동 승인 실패", err)
		}
	} else {
		// 8. Notify signal creator
		go s.notifyCreatorOfJoinRequest(signal.CreatorID, signal, user)
	}

	// 9. Schedule expiration cleanup
	go s.queue.ScheduleJoinRequestExpiration(ctx, joinRequest.ID, expiresAt)

	s.logger.LogJoinRequestCreated(ctx, joinRequest.ID, signalID, userID)

	return joinRequest, nil
}

// ApproveJoinRequest approves a join request with enhanced workflow
func (s *SignalService) ApproveJoinRequest(signalID, creatorID, userID uint, req *models.ApproveJoinRequestRequest) error {
	ctx := context.Background()

	// 1. Validate signal and creator
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	if signal.CreatorID != creatorID {
		return fmt.Errorf("시그널 생성자만 승인할 수 있습니다")
	}

	// 2. Check if signal is still accepting participants
	if signal.Status != models.SignalActive {
		return fmt.Errorf("참여를 받지 않는 시그널입니다")
	}

	if signal.CurrentParticipants >= signal.MaxParticipants {
		return fmt.Errorf("정원이 마감되었습니다")
	}

	// 3. Find and validate join request
	joinRequest, err := s.signalRepo.GetJoinRequest(signalID, userID)
	if err != nil {
		return fmt.Errorf("참여 요청을 찾을 수 없습니다")
	}

	if joinRequest.Status != models.JoinRequestPending {
		return fmt.Errorf("이미 처리된 요청입니다")
	}

	if time.Now().After(joinRequest.ExpiresAt) {
		return fmt.Errorf("만료된 참여 요청입니다")
	}

	// 4. Transaction: Update join request and create participant
	if err := s.signalRepo.CreateWithTransaction(func(tx interface{}) error {
		// Update join request status
		now := time.Now()
		joinRequest.Status = models.JoinRequestApproved
		joinRequest.ApprovedBy = &creatorID
		joinRequest.ApprovedAt = &now
		
		if err := s.signalRepo.UpdateJoinRequestTx(tx, joinRequest); err != nil {
			return err
		}

		// Create participant
		participant := &models.SignalParticipant{
			SignalID: signalID,
			UserID:   userID,
			Status:   models.ParticipantApproved,
			Message:  req.Message,
			JoinedAt: &now,
		}

		if err := s.signalRepo.CreateParticipantTx(tx, participant); err != nil {
			return err
		}

		// Update signal participant count
		return s.signalRepo.IncrementParticipantCountTx(tx, signalID)
	}); err != nil {
		s.logger.Error("참여 승인 트랜잭션 실패", err)
		return fmt.Errorf("참여 승인에 실패했습니다")
	}

	// 5. Post-approval actions
	go func() {
		// Invite to chat room
		if err := s.inviteUserToChatRoom(signalID, userID); err != nil {
			s.logger.Error("채팅방 초대 실패", err)
		}

		// Send approval notification to user
		s.notifyUserOfApproval(userID, signal)

		// Update caches
		s.invalidateSignalCaches(signalID)
	}()

	// 6. Real-time updates
	go s.NotifySignalParticipantChange(signalID)

	s.logger.LogJoinRequestApproved(ctx, joinRequest.ID, signalID, userID, creatorID)

	return nil
}

// RejectJoinRequest rejects a join request with reason
func (s *SignalService) RejectJoinRequest(signalID, creatorID, userID uint, req *models.RejectJoinRequestRequest) error {
	ctx := context.Background()

	// 1. Validate signal and creator
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	if signal.CreatorID != creatorID {
		return fmt.Errorf("시그널 생성자만 거절할 수 있습니다")
	}

	// 2. Find and validate join request
	joinRequest, err := s.signalRepo.GetJoinRequest(signalID, userID)
	if err != nil {
		return fmt.Errorf("참여 요청을 찾을 수 없습니다")
	}

	if joinRequest.Status != models.JoinRequestPending {
		return fmt.Errorf("이미 처리된 요청입니다")
	}

	// 3. Update join request with rejection
	now := time.Now()
	joinRequest.Status = models.JoinRequestRejected
	joinRequest.RejectedBy = &creatorID
	joinRequest.RejectedAt = &now
	joinRequest.RejectionReason = req.Reason

	if err := s.signalRepo.UpdateJoinRequest(joinRequest); err != nil {
		s.logger.Error("참여 거절 업데이트 실패", err)
		return fmt.Errorf("참여 거절에 실패했습니다")
	}

	// 4. Notify user of rejection
	go s.notifyUserOfRejection(userID, signal, req.Reason)

	s.logger.LogJoinRequestRejected(ctx, joinRequest.ID, signalID, userID, creatorID)

	return nil
}

// GetPendingJoinRequests retrieves pending join requests for a signal
func (s *SignalService) GetPendingJoinRequests(signalID, creatorID uint) ([]models.SignalJoinRequest, error) {
	// Validate creator permissions
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return nil, fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	if signal.CreatorID != creatorID {
		return nil, fmt.Errorf("시그널 생성자만 조회할 수 있습니다")
	}

	// Get pending requests with user information
	requests, err := s.signalRepo.GetPendingJoinRequests(signalID)
	if err != nil {
		s.logger.Error("대기중인 참여 요청 조회 실패", err)
		return nil, fmt.Errorf("참여 요청 조회에 실패했습니다")
	}

	return requests, nil
}

// GetMyJoinRequests retrieves user's join requests with pagination
func (s *SignalService) GetMyJoinRequests(userID uint, page, limit int) ([]models.SignalJoinRequest, *utils.Pagination, error) {
	if page <= 0 {
		page = 1
	}
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	requests, total, err := s.signalRepo.GetUserJoinRequestsPaginated(userID, page, limit)
	if err != nil {
		s.logger.Error("내 참여 요청 조회 실패", err)
		return nil, nil, fmt.Errorf("참여 요청 조회에 실패했습니다")
	}

	pagination := utils.CalculatePagination(page, limit, total)

	return requests, &pagination, nil
}

// ============================================================================
// SIGNAL MANAGEMENT ENHANCEMENTS
// ============================================================================

// UpdateSignalStatus updates signal status with validation
func (s *SignalService) UpdateSignalStatus(signalID uint, status models.SignalStatus) error {
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	// Validate status transition
	if !s.isValidStatusTransition(signal.Status, status) {
		return fmt.Errorf("유효하지 않은 상태 변경입니다: %s -> %s", signal.Status, status)
	}

	// Update status
	signal.Status = status
	if err := s.signalRepo.Update(signal); err != nil {
		s.logger.Error("시그널 상태 업데이트 실패", err)
		return fmt.Errorf("상태 업데이트에 실패했습니다")
	}

	// Broadcast status change
	go s.BroadcastSignalStatusUpdate(signalID, status)

	// Update caches
	go s.invalidateSignalCaches(signalID)

	s.logger.Info(fmt.Sprintf("시그널 %d 상태 변경: %s", signalID, status))

	return nil
}

// CancelSignal cancels a signal with reason
func (s *SignalService) CancelSignal(signalID, userID uint, reason string) error {
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	if signal.CreatorID != userID {
		return fmt.Errorf("시그널 생성자만 취소할 수 있습니다")
	}

	if signal.Status != models.SignalActive {
		return fmt.Errorf("취소할 수 없는 시그널입니다")
	}

	// Update status and notify participants
	if err := s.UpdateSignalStatus(signalID, models.SignalCancelled); err != nil {
		return err
	}

	// Notify all participants
	go s.notifySignalCancellation(signal, reason)

	return nil
}

// CompleteSignal marks a signal as completed
func (s *SignalService) CompleteSignal(signalID, userID uint) error {
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	if signal.CreatorID != userID {
		return fmt.Errorf("시그널 생성자만 완료할 수 있습니다")
	}

	return s.UpdateSignalStatus(signalID, models.SignalCompleted)
}

// ============================================================================
// RATE LIMITING AND VALIDATION
// ============================================================================

// CheckRateLimits validates user rate limits for various actions
func (s *SignalService) CheckRateLimits(userID uint, action string) error {
	ctx := context.Background()
	now := time.Now()

	switch action {
	case "join_request":
		// Daily join request limit
		dailyKey := fmt.Sprintf("rate_limit:join_request:daily:%d:%s", userID, now.Format("2006-01-02"))
		dailyCount, err := s.redisClient.Incr(ctx, dailyKey)
		if err == nil {
			s.redisClient.Expire(ctx, dailyKey, 24*time.Hour)
			if dailyCount > 15 { // Max 15 join requests per day
				return fmt.Errorf("일일 참여 요청 한도에 도달했습니다 (15개/일)")
			}
		}

		// Hourly join request limit for spam prevention
		hourlyKey := fmt.Sprintf("rate_limit:join_request:hourly:%d:%s", userID, now.Format("2006-01-02-15"))
		hourlyCount, err := s.redisClient.Incr(ctx, hourlyKey)
		if err == nil {
			s.redisClient.Expire(ctx, hourlyKey, time.Hour)
			if hourlyCount > 5 { // Max 5 join requests per hour
				return fmt.Errorf("시간당 참여 요청 한도에 도달했습니다 (5개/시간)")
			}
		}

	case "signal_creation":
		// Already handled in CreateSignal method
		break
	}

	return nil
}

// ValidateSignalEligibility checks if user can participate in signal
func (s *SignalService) ValidateSignalEligibility(userID uint, signal *models.Signal) error {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return fmt.Errorf("사용자 정보를 찾을 수 없습니다")
	}

	if !user.IsActive {
		return fmt.Errorf("비활성 사용자는 참여할 수 없습니다")
	}

	// Enhanced manner score validation
	if user.Profile != nil {
		minMannerScore := 30.0
		if signal.Category == "study" || signal.Category == "culture" {
			minMannerScore = 35.0 // Higher requirements for quality activities
		}
		if user.Profile.MannerScore < minMannerScore {
			return fmt.Errorf("매너 점수가 부족하여 참여할 수 없습니다 (현재: %.1f점, 필요: %.1f점)", 
				user.Profile.MannerScore, minMannerScore)
		}
	}

	// Basic signal validation
	if signal.Status != models.SignalActive {
		return fmt.Errorf("참여할 수 없는 시그널입니다")
	}

	if signal.CreatorID == userID {
		return fmt.Errorf("자신이 생성한 시그널에는 참여할 수 없습니다")
	}

	if signal.CurrentParticipants >= signal.MaxParticipants {
		return fmt.Errorf("정원이 마감되었습니다")
	}

	if time.Now().After(signal.ScheduledAt) {
		return fmt.Errorf("이미 시작된 시그널입니다")
	}

	// Age and gender validation
	return s.validateUserEligibility(user, signal)
}

// ============================================================================
// HELPER METHODS
// ============================================================================

// isValidStatusTransition validates signal status transitions
func (s *SignalService) isValidStatusTransition(from, to models.SignalStatus) bool {
	validTransitions := map[models.SignalStatus][]models.SignalStatus{
		models.SignalActive:    {models.SignalFull, models.SignalClosed, models.SignalCancelled, models.SignalCompleted},
		models.SignalFull:      {models.SignalClosed, models.SignalCancelled, models.SignalCompleted},
		models.SignalClosed:    {models.SignalCompleted},
		models.SignalCancelled: {}, // Final state
		models.SignalCompleted: {}, // Final state
	}

	allowed, exists := validTransitions[from]
	if !exists {
		return false
	}

	for _, allowedStatus := range allowed {
		if allowedStatus == to {
			return true
		}
	}

	return false
}

// invalidateSignalCaches invalidates all caches related to a signal
func (s *SignalService) invalidateSignalCaches(signalID uint) {
	ctx := context.Background()
	
	// Remove from Redis GEO cache
	s.RemoveSignalFromGeoCache(signalID)
	
	// Invalidate signal details cache
	signalKey := fmt.Sprintf("signal:%d:details", signalID)
	s.redisClient.Delete(ctx, signalKey)
	
	// Invalidate nearby caches (this could be optimized with signal location)
	// For now, we'll invalidate common cache patterns
	pattern := "nearby_signals:*"
	keys, err := s.redisClient.Keys(ctx, pattern)
	if err == nil {
		for _, key := range keys {
			s.redisClient.Delete(ctx, key)
		}
	}
}

// Enhanced notification methods
func (s *SignalService) notifyUrgentJoinRequest(creatorID uint, signal *models.Signal, user *models.User) {
	title := fmt.Sprintf("🚨 긴급 참여 요청: %s", signal.Title)
	body := fmt.Sprintf("%s님이 긴급 참여를 요청했습니다 (시작 임박)", user.Profile.DisplayName)
	data := map[string]string{
		"type":      "urgent_join_request",
		"signal_id": fmt.Sprintf("%d", signal.ID),
		"user_id":   fmt.Sprintf("%d", user.ID),
		"priority":  "high",
	}

	if err := s.queue.PushNotification(nil, []uint{creatorID}, title, body, data); err != nil {
		s.logger.Error("긴급 참여 요청 알림 발송 실패", err)
	}
}

func (s *SignalService) sendWelcomeMessage(signalID, userID uint) {
	// TODO: Implement welcome message sending when chat service is available
	s.logger.Info(fmt.Sprintf("환영 메시지 발송: 시그널 %d, 사용자 %d", signalID, userID))
}

func (s *SignalService) notifyUserOfApproval(userID uint, signal *models.Signal) {
	title := fmt.Sprintf("✅ 참여 승인: %s", signal.Title)
	body := fmt.Sprintf("참여가 승인되었습니다! 채팅방에서 만나요.")
	data := map[string]string{
		"type":      "join_approved",
		"signal_id": fmt.Sprintf("%d", signal.ID),
	}

	if err := s.queue.PushNotification(nil, []uint{userID}, title, body, data); err != nil {
		s.logger.Error("승인 알림 발송 실패", err)
	}
}

func (s *SignalService) notifyUserOfRejection(userID uint, signal *models.Signal, reason string) {
	title := fmt.Sprintf("❌ 참여 거절: %s", signal.Title)
	body := fmt.Sprintf("참여가 거절되었습니다: %s", reason)
	data := map[string]string{
		"type":      "join_rejected",
		"signal_id": fmt.Sprintf("%d", signal.ID),
		"reason":    reason,
	}

	if err := s.queue.PushNotification(nil, []uint{userID}, title, body, data); err != nil {
		s.logger.Error("거절 알림 발송 실패", err)
	}
}

func (s *SignalService) notifySignalCancellation(signal *models.Signal, reason string) {
	participants, err := s.signalRepo.GetParticipants(signal.ID)
	if err != nil {
		s.logger.Error("참여자 조회 실패", err)
		return
	}

	userIDs := make([]uint, 0, len(participants))
	for _, p := range participants {
		if p.Status == models.ParticipantApproved {
			userIDs = append(userIDs, p.UserID)
		}
	}

	if len(userIDs) == 0 {
		return
	}

	title := fmt.Sprintf("🚫 시그널 취소: %s", signal.Title)
	body := fmt.Sprintf("시그널이 취소되었습니다: %s", reason)
	data := map[string]string{
		"type":      "signal_cancelled",
		"signal_id": fmt.Sprintf("%d", signal.ID),
		"reason":    reason,
	}

	if err := s.queue.PushNotification(nil, userIDs, title, body, data); err != nil {
		s.logger.Error("취소 알림 발송 실패", err)
	}
}