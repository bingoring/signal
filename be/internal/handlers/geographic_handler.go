package handlers

import (
	"strconv"

	"signal-be/internal/services"
	"signal-be/internal/utils"
	"signal-module/pkg/logger"

	"github.com/gin-gonic/gin"
)

type GeographicHandler struct {
	geographicService *services.GeographicService
	logger            *logger.Logger
}

func NewGeographicHandler(geographicService *services.GeographicService, logger *logger.Logger) *GeographicHandler {
	return &GeographicHandler{
		geographicService: geographicService,
		logger:            logger,
	}
}

// AdvancedSearch 고급 지리적 검색
// @Summary Advanced geographic search
// @Description Performs advanced geographic search with clustering, density analysis, and polygon/route search
// @Tags Geographic
// @Accept json
// @Produce json
// @Param request body services.GeographicSearchRequest true "Search parameters"
// @Success 200 {object} services.GeographicSearchResult
// @Router /api/v1/geographic/search [post]
func (h *GeographicHandler) AdvancedSearch(c *gin.Context) {
	var req services.GeographicSearchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 검색 요청입니다")
		return
	}

	// 기본값 설정
	if req.Page == 0 {
		req.Page = 1
	}
	if req.Limit == 0 {
		req.Limit = 20
	}
	if req.Radius == 0 {
		req.Radius = 5000 // 기본 5km
	}

	result, err := h.geographicService.AdvancedSearch(&req)
	if err != nil {
		utils.InternalServerErrorResponse(c, "지리적 검색에 실패했습니다", err)
		return
	}

	utils.SuccessResponse(c, "고급 지리적 검색 완료", result)
}

// GetDensityMap 시그널 밀도 맵 조회
// @Summary Get signal density map
// @Description Returns signal density map for visualization
// @Tags Geographic
// @Accept json
// @Produce json
// @Param lat query float64 true "Latitude"
// @Param lon query float64 true "Longitude"
// @Param radius query float64 false "Search radius in meters" default(5000)
// @Param grid_size query float64 false "Grid size for density calculation" default(0.01)
// @Success 200 {array} services.DensityPoint
// @Router /api/v1/geographic/density [get]
func (h *GeographicHandler) GetDensityMap(c *gin.Context) {
	lat, err := strconv.ParseFloat(c.Query("lat"), 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 위도입니다")
		return
	}

	lon, err := strconv.ParseFloat(c.Query("lon"), 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 경도입니다")
		return
	}

	radius, err := strconv.ParseFloat(c.DefaultQuery("radius", "5000"), 64)
	if err != nil {
		radius = 5000
	}

	gridSize, err := strconv.ParseFloat(c.DefaultQuery("grid_size", "0.01"), 64)
	if err != nil {
		gridSize = 0.01
	}

	densityPoints, err := h.geographicService.GetNearbySignalsDensity(lat, lon, radius, gridSize)
	if err != nil {
		utils.InternalServerErrorResponse(c, "밀도 맵 생성에 실패했습니다", err)
		return
	}

	utils.SuccessResponse(c, "밀도 맵 조회 완료", densityPoints)
}

// GetHotspots 시그널 핫스팟 분석
// @Summary Get signal hotspots
// @Description Returns areas with high signal concentration
// @Tags Geographic
// @Accept json
// @Produce json
// @Param lat query float64 true "Latitude"
// @Param lon query float64 true "Longitude"
// @Param radius query float64 false "Search radius in meters" default(10000)
// @Param min_signals query int false "Minimum signals for hotspot" default(5)
// @Success 200 {array} services.SignalCluster
// @Router /api/v1/geographic/hotspots [get]
func (h *GeographicHandler) GetHotspots(c *gin.Context) {
	lat, err := strconv.ParseFloat(c.Query("lat"), 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 위도입니다")
		return
	}

	lon, err := strconv.ParseFloat(c.Query("lon"), 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 경도입니다")
		return
	}

	radius, err := strconv.ParseFloat(c.DefaultQuery("radius", "10000"), 64)
	if err != nil {
		radius = 10000
	}

	minSignals, err := strconv.Atoi(c.DefaultQuery("min_signals", "5"))
	if err != nil {
		minSignals = 5
	}

	hotspots, err := h.geographicService.GetSignalHotspots(lat, lon, radius, minSignals)
	if err != nil {
		utils.InternalServerErrorResponse(c, "핫스팟 분석에 실패했습니다", err)
		return
	}

	utils.SuccessResponse(c, "핫스팟 분석 완료", hotspots)
}

