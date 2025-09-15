package com.signal.app.features.signal.presentation.state

import com.signal.app.features.signal.data.models.Signal
import com.signal.app.features.signal.data.models.SignalWithDistance
import com.signal.app.features.signal.data.services.*
import java.time.LocalTime

enum class MapSearchMode {
    RADIUS,    // 반경 검색
    POLYGON,   // 다각형 검색
    ROUTE,     // 경로 검색
    POI        // POI 기반 검색
}

enum class MapViewMode {
    NORMAL,    // 일반 마커
    DENSITY,   // 밀도 히트맵
    CLUSTER    // 클러스터링
}

enum class DrawingMode {
    NONE,      // 그리기 없음
    POLYGON,   // 다각형 그리기
    ROUTE      // 경로 설정
}

data class EnhancedMapState(
    // 기본 지도 상태
    val isLoading: Boolean = false,
    val error: String? = null,
    val signals: List<SignalWithDistance> = emptyList(),
    val selectedSignal: Signal? = null,
    val userLatitude: Double? = null,
    val userLongitude: Double? = null,

    // 고급 검색 모드
    val searchMode: MapSearchMode = MapSearchMode.RADIUS,
    val viewMode: MapViewMode = MapViewMode.NORMAL,
    val drawingMode: DrawingMode = DrawingMode.NONE,
    val searchQuery: String = "",

    // 검색 파라미터
    val searchRadius: Float = 5000f,
    val minRadius: Double? = null,
    val maxRadius: Double? = null,
    val selectedCategories: List<String> = emptyList(),
    val selectedTimeSlots: List<String> = emptyList(),
    val startTime: LocalTime? = null,
    val endTime: LocalTime? = null,
    val todayOnly: Boolean = false,
    val minDistance: Double = 0.0,
    val maxDistance: Double = 20000.0,
    val minAge: Int = 18,
    val maxAge: Int = 65,
    val minParticipants: Int? = null,
    val maxParticipants: Int? = null,
    val availableOnly: Boolean = false,

    // 다각형 검색
    val polygonPoints: List<List<Double>>? = null,
    val isDrawingPolygon: Boolean = false,

    // 경로 검색
    val routeStartLat: Double? = null,
    val routeStartLon: Double? = null,
    val routeEndLat: Double? = null,
    val routeEndLon: Double? = null,
    val isSelectingRoute: Boolean = false,
    val routeBufferWidth: Double = 1000.0,

    // 시각화 데이터
    val clusters: List<SignalCluster>? = null,
    val densityPoints: List<DensityPoint>? = null,
    val statistics: GeographicStatistics? = null,
    val poiAnalysis: PoiAnalysisResult? = null,
    val hotspots: List<Hotspot>? = null,

    // 클러스터링 설정
    val clusteringEnabled: Boolean = false,
    val clusterDistance: Double = 500.0,
    val minClusterPoints: Int = 2,

    // 밀도 맵 설정
    val densityMapEnabled: Boolean = false,
    val densityGridSize: Double = 0.01,

    // 성능 및 상태
    val lastUpdateTime: Long? = null,
    val isCacheEnabled: Boolean = true,
    val totalSignalsFound: Int = 0,
    val currentZoomLevel: Int = 12,
    val enableClustering: Boolean = false,
    val maxMarkersToShow: Int = 100,

    // UI 상태
    val showFilterDialog: Boolean = false,
    val showStatistics: Boolean = false
) {
    // 편의 프로퍼티들
    val hasActiveAdvancedFilters: Boolean
        get() = selectedCategories.isNotEmpty() ||
                selectedTimeSlots.isNotEmpty() ||
                startTime != null ||
                endTime != null ||
                minRadius != null ||
                maxRadius != null ||
                searchRadius != 5000f

    val hasResults: Boolean
        get() = signals.isNotEmpty()

    val isAdvancedSearchMode: Boolean
        get() = searchMode != MapSearchMode.RADIUS

    val isAdvancedVisualizationMode: Boolean
        get() = viewMode != MapViewMode.NORMAL

    val hasUserLocation: Boolean
        get() = userLatitude != null && userLongitude != null

    val canPerformSearch: Boolean
        get() = hasUserLocation

    val isPolygonComplete: Boolean
        get() = polygonPoints != null && polygonPoints.size >= 3

    val isRouteComplete: Boolean
        get() = routeStartLat != null && routeStartLon != null &&
                routeEndLat != null && routeEndLon != null

    val shouldEnableClustering: Boolean
        get() = enableClustering || (signals.size > maxMarkersToShow)

    val searchModeDescription: String
        get() = when (searchMode) {
            MapSearchMode.RADIUS ->
                "반경 ${String.format("%.1f", searchRadius / 1000)}km 검색"
            MapSearchMode.POLYGON ->
                if (isPolygonComplete) "다각형 영역 검색" else "다각형 영역 설정 중"
            MapSearchMode.ROUTE ->
                if (isRouteComplete) "경로 기반 검색" else "경로 설정 중"
            MapSearchMode.POI ->
                "POI 기반 검색"
        }

    val visualizationModeDescription: String
        get() = when (viewMode) {
            MapViewMode.NORMAL -> "일반 지도"
            MapViewMode.DENSITY -> "밀도 히트맵"
            MapViewMode.CLUSTER -> "클러스터 보기"
        }

    // 검색 결과 요약
    val searchSummary: Map<String, Any>
        get() = mapOf(
            "total_signals" to totalSignalsFound,
            "visible_signals" to signals.size,
            "search_mode" to searchMode.name.lowercase(),
            "visualization_mode" to viewMode.name.lowercase(),
            "has_clusters" to (clusters?.isNotEmpty() == true),
            "has_density_data" to (densityPoints?.isNotEmpty() == true),
            "search_radius_km" to (searchRadius / 1000),
            "has_filters" to hasActiveAdvancedFilters
        )

    // 성능 관련 메서드
    fun isHighPerformanceMode(): Boolean {
        return maxMarkersToShow > 100 && enableClustering
    }

    fun getOptimalClusterDistance(): Double {
        return when (currentZoomLevel) {
            in 0..9 -> 2000.0
            in 10..11 -> 1000.0
            in 12..13 -> 500.0
            else -> 200.0
        }
    }

    fun shouldShowPerformanceWarning(): Boolean {
        return signals.size > maxMarkersToShow && !enableClustering
    }

    // 필터 관련 메서드
    fun getActiveFilterCount(): Int {
        var count = 0
        if (selectedCategories.isNotEmpty()) count++
        if (selectedTimeSlots.isNotEmpty()) count++
        if (startTime != null || endTime != null) count++
        if (minRadius != null || maxRadius != null) count++
        if (searchRadius != 5000f) count++
        if (minDistance != 0.0 || maxDistance != 20000.0) count++
        if (minAge != 18 || maxAge != 65) count++
        if (minParticipants != null || maxParticipants != null) count++
        if (availableOnly) count++
        return count
    }

    fun getFilterSummary(): String {
        val activeFilters = mutableListOf<String>()

        if (selectedCategories.isNotEmpty()) {
            activeFilters.add("카테고리 ${selectedCategories.size}개")
        }
        if (startTime != null || endTime != null) {
            activeFilters.add("시간 제한")
        }
        if (searchRadius != 5000f) {
            activeFilters.add("반경 ${String.format("%.1f", searchRadius / 1000)}km")
        }
        if (availableOnly) {
            activeFilters.add("참여 가능만")
        }

        return if (activeFilters.isEmpty()) {
            "필터 없음"
        } else {
            activeFilters.joinToString(", ")
        }
    }

    // 지도 상태 검증
    fun validateMapState(): List<String> {
        val issues = mutableListOf<String>()

        if (!hasUserLocation) {
            issues.add("사용자 위치 정보가 필요합니다")
        }

        if (searchMode == MapSearchMode.POLYGON && !isPolygonComplete) {
            issues.add("다각형을 완성해주세요 (최소 3개 점 필요)")
        }

        if (searchMode == MapSearchMode.ROUTE && !isRouteComplete) {
            issues.add("경로의 시작점과 끝점을 설정해주세요")
        }

        if (viewMode == MapViewMode.DENSITY && densityPoints == null) {
            issues.add("밀도 데이터를 불러오는 중입니다")
        }

        if (viewMode == MapViewMode.CLUSTER && clusters == null) {
            issues.add("클러스터 데이터를 불러오는 중입니다")
        }

        return issues
    }

    // 검색 가능 여부 확인
    fun canPerformAdvancedSearch(): Boolean {
        return when (searchMode) {
            MapSearchMode.RADIUS -> hasUserLocation
            MapSearchMode.POLYGON -> hasUserLocation && isPolygonComplete
            MapSearchMode.ROUTE -> hasUserLocation && isRouteComplete
            MapSearchMode.POI -> hasUserLocation
        }
    }

    // 메모리 사용량 추정 (대략적)
    fun getEstimatedMemoryUsage(): String {
        val signalMemory = signals.size * 0.5 // KB per signal
        val clusterMemory = (clusters?.size ?: 0) * 0.2 // KB per cluster
        val densityMemory = (densityPoints?.size ?: 0) * 0.1 // KB per density point

        val totalKB = signalMemory + clusterMemory + densityMemory

        return when {
            totalKB < 1024 -> "${String.format("%.1f", totalKB)} KB"
            totalKB < 1024 * 1024 -> "${String.format("%.1f", totalKB / 1024)} MB"
            else -> "${String.format("%.1f", totalKB / (1024 * 1024))} GB"
        }
    }
}