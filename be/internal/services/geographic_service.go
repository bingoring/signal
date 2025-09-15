package services

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"time"

	"signal-module/pkg/config"
	"signal-module/pkg/logger"
	"signal-module/pkg/models"
	"signal-module/pkg/redis"

	"github.com/go-redis/redis/v8"
	"gorm.io/gorm"
)

// GeographicService PostGIS 기반 고급 지리적 검색 서비스
type GeographicService struct {
	db          *gorm.DB
	redisClient *redis.Client
	config      *config.LocationConfig
	logger      *logger.Logger
}

// GeographicSearchRequest 고급 지리적 검색 요청
type GeographicSearchRequest struct {
	Latitude     float64                    `json:"latitude" binding:"required"`
	Longitude    float64                    `json:"longitude" binding:"required"`
	Radius       float64                    `json:"radius"`
	Categories   []models.InterestCategory  `json:"categories"`
	MinRadius    float64                    `json:"min_radius"`
	MaxRadius    float64                    `json:"max_radius"`
	SearchType   string                     `json:"search_type"` // radius, polygon, route
	Polygon      [][]float64               `json:"polygon"`     // 다각형 영역 검색
	Route        RouteSearchParams         `json:"route"`       // 경로 기반 검색
	TimeFilter   TimeFilterParams          `json:"time_filter"`
	Density      bool                       `json:"density"`     // 밀도 맵 요청
	Clustering   ClusteringParams          `json:"clustering"`  // 클러스터링 옵션
	Page         int                        `json:"page"`
	Limit        int                        `json:"limit"`
}

// RouteSearchParams 경로 기반 검색 파라미터
type RouteSearchParams struct {
	StartLat    float64 `json:"start_lat"`
	StartLon    float64 `json:"start_lon"`
	EndLat      float64 `json:"end_lat"`
	EndLon      float64 `json:"end_lon"`
	BufferWidth float64 `json:"buffer_width"` // 경로 양쪽 버퍼 거리
}

// TimeFilterParams 시간 기반 필터링
type TimeFilterParams struct {
	StartTime    *time.Time `json:"start_time"`
	EndTime      *time.Time `json:"end_time"`
	TimeSlots    []string   `json:"time_slots"` // morning, afternoon, evening, night
	Weekdays     []int      `json:"weekdays"`   // 0=Sunday, 1=Monday, ...
}

// ClusteringParams 클러스터링 파라미터
type ClusteringParams struct {
	Enabled     bool    `json:"enabled"`
	Distance    float64 `json:"distance"`    // 클러스터링 거리 (미터)
	MinPoints   int     `json:"min_points"`  // 최소 포인트 수
}

// GeographicSearchResult 지리적 검색 결과
type GeographicSearchResult struct {
	Signals     []models.SignalWithDistance `json:"signals"`
	Clusters    []SignalCluster             `json:"clusters,omitempty"`
	DensityMap  []DensityPoint              `json:"density_map,omitempty"`
	Statistics  GeographicStatistics        `json:"statistics"`
}

// SignalCluster 시그널 클러스터
type SignalCluster struct {
	ID           string                      `json:"id"`
	CenterLat    float64                     `json:"center_lat"`
	CenterLon    float64                     `json:"center_lon"`
	Radius       float64                     `json:"radius"`
	SignalCount  int                         `json:"signal_count"`
	Signals      []models.SignalWithDistance `json:"signals"`
	AvgDistance  float64                     `json:"avg_distance"`
}

// DensityPoint 밀도 맵 포인트
type DensityPoint struct {
	Latitude     float64 `json:"latitude"`
	Longitude    float64 `json:"longitude"`
	Density      int     `json:"density"`
	Weight       float64 `json:"weight"`
}

// GeographicStatistics 지리적 통계
type GeographicStatistics struct {
	TotalSignals    int                 `json:"total_signals"`
	AverageDistance float64             `json:"average_distance"`
	Categories      map[string]int      `json:"categories"`
	TimeDistribution map[string]int     `json:"time_distribution"`
	RadialDistribution []RadialBucket   `json:"radial_distribution"`
}

// RadialBucket 반경별 분포
type RadialBucket struct {
	MinDistance  float64 `json:"min_distance"`
	MaxDistance  float64 `json:"max_distance"`
	Count        int     `json:"count"`
}

// NewGeographicService 지리적 검색 서비스 생성자
func NewGeographicService(db *gorm.DB, redisClient *redis.Client, config *config.LocationConfig, logger *logger.Logger) *GeographicService {
	return &GeographicService{
		db:          db,
		redisClient: redisClient,
		config:      config,
		logger:      logger,
	}
}

