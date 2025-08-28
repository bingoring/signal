package services

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
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
	signalRepo repositories.SignalRepositoryInterface
	userRepo   repositories.UserRepositoryInterface
	redisClient *redis.Client
	queue      *queue.Queue
	logger     *logger.Logger
}

func NewSignalService(
	signalRepo repositories.SignalRepositoryInterface,
	userRepo repositories.UserRepositoryInterface,
	redisClient *redis.Client,
	queue *queue.Queue,
	logger *logger.Logger,
) SignalServiceInterface {
	return &SignalService{
		signalRepo:  signalRepo,
		userRepo:    userRepo,
		redisClient: redisClient,
		queue:       queue,
		logger:      logger,
	}
}

func (s *SignalService) CreateSignal(creatorID uint, req *models.CreateSignalRequest) (*models.Signal, error) {
	// 유효성 검사
	if req.ScheduledAt.Before(time.Now()) {
		return nil, fmt.Errorf("과거 시간으로 시그널을 생성할 수 없습니다")
	}

	if req.ScheduledAt.After(time.Now().Add(24 * time.Hour)) {
		return nil, fmt.Errorf("24시간 이후의 시그널은 생성할 수 없습니다")
	}

	if !utils.IsValidCoordinate(req.Latitude, req.Longitude) {
		return nil, fmt.Errorf("유효하지 않은 좌표입니다")
	}

	// 만료 시간 설정 (예정 시간 + 1시간)
	expiresAt := req.ScheduledAt.Add(1 * time.Hour)

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

	if err := s.signalRepo.Create(signal); err != nil {
		s.logger.Error("시그널 생성 실패", err)
		return nil, fmt.Errorf("시그널 생성에 실패했습니다")
	}

	// Redis에 활성 시그널 등록
	if err := s.redisClient.AddActiveSignal(nil, signal.ID, signal.Latitude, signal.Longitude); err != nil {
		s.logger.Warn(fmt.Sprintf("Redis 시그널 등록 실패: %v", err))
	}

	// 시그널 만료 작업 스케줄링
	if err := s.queue.ScheduleSignalExpiration(nil, signal.ID, expiresAt); err != nil {
		s.logger.Warn(fmt.Sprintf("시그널 만료 스케줄링 실패: %v", err))
	}

	// 근처 시그널 캐시 무효화
	go s.invalidateNearbyCache(signal.Latitude, signal.Longitude)

	// 주변 사용자들에게 푸시 알림 발송
	go s.notifyNearbyUsers(signal)

	s.logger.LogSignalCreated(nil, signal.ID, creatorID)

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
	signal, err := s.signalRepo.GetByID(signalID)
	if err != nil {
		return fmt.Errorf("시그널을 찾을 수 없습니다")
	}

	// 유효성 검사
	if signal.Status != models.SignalActive {
		return fmt.Errorf("참여할 수 없는 시그널입니다")
	}

	if signal.CreatorID == userID {
		return fmt.Errorf("자신이 생성한 시그널에는 참여할 수 없습니다")
	}

	if signal.CurrentParticipants >= signal.MaxParticipants {
		return fmt.Errorf("정원이 마감되었습니다")
	}

	// 이미 참여했는지 확인
	participants, err := s.signalRepo.GetParticipants(signalID)
	if err != nil {
		return fmt.Errorf("참여자 조회에 실패했습니다")
	}

	for _, p := range participants {
		if p.UserID == userID && p.Status != models.ParticipantLeft {
			return fmt.Errorf("이미 참여한 시그널입니다")
		}
	}

	// 참여자 추가
	status := models.ParticipantPending
	if signal.AllowInstantJoin && !signal.RequireApproval {
		status = models.ParticipantApproved
	}

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

	if err := s.signalRepo.JoinSignal(participant); err != nil {
		s.logger.Error("시그널 참여 실패", err)
		return fmt.Errorf("시그널 참여에 실패했습니다")
	}

	s.logger.LogSignalJoined(nil, signalID, userID)

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