// SearchInPolygon 다각형 영역 내 시그널 검색
// @Summary Search signals in polygon area
// @Description Searches for signals within a defined polygon area
// @Tags Geographic
// @Accept json
// @Produce json
// @Param request body PolygonSearchRequest true "Polygon search parameters"
// @Success 200 {array} models.SignalWithDistance
// @Router /api/v1/geographic/polygon [post]
func (h *GeographicHandler) SearchInPolygon(c *gin.Context) {
	var req struct {
		Polygon    [][]float64               `json:"polygon" binding:"required,min=3"`
		Categories []string                  `json:"categories"`
		Page       int                       `json:"page"`
		Limit      int                       `json:"limit"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 다각형 검색 요청입니다")
		return
	}

	// 기본값 설정
	if req.Page == 0 {
		req.Page = 1
	}
	if req.Limit == 0 {
		req.Limit = 20
	}

	// 지리적 검색 요청으로 변환
	geoReq := &services.GeographicSearchRequest{
		SearchType: "polygon",
		Polygon:    req.Polygon,
		Page:       req.Page,
		Limit:      req.Limit,
	}

	result, err := h.geographicService.AdvancedSearch(geoReq)
	if err != nil {
		utils.InternalServerErrorResponse(c, "다각형 영역 검색에 실패했습니다", err)
		return
	}

	utils.SuccessResponse(c, "다각형 영역 검색 완료", result.Signals)
}

// SearchAlongRoute 경로 기반 시그널 검색
// @Summary Search signals along a route
// @Description Searches for signals along a defined route with buffer
// @Tags Geographic
// @Accept json
// @Produce json
// @Param request body RouteSearchRequest true "Route search parameters"
// @Success 200 {array} models.SignalWithDistance
// @Router /api/v1/geographic/route [post]
func (h *GeographicHandler) SearchAlongRoute(c *gin.Context) {
	var req struct {
		StartLat     float64  `json:"start_lat" binding:"required"`
		StartLon     float64  `json:"start_lon" binding:"required"`
		EndLat       float64  `json:"end_lat" binding:"required"`
		EndLon       float64  `json:"end_lon" binding:"required"`
		BufferWidth  float64  `json:"buffer_width"` // 미터 단위
		Categories   []string `json:"categories"`
		Page         int      `json:"page"`
		Limit        int      `json:"limit"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, "잘못된 경로 검색 요청입니다")
		return
	}

	// 기본값 설정
	if req.Page == 0 {
		req.Page = 1
	}
	if req.Limit == 0 {
		req.Limit = 20
	}
	if req.BufferWidth == 0 {
		req.BufferWidth = 1000 // 기본 1km 버퍼
	}

	// 지리적 검색 요청으로 변환
	geoReq := &services.GeographicSearchRequest{
		SearchType: "route",
		Route: services.RouteSearchParams{
			StartLat:    req.StartLat,
			StartLon:    req.StartLon,
			EndLat:      req.EndLat,
			EndLon:      req.EndLon,
			BufferWidth: req.BufferWidth,
		},
		Page:  req.Page,
		Limit: req.Limit,
	}

	result, err := h.geographicService.AdvancedSearch(geoReq)
	if err != nil {
		utils.InternalServerErrorResponse(c, "경로 기반 검색에 실패했습니다", err)
		return
	}

	utils.SuccessResponse(c, "경로 기반 검색 완료", result.Signals)
}

// GetLocationStatistics 지역별 시그널 통계
// @Summary Get location-based signal statistics
// @Description Returns statistical analysis of signals in a given area
// @Tags Geographic
// @Accept json
// @Produce json
// @Param lat query float64 true "Latitude"
// @Param lon query float64 true "Longitude"
// @Param radius query float64 false "Analysis radius in meters" default(5000)
// @Success 200 {object} services.GeographicStatistics
// @Router /api/v1/geographic/statistics [get]
func (h *GeographicHandler) GetLocationStatistics(c *gin.Context) {
	lat, err := strconv.ParseFloat(c.Query("lat"), 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 위도입니다")
		return
	}

	lon, err := strconv.ParseFloat(c.Query("lon"), 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 경도입니다")
		return
	}

	radius, err := strconv.ParseFloat(c.DefaultQuery("radius", "5000"), 64)
	if err != nil {
		radius = 5000
	}

	// 기본 반경 검색으로 시그널 조회
	geoReq := &services.GeographicSearchRequest{
		Latitude:   lat,
		Longitude:  lon,
		Radius:     radius,
		SearchType: "radius",
		Page:       1,
		Limit:      1000, // 통계용으로 많은 데이터 조회
	}

	result, err := h.geographicService.AdvancedSearch(geoReq)
	if err != nil {
		utils.InternalServerErrorResponse(c, "지역 통계 조회에 실패했습니다", err)
		return
	}

	utils.SuccessResponse(c, "지역 통계 조회 완료", result.Statistics)
}

// GetNearbyPoiAnalysis 주변 관심지점(POI) 분석
// @Summary Analyze nearby points of interest
// @Description Analyzes the distribution of signals around popular locations
// @Tags Geographic
// @Accept json
// @Produce json
// @Param lat query float64 true "Latitude"
// @Param lon query float64 true "Longitude"
// @Param radius query float64 false "Analysis radius in meters" default(2000)
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/geographic/poi-analysis [get]
func (h *GeographicHandler) GetNearbyPoiAnalysis(c *gin.Context) {
	lat, err := strconv.ParseFloat(c.Query("lat"), 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 위도입니다")
		return
	}

	lon, err := strconv.ParseFloat(c.Query("lon"), 64)
	if err != nil {
		utils.BadRequestResponse(c, "유효하지 않은 경도입니다")
		return
	}

	radius, err := strconv.ParseFloat(c.DefaultQuery("radius", "2000"), 64)
	if err != nil {
		radius = 2000
	}

	// POI 분석 (간단한 버전)
	geoReq := &services.GeographicSearchRequest{
		Latitude:   lat,
		Longitude:  lon,
		Radius:     radius,
		SearchType: "radius",
		Clustering: services.ClusteringParams{
			Enabled:   true,
			Distance:  300, // 300m 클러스터링
			MinPoints: 2,
		},
		Density: true,
		Page:    1,
		Limit:   500,
	}

	result, err := h.geographicService.AdvancedSearch(geoReq)
	if err != nil {
		utils.InternalServerErrorResponse(c, "POI 분석에 실패했습니다", err)
		return
	}

	analysis := map[string]interface{}{
		"total_signals":    result.Statistics.TotalSignals,
		"clusters":         result.Clusters,
		"density_points":   result.DensityMap,
		"category_distribution": result.Statistics.Categories,
		"time_distribution": result.Statistics.TimeDistribution,
		"average_distance": result.Statistics.AverageDistance,
		"analysis_center": map[string]float64{
			"latitude":  lat,
			"longitude": lon,
		},
		"analysis_radius": radius,
	}

	utils.SuccessResponse(c, "POI 분석 완료", analysis)
}