// AdvancedSearch 고급 지리적 검색
func (gs *GeographicService) AdvancedSearch(req *GeographicSearchRequest) (*GeographicSearchResult, error) {
	ctx := context.Background()
	cacheKey := gs.generateCacheKey(req)
	
	// 캐시 확인
	if cachedResult, err := gs.getCachedResult(ctx, cacheKey); err == nil {
		gs.logger.Info("지리적 검색 캐시 히트")
		return cachedResult, nil
	}

	// 검색 타입에 따른 쿼리 실행
	var signals []models.SignalWithDistance
	var err error
	
	switch req.SearchType {
	case "polygon":
		signals, err = gs.searchInPolygon(req)
	case "route":
		signals, err = gs.searchAlongRoute(req)
	default: // radius
		signals, err = gs.searchInRadius(req)
	}
	
	if err != nil {
		return nil, err
	}

	// 결과 처리
	result := &GeographicSearchResult{
		Signals: signals,
		Statistics: gs.calculateStatistics(signals, req),
	}

	// 클러스터링 수행
	if req.Clustering.Enabled {
		result.Clusters = gs.clusterSignals(signals, req.Clustering)
	}

	// 밀도 맵 생성
	if req.Density {
		result.DensityMap = gs.generateDensityMap(signals, req)
	}

	// 결과 캐싱
	if err := gs.cacheResult(ctx, cacheKey, result); err != nil {
		gs.logger.Warn("지리적 검색 결과 캐싱 실패", err)
	}

	return result, nil
}

// searchInRadius 반경 기반 검색
func (gs *GeographicService) searchInRadius(req *GeographicSearchRequest) ([]models.SignalWithDistance, error) {
	query := `
		SELECT s.*, 
		       ST_Distance(
		           ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography,
		           ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
		       ) as distance
		FROM signals s
		WHERE s.status = 'active'
		  AND s.expires_at > NOW()
		  AND ST_DWithin(
		      ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography,
		      ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
		      ?
		  )
	`
	args := []interface{}{req.Longitude, req.Latitude, req.Longitude, req.Latitude, req.Radius}

	// 최소 반경 조건 추가
	if req.MinRadius > 0 {
		query += ` AND ST_Distance(
		    ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography,
		    ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
		) >= ?`
		args = append(args, req.Longitude, req.Latitude, req.MinRadius)
	}

	// 카테고리 필터
	if len(req.Categories) > 0 {
		query += " AND s.category IN ?"
		args = append(args, req.Categories)
	}

	// 시간 필터
	if req.TimeFilter.StartTime != nil && req.TimeFilter.EndTime != nil {
		query += " AND s.scheduled_at BETWEEN ? AND ?"
		args = append(args, req.TimeFilter.StartTime, req.TimeFilter.EndTime)
	}

	query += " ORDER BY distance LIMIT ? OFFSET ?"
	offset := (req.Page - 1) * req.Limit
	args = append(args, req.Limit, offset)

	var results []struct {
		models.Signal
		Distance float64 `json:"distance"`
	}

	if err := gs.db.Raw(query, args...).Scan(&results).Error; err != nil {
		return nil, err
	}

	signals := make([]models.SignalWithDistance, len(results))
	for i, result := range results {
		signals[i] = models.SignalWithDistance{
			Signal:   result.Signal,
			Distance: result.Distance,
		}
	}

	return signals, nil
}

// searchInPolygon 다각형 영역 내 검색
func (gs *GeographicService) searchInPolygon(req *GeographicSearchRequest) ([]models.SignalWithDistance, error) {
	if len(req.Polygon) < 3 {
		return nil, fmt.Errorf("다각형은 최소 3개의 점이 필요합니다")
	}

	// PostGIS 다각형 생성
	polygonWKT := "POLYGON(("
	for i, point := range req.Polygon {
		if i > 0 {
			polygonWKT += ", "
		}
		polygonWKT += fmt.Sprintf("%f %f", point[0], point[1])
	}
	// 마지막 점을 첫 번째 점과 연결하여 다각형 닫기
	polygonWKT += fmt.Sprintf(", %f %f", req.Polygon[0][0], req.Polygon[0][1])
	polygonWKT += "))"

	query := `
		SELECT s.*, 
		       ST_Distance(
		           ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography,
		           ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
		       ) as distance
		FROM signals s
		WHERE s.status = 'active'
		  AND s.expires_at > NOW()
		  AND ST_Within(
		      ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326),
		      ST_GeomFromText(?, 4326)
		  )
		ORDER BY distance
		LIMIT ? OFFSET ?
	`

	offset := (req.Page - 1) * req.Limit
	args := []interface{}{req.Longitude, req.Latitude, polygonWKT, req.Limit, offset}

	var results []struct {
		models.Signal
		Distance float64 `json:"distance"`
	}

	if err := gs.db.Raw(query, args...).Scan(&results).Error; err != nil {
		return nil, err
	}

	signals := make([]models.SignalWithDistance, len(results))
	for i, result := range results {
		signals[i] = models.SignalWithDistance{
			Signal:   result.Signal,
			Distance: result.Distance,
		}
	}

	return signals, nil
}

// searchAlongRoute 경로를 따라 검색
func (gs *GeographicService) searchAlongRoute(req *GeographicSearchRequest) ([]models.SignalWithDistance, error) {
	route := req.Route
	if route.BufferWidth == 0 {
		route.BufferWidth = 1000 // 기본 1km 버퍼
	}

	query := `
		SELECT s.*, 
		       ST_Distance(
		           ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography,
		           ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
		       ) as distance
		FROM signals s
		WHERE s.status = 'active'
		  AND s.expires_at > NOW()
		  AND ST_DWithin(
		      ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography,
		      ST_Buffer(
		          ST_MakeLine(
		              ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
		              ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
		          ),
		          ?
		      ),
		      0
		  )
		ORDER BY distance
		LIMIT ? OFFSET ?
	`

	offset := (req.Page - 1) * req.Limit
	args := []interface{}{
		req.Longitude, req.Latitude,
		route.StartLon, route.StartLat,
		route.EndLon, route.EndLat,
		route.BufferWidth,
		req.Limit, offset,
	}

	var results []struct {
		models.Signal
		Distance float64 `json:"distance"`
	}

	if err := gs.db.Raw(query, args...).Scan(&results).Error; err != nil {
		return nil, err
	}

	signals := make([]models.SignalWithDistance, len(results))
	for i, result := range results {
		signals[i] = models.SignalWithDistance{
			Signal:   result.Signal,
			Distance: result.Distance,
		}
	}

	return signals, nil
}

// clusterSignals 시그널 클러스터링
func (gs *GeographicService) clusterSignals(signals []models.SignalWithDistance, params ClusteringParams) []SignalCluster {
	if params.Distance == 0 {
		params.Distance = 500 // 기본 500m
	}
	if params.MinPoints == 0 {
		params.MinPoints = 2 // 기본 최소 2개
	}

	var clusters []SignalCluster
	visited := make(map[int]bool)

	for i, signal := range signals {
		if visited[i] {
			continue
		}

		// 근처 시그널들 찾기
		var clusterSignals []models.SignalWithDistance
		clusterSignals = append(clusterSignals, signal)
		visited[i] = true

		for j := i + 1; j < len(signals); j++ {
			if visited[j] {
				continue
			}

			distance := gs.calculateDistance(
				signal.Latitude, signal.Longitude,
				signals[j].Latitude, signals[j].Longitude,
			)

			if distance <= params.Distance {
				clusterSignals = append(clusterSignals, signals[j])
				visited[j] = true
			}
		}

		// 최소 포인트 수 확인
		if len(clusterSignals) >= params.MinPoints {
			cluster := gs.createCluster(clusterSignals)
			clusters = append(clusters, cluster)
		}
	}

	return clusters
}

// createCluster 클러스터 생성
func (gs *GeographicService) createCluster(signals []models.SignalWithDistance) SignalCluster {
	var totalLat, totalLon, totalDistance float64
	
	for _, signal := range signals {
		totalLat += signal.Latitude
		totalLon += signal.Longitude
		totalDistance += signal.Distance
	}

	count := float64(len(signals))
	centerLat := totalLat / count
	centerLon := totalLon / count
	avgDistance := totalDistance / count

	// 클러스터 반경 계산 (가장 먼 시그널까지의 거리)
	maxDistance := 0.0
	for _, signal := range signals {
		distance := gs.calculateDistance(centerLat, centerLon, signal.Latitude, signal.Longitude)
		if distance > maxDistance {
			maxDistance = distance
		}
	}

	return SignalCluster{
		ID:          fmt.Sprintf("cluster_%d_%d", int(centerLat*1000000), int(centerLon*1000000)),
		CenterLat:   centerLat,
		CenterLon:   centerLon,
		Radius:      maxDistance,
		SignalCount: len(signals),
		Signals:     signals,
		AvgDistance: avgDistance,
	}
}

// generateDensityMap 밀도 맵 생성
func (gs *GeographicService) generateDensityMap(signals []models.SignalWithDistance, req *GeographicSearchRequest) []DensityPoint {
	gridSize := 0.01 // 약 1km 그리드

	densityMap := make(map[string]*DensityPoint)

	for _, signal := range signals {
		// 그리드 좌표 계산
		gridLat := math.Floor(signal.Latitude/gridSize) * gridSize
		gridLon := math.Floor(signal.Longitude/gridSize) * gridSize
		key := fmt.Sprintf("%.6f,%.6f", gridLat, gridLon)

		if point, exists := densityMap[key]; exists {
			point.Density++
			point.Weight += 1.0 / (1.0 + signal.Distance/1000.0) // 거리 기반 가중치
		} else {
			densityMap[key] = &DensityPoint{
				Latitude:  gridLat + gridSize/2, // 그리드 중심점
				Longitude: gridLon + gridSize/2,
				Density:   1,
				Weight:    1.0 / (1.0 + signal.Distance/1000.0),
			}
		}
	}

	// 맵을 슬라이스로 변환
	var densityPoints []DensityPoint
	for _, point := range densityMap {
		densityPoints = append(densityPoints, *point)
	}

	return densityPoints
}

// calculateStatistics 지리적 통계 계산
func (gs *GeographicService) calculateStatistics(signals []models.SignalWithDistance, req *GeographicSearchRequest) GeographicStatistics {
	stats := GeographicStatistics{
		TotalSignals:       len(signals),
		Categories:         make(map[string]int),
		TimeDistribution:   make(map[string]int),
		RadialDistribution: make([]RadialBucket, 0),
	}

	if len(signals) == 0 {
		return stats
	}

	var totalDistance float64
	radialBuckets := map[string]int{
		"0-1km":   0,
		"1-5km":   0,
		"5-10km":  0,
		"10-20km": 0,
		"20km+":   0,
	}

	for _, signal := range signals {
		totalDistance += signal.Distance
		
		// 카테고리 분포
		stats.Categories[string(signal.Category)]++
		
		// 시간 분포
		hour := signal.ScheduledAt.Hour()
		var timeSlot string
		switch {
		case hour >= 6 && hour < 12:
			timeSlot = "morning"
		case hour >= 12 && hour < 18:
			timeSlot = "afternoon"
		case hour >= 18 && hour < 24:
			timeSlot = "evening"
		default:
			timeSlot = "night"
		}
		stats.TimeDistribution[timeSlot]++
		
		// 반경별 분포
		distanceKm := signal.Distance / 1000.0
		switch {
		case distanceKm < 1:
			radialBuckets["0-1km"]++
		case distanceKm < 5:
			radialBuckets["1-5km"]++
		case distanceKm < 10:
			radialBuckets["5-10km"]++
		case distanceKm < 20:
			radialBuckets["10-20km"]++
		default:
			radialBuckets["20km+"]++
		}
	}

	stats.AverageDistance = totalDistance / float64(len(signals))

	// 반경별 분포 변환
	bucketRanges := []struct {
		name string
		min  float64
		max  float64
	}{
		{"0-1km", 0, 1000},
		{"1-5km", 1000, 5000},
		{"5-10km", 5000, 10000},
		{"10-20km", 10000, 20000},
		{"20km+", 20000, math.Inf(1)},
	}

	for _, bucket := range bucketRanges {
		stats.RadialDistribution = append(stats.RadialDistribution, RadialBucket{
			MinDistance: bucket.min,
			MaxDistance: bucket.max,
			Count:       radialBuckets[bucket.name],
		})
	}

	return stats
}

// calculateDistance 두 지점 간 거리 계산 (Haversine 공식)
func (gs *GeographicService) calculateDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371000 // 지구 반지름 (미터)

	φ1 := lat1 * math.Pi / 180
	φ2 := lat2 * math.Pi / 180
	Δφ := (lat2 - lat1) * math.Pi / 180
	Δλ := (lon2 - lon1) * math.Pi / 180

	a := math.Sin(Δφ/2)*math.Sin(Δφ/2) +
		math.Cos(φ1)*math.Cos(φ2)*
			math.Sin(Δλ/2)*math.Sin(Δλ/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return R * c
}

// 캐시 관련 메서드들
func (gs *GeographicService) generateCacheKey(req *GeographicSearchRequest) string {
	key := fmt.Sprintf("geo_search:%f,%f:%f:%v:%s:%d:%d",
		req.Latitude, req.Longitude, req.Radius,
		req.Categories, req.SearchType, req.Page, req.Limit)
	return key
}

func (gs *GeographicService) getCachedResult(ctx context.Context, key string) (*GeographicSearchResult, error) {
	data, err := gs.redisClient.Get(ctx, key).Result()
	if err != nil {
		return nil, err
	}

	var result GeographicSearchResult
	if err := json.Unmarshal([]byte(data), &result); err != nil {
		return nil, err
	}

	return &result, nil
}

func (gs *GeographicService) cacheResult(ctx context.Context, key string, result *GeographicSearchResult) error {
	data, err := json.Marshal(result)
	if err != nil {
		return err
	}

	return gs.redisClient.Set(ctx, key, data, 5*time.Minute).Err()
}

// GetNearbySignalsDensity 주변 시그널 밀도 조회
func (gs *GeographicService) GetNearbySignalsDensity(lat, lon, radius float64, gridSize float64) ([]DensityPoint, error) {
	if gridSize == 0 {
		gridSize = 0.01 // 기본 1km 그리드
	}

	query := `
		SELECT 
		    FLOOR(latitude / ?) * ? as grid_lat,
		    FLOOR(longitude / ?) * ? as grid_lon,
		    COUNT(*) as density
		FROM signals
		WHERE status = 'active'
		  AND expires_at > NOW()
		  AND ST_DWithin(
		      ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
		      ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
		      ?
		  )
		GROUP BY grid_lat, grid_lon
		HAVING COUNT(*) > 0
		ORDER BY density DESC
	`

	var results []struct {
		GridLat float64 `json:"grid_lat"`
		GridLon float64 `json:"grid_lon"`
		Density int     `json:"density"`
	}

	args := []interface{}{gridSize, gridSize, gridSize, gridSize, lon, lat, radius}
	if err := gs.db.Raw(query, args...).Scan(&results).Error; err != nil {
		return nil, err
	}

	densityPoints := make([]DensityPoint, len(results))
	for i, result := range results {
		densityPoints[i] = DensityPoint{
			Latitude:  result.GridLat + gridSize/2,
			Longitude: result.GridLon + gridSize/2,
			Density:   result.Density,
			Weight:    float64(result.Density),
		}
	}

	return densityPoints, nil
}

// GetSignalHotspots 시그널 핫스팟 분석
func (gs *GeographicService) GetSignalHotspots(lat, lon, radius float64, minSignals int) ([]SignalCluster, error) {
	if minSignals == 0 {
		minSignals = 5
	}

	// 시그널 밀도가 높은 지역 찾기
	query := `
		WITH signal_clusters AS (
		    SELECT 
		        s1.id,
		        s1.latitude,
		        s1.longitude,
		        s1.category,
		        COUNT(s2.id) as nearby_count
		    FROM signals s1
		    JOIN signals s2 ON s1.id != s2.id
		    WHERE s1.status = 'active'
		      AND s1.expires_at > NOW()
		      AND s2.status = 'active'
		      AND s2.expires_at > NOW()
		      AND ST_DWithin(
		          ST_SetSRID(ST_MakePoint(s1.longitude, s1.latitude), 4326)::geography,
		          ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
		          ?
		      )
		      AND ST_DWithin(
		          ST_SetSRID(ST_MakePoint(s1.longitude, s1.latitude), 4326)::geography,
		          ST_SetSRID(ST_MakePoint(s2.longitude, s2.latitude), 4326)::geography,
		          500
		      )
		    GROUP BY s1.id, s1.latitude, s1.longitude, s1.category
		    HAVING COUNT(s2.id) >= ?
		)
		SELECT * FROM signal_clusters
		ORDER BY nearby_count DESC
	`

	var results []struct {
		ID          uint                     `json:"id"`
		Latitude    float64                  `json:"latitude"`
		Longitude   float64                  `json:"longitude"`
		Category    models.InterestCategory  `json:"category"`
		NearbyCount int                      `json:"nearby_count"`
	}

	args := []interface{}{lon, lat, radius, minSignals}
	if err := gs.db.Raw(query, args...).Scan(&results).Error; err != nil {
		return nil, err
	}

	// 결과를 클러스터로 변환
	hotspots := make([]SignalCluster, 0)
	for _, result := range results {
		hotspot := SignalCluster{
			ID:          fmt.Sprintf("hotspot_%d", result.ID),
			CenterLat:   result.Latitude,
			CenterLon:   result.Longitude,
			SignalCount: result.NearbyCount + 1, // 자기 자신 포함
		}
		hotspots = append(hotspots, hotspot)
	}

	return hotspots, nil
}