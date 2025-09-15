package com.signal.app.features.signal.presentation.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.signal.app.core.services.LocationService
import com.signal.app.features.signal.data.models.Signal
import com.signal.app.features.signal.data.models.SignalWithDistance
import com.signal.app.features.signal.data.services.*
import com.signal.app.features.signal.presentation.state.*
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.serialization.json.Json
import java.time.LocalTime
import javax.inject.Inject

@HiltViewModel
class EnhancedMapViewModel @Inject constructor(
    private val geographicService: EnhancedGeographicService,
    private val webSocketService: SignalWebSocketService,
    private val locationService: LocationService
) : ViewModel() {

    private val _state = MutableStateFlow(EnhancedMapState())
    val state: StateFlow<EnhancedMapState> = _state.asStateFlow()

    private var searchDebounceJob: Job? = null
    private var locationUpdateJob: Job? = null
    private var webSocketJob: Job? = null

    init {
        initializeServices()
    }

    /**
     * 서비스 초기화
     */
    private fun initializeServices() {
        connectWebSocket()
        startLocationTracking()
    }

    /**
     * WebSocket 연결
     */
    private fun connectWebSocket() {
        webSocketJob = viewModelScope.launch {
            try {
                webSocketService.connect()
                webSocketService.messageFlow.collect { message ->
                    handleWebSocketMessage(message)
                }
            } catch (e: Exception) {
                _state.update { it.copy(error = "WebSocket 연결 오류: ${e.message}") }
            }
        }
    }

    /**
     * 위치 추적 시작
     */
    private fun startLocationTracking() {
        locationUpdateJob = viewModelScope.launch {
            try {
                locationService.locationFlow.collect { location ->
                    _state.update {
                        it.copy(
                            userLatitude = location.latitude,
                            userLongitude = location.longitude
                        )
                    }

                    // 자동 검색 업데이트
                    if (_state.value.signals.isEmpty() || shouldRefreshSignals()) {
                        performSearch()
                    }
                }
            } catch (e: Exception) {
                _state.update { it.copy(error = "위치 추적 오류: ${e.message}") }
            }
        }
    }

    /**
     * WebSocket 메시지 처리
     */
    private suspend fun handleWebSocketMessage(message: String) {
        try {
            val json = Json { ignoreUnknownKeys = true }
            val data = json.parseToJsonElement(message).jsonObject
            val messageType = data["type"]?.jsonPrimitive?.content

            when (messageType) {
                "signal_created" -> handleSignalCreated(data)
                "signal_updated" -> handleSignalUpdated(data)
                "signal_deleted" -> handleSignalDeleted(data)
            }
        } catch (e: Exception) {
            // 메시지 파싱 오류는 조용히 처리
        }
    }

    private suspend fun handleSignalCreated(data: kotlinx.serialization.json.JsonObject) {
        try {
            val signalData = data["signal"]?.jsonObject
            if (signalData != null) {
                // TODO: JSON 파싱을 통한 SignalWithDistance 생성
                val updatedSignals = _state.value.signals.toMutableList()
                // updatedSignals.add(signal)

                _state.update {
                    it.copy(
                        signals = updatedSignals,
                        lastUpdateTime = System.currentTimeMillis()
                    )
                }
            }
        } catch (e: Exception) {
            // 처리 오류 무시
        }
    }

    private suspend fun handleSignalUpdated(data: kotlinx.serialization.json.JsonObject) {
        try {
            val signalData = data["signal"]?.jsonObject
            if (signalData != null) {
                // TODO: JSON 파싱을 통한 SignalWithDistance 업데이트
                val signalId = signalData["id"]?.jsonPrimitive?.content

                if (signalId != null) {
                    val updatedSignals = _state.value.signals.toMutableList()
                    val signalIndex = updatedSignals.indexOfFirst { it.signal.id == signalId }

                    if (signalIndex >= 0) {
                        // updatedSignals[signalIndex] = updatedSignal

                        _state.update {
                            it.copy(
                                signals = updatedSignals,
                                selectedSignal = if (it.selectedSignal?.id == signalId) {
                                    // updatedSignal.signal
                                    it.selectedSignal
                                } else {
                                    it.selectedSignal
                                },
                                lastUpdateTime = System.currentTimeMillis()
                            )
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // 처리 오류 무시
        }
    }

    private suspend fun handleSignalDeleted(data: kotlinx.serialization.json.JsonObject) {
        try {
            val signalId = data["signal_id"]?.jsonPrimitive?.content
            if (signalId != null) {
                val updatedSignals = _state.value.signals.filter { it.signal.id != signalId }

                _state.update {
                    it.copy(
                        signals = updatedSignals,
                        selectedSignal = if (it.selectedSignal?.id == signalId) null else it.selectedSignal,
                        lastUpdateTime = System.currentTimeMillis()
                    )
                }
            }
        } catch (e: Exception) {
            // 처리 오류 무시
        }
    }

    /**
     * 사용자 위치 업데이트
     */
    suspend fun updateUserLocation(latitude: Double, longitude: Double) {
        _state.update {
            it.copy(
                userLatitude = latitude,
                userLongitude = longitude
            )
        }

        if (_state.value.signals.isEmpty() || shouldRefreshSignals()) {
            performSearch()
        }
    }

    /**
     * 검색 모드 설정
     */
    fun setSearchMode(mode: MapSearchMode) {
        _state.update { it.copy(searchMode = mode) }

        // 모드에 따른 초기화
        when (mode) {
            MapSearchMode.POLYGON -> {
                _state.update {
                    it.copy(
                        polygonPoints = emptyList(),
                        isDrawingPolygon = true
                    )
                }
            }
            MapSearchMode.ROUTE -> {
                _state.update {
                    it.copy(
                        routeStartLat = null,
                        routeStartLon = null,
                        routeEndLat = null,
                        routeEndLon = null,
                        isSelectingRoute = true
                    )
                }
            }
            else -> {
                _state.update {
                    it.copy(
                        polygonPoints = null,
                        isDrawingPolygon = false,
                        isSelectingRoute = false
                    )
                }
            }
        }
    }

    /**
     * 뷰 모드 설정
     */
    fun setViewMode(mode: MapViewMode) {
        _state.update { it.copy(viewMode = mode) }

        when (mode) {
            MapViewMode.DENSITY -> loadDensityData()
            MapViewMode.CLUSTER -> performClusterSearch()
            MapViewMode.NORMAL -> {
                _state.update {
                    it.copy(
                        densityPoints = null,
                        clusters = null
                    )
                }
            }
        }
    }

    /**
     * 검색 반경 업데이트
     */
    fun updateSearchRadius(radius: Float) {
        _state.update { it.copy(searchRadius = radius) }
        debounceSearch()
    }

    /**
     * 카테고리 필터 토글
     */
    fun toggleCategoryFilter(category: String) {
        val categories = _state.value.selectedCategories.toMutableList()
        if (categories.contains(category)) {
            categories.remove(category)
        } else {
            categories.add(category)
        }

        _state.update { it.copy(selectedCategories = categories) }
        debounceSearch()
    }

    /**
     * 시그널 검색
     */
    fun searchSignals(query: String) {
        _state.update {
            it.copy(
                searchQuery = query,
                isLoading = true
            )
        }

        viewModelScope.launch {
            performSearch()
        }
    }

    /**
     * 다각형 점 추가
     */
    fun addPolygonPoint(lat: Double, lon: Double) {
        if (!_state.value.isDrawingPolygon) return

        val points = _state.value.polygonPoints?.toMutableList() ?: mutableListOf()
        points.add(listOf(lon, lat)) // PostGIS 형식: [lon, lat]

        _state.update { it.copy(polygonPoints = points) }

        // 3개 이상의 점이 있으면 검색 수행
        if (points.size >= 3) {
            viewModelScope.launch { performPolygonSearch() }
        }
    }

    /**
     * 다각형 완성
     */
    fun completePolygon() {
        if (_state.value.isPolygonComplete) {
            _state.update { it.copy(isDrawingPolygon = false) }
            viewModelScope.launch { performPolygonSearch() }
        }
    }

    /**
     * 다각형 초기화
     */
    fun clearPolygon() {
        _state.update {
            it.copy(
                polygonPoints = emptyList(),
                isDrawingPolygon = true
            )
        }
    }

    /**
     * 경로 시작점 설정
     */
    fun setRouteStart(lat: Double, lon: Double) {
        _state.update {
            it.copy(
                routeStartLat = lat,
                routeStartLon = lon
            )
        }
    }

    /**
     * 경로 끝점 설정
     */
    fun setRouteEnd(lat: Double, lon: Double) {
        _state.update {
            it.copy(
                routeEndLat = lat,
                routeEndLon = lon,
                isSelectingRoute = false
            )
        }

        if (_state.value.isRouteComplete) {
            viewModelScope.launch { performRouteSearch() }
        }
    }

    /**
     * 경로 버퍼 폭 설정
     */
    fun setRouteBufferWidth(width: Double) {
        _state.update { it.copy(routeBufferWidth = width) }

        if (_state.value.isRouteComplete) {
            debounceSearch()
        }
    }

    /**
     * 시간 필터 설정
     */
    fun toggleTodayOnly() {
        _state.update { it.copy(todayOnly = !it.todayOnly) }
        debounceSearch()
    }

    fun setStartTime(time: LocalTime) {
        _state.update { it.copy(startTime = time) }
        debounceSearch()
    }

    fun setEndTime(time: LocalTime) {
        _state.update { it.copy(endTime = time) }
        debounceSearch()
    }

    /**
     * 거리 범위 설정
     */
    fun setDistanceRange(min: Double, max: Double) {
        _state.update {
            it.copy(
                minDistance = min,
                maxDistance = max
            )
        }
        debounceSearch()
    }

    /**
     * 연령 범위 설정
     */
    fun setAgeRange(min: Int, max: Int) {
        _state.update {
            it.copy(
                minAge = min,
                maxAge = max
            )
        }
        debounceSearch()
    }

    /**
     * 참여자 수 범위 설정
     */
    fun setParticipantRange(min: Int?, max: Int?) {
        _state.update {
            it.copy(
                minParticipants = min,
                maxParticipants = max
            )
        }
        debounceSearch()
    }

    /**
     * 사용 가능한 시그널만 보기 토글
     */
    fun toggleAvailableOnly() {
        _state.update { it.copy(availableOnly = !it.availableOnly) }
        debounceSearch()
    }

    /**
     * 줌 레벨 업데이트
     */
    fun updateZoomLevel(zoomLevel: Int) {
        _state.update { it.copy(currentZoomLevel = zoomLevel) }

        // 줌 레벨에 따른 성능 최적화
        if (zoomLevel < 12 && _state.value.signals.size > 200) {
            performClusterSearch()
        }
    }

    /**
     * 시그널 선택
     */
    fun selectSignal(signal: Signal) {
        _state.update { it.copy(selectedSignal = signal) }
    }

    /**
     * 선택 해제
     */
    fun clearSelection() {
        _state.update { it.copy(selectedSignal = null) }
    }

    /**
     * 필터 초기화
     */
    fun clearFilters() {
        _state.update {
            it.copy(
                selectedCategories = emptyList(),
                searchRadius = 5000f,
                todayOnly = false,
                startTime = null,
                endTime = null,
                minDistance = 0.0,
                maxDistance = 20000.0,
                minAge = 18,
                maxAge = 65,
                minParticipants = null,
                maxParticipants = null,
                availableOnly = false,
                searchQuery = ""
            )
        }
        viewModelScope.launch { performSearch() }
    }

    /**
     * 필터 적용
     */
    fun applyFilters() {
        viewModelScope.launch { performSearch() }
    }

    /**
     * 통계 로드
     */
    fun loadStatistics() {
        if (!_state.value.hasUserLocation) return

        viewModelScope.launch {
            try {
                val statistics = geographicService.getLocationStatistics(
                    latitude = _state.value.userLatitude!!,
                    longitude = _state.value.userLongitude!!,
                    radius = _state.value.searchRadius.toDouble()
                )

                _state.update { it.copy(statistics = statistics) }
            } catch (e: Exception) {
                _state.update { it.copy(error = "통계 로드 실패: ${e.message}") }
            }
        }
    }

    /**
     * POI 분석 로드
     */
    fun loadPoiAnalysis() {
        if (!_state.value.hasUserLocation) return

        viewModelScope.launch {
            try {
                _state.update { it.copy(isLoading = true) }

                val analysis = geographicService.getPoiAnalysis(
                    latitude = _state.value.userLatitude!!,
                    longitude = _state.value.userLongitude!!,
                    radius = _state.value.searchRadius.toDouble()
                )

                _state.update {
                    it.copy(
                        poiAnalysis = analysis,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        isLoading = false,
                        error = "POI 분석 실패: ${e.message}"
                    )
                }
            }
        }
    }

    /**
     * 수동 새로고침
     */
    fun refresh() {
        viewModelScope.launch { performSearch() }
    }

    /**
     * 핫스팟 로드
     */
    fun loadHotspots() {
        if (!_state.value.hasUserLocation) return

        viewModelScope.launch {
            try {
                val hotspots = geographicService.getHotspots(
                    latitude = _state.value.userLatitude!!,
                    longitude = _state.value.userLongitude!!,
                    radius = _state.value.searchRadius.toDouble() * 2 // 더 넓은 범위에서 핫스팟 검색
                )

                _state.update { it.copy(hotspots = hotspots) }
            } catch (e: Exception) {
                _state.update { it.copy(error = "핫스팟 로드 실패: ${e.message}") }
            }
        }
    }

    /**
     * 필터 다이얼로그 표시
     */
    fun showFilterDialog() {
        _state.update { it.copy(showFilterDialog = true) }
    }

    /**
     * 필터 다이얼로그 숨김
     */
    fun hideFilterDialog() {
        _state.update { it.copy(showFilterDialog = false) }
    }

    /**
     * 통계 표시
     */
    fun showStatistics() {
        loadStatistics()
        _state.update { it.copy(showStatistics = true) }
    }

    /**
     * 통계 숨김
     */
    fun hideStatistics() {
        _state.update { it.copy(showStatistics = false) }
    }

    /**
     * 밀도 모드 토글
     */
    fun toggleDensityMode() {
        val newMode = if (_state.value.viewMode == MapViewMode.DENSITY) {
            MapViewMode.NORMAL
        } else {
            MapViewMode.DENSITY
        }
        setViewMode(newMode)
    }

    /**
     * 클러스터 모드 토글
     */
    fun toggleClusterMode() {
        val newMode = if (_state.value.viewMode == MapViewMode.CLUSTER) {
            MapViewMode.NORMAL
        } else {
            MapViewMode.CLUSTER
        }
        setViewMode(newMode)
    }

    // Private Methods

    private fun shouldRefreshSignals(): Boolean {
        val lastUpdate = _state.value.lastUpdateTime ?: return true
        val timeDiff = System.currentTimeMillis() - lastUpdate
        return timeDiff >= 2 * 60 * 1000 // 2분
    }

    private fun debounceSearch() {
        searchDebounceJob?.cancel()
        searchDebounceJob = viewModelScope.launch {
            delay(800)
            performSearch()
        }
    }

    private suspend fun performSearch() {
        if (!_state.value.hasUserLocation) return

        try {
            _state.update { it.copy(isLoading = true, error = null) }

            when (_state.value.searchMode) {
                MapSearchMode.RADIUS -> performRadiusSearch()
                MapSearchMode.POLYGON -> {
                    if (_state.value.isPolygonComplete) {
                        performPolygonSearch()
                    }
                }
                MapSearchMode.ROUTE -> {
                    if (_state.value.isRouteComplete) {
                        performRouteSearch()
                    }
                }
                MapSearchMode.POI -> loadPoiAnalysis()
            }

            _state.update {
                it.copy(
                    isLoading = false,
                    lastUpdateTime = System.currentTimeMillis()
                )
            }
        } catch (e: Exception) {
            _state.update {
                it.copy(
                    isLoading = false,
                    error = "검색 실패: ${e.message}"
                )
            }
        }
    }

    private suspend fun performRadiusSearch() {
        val result = geographicService.advancedSearch(
            latitude = _state.value.userLatitude!!,
            longitude = _state.value.userLongitude!!,
            radius = _state.value.searchRadius.toDouble(),
            categories = if (_state.value.selectedCategories.isNotEmpty()) {
                _state.value.selectedCategories
            } else null,
            searchType = "radius",
            clustering = if (_state.value.shouldEnableClustering) {
                ClusteringParams(
                    enabled = true,
                    distance = 500.0,
                    minPoints = 3
                )
            } else null,
            density = _state.value.viewMode == MapViewMode.DENSITY
        )

        _state.update {
            it.copy(
                signals = result.signals,
                clusters = result.clusters,
                densityPoints = result.densityMap,
                statistics = result.statistics
            )
        }
    }

    private suspend fun performPolygonSearch() {
        val polygonPoints = _state.value.polygonPoints
        if (polygonPoints == null || polygonPoints.size < 3) return

        val signals = geographicService.searchInPolygon(
            polygon = polygonPoints,
            categories = if (_state.value.selectedCategories.isNotEmpty()) {
                _state.value.selectedCategories
            } else null
        )

        _state.update { it.copy(signals = signals) }
    }

    private suspend fun performRouteSearch() {
        if (!_state.value.isRouteComplete) return

        val signals = geographicService.searchAlongRoute(
            startLat = _state.value.routeStartLat!!,
            startLon = _state.value.routeStartLon!!,
            endLat = _state.value.routeEndLat!!,
            endLon = _state.value.routeEndLon!!,
            bufferWidth = _state.value.routeBufferWidth,
            categories = if (_state.value.selectedCategories.isNotEmpty()) {
                _state.value.selectedCategories
            } else null
        )

        _state.update { it.copy(signals = signals) }
    }

    private fun performClusterSearch() {
        if (!_state.value.hasUserLocation) return

        viewModelScope.launch {
            val result = geographicService.advancedSearch(
                latitude = _state.value.userLatitude!!,
                longitude = _state.value.userLongitude!!,
                radius = _state.value.searchRadius.toDouble(),
                clustering = ClusteringParams(
                    enabled = true,
                    distance = getClusterDistance(),
                    minPoints = 2
                )
            )

            _state.update {
                it.copy(
                    signals = result.signals,
                    clusters = result.clusters
                )
            }
        }
    }

    private fun loadDensityData() {
        if (!_state.value.hasUserLocation) return

        viewModelScope.launch {
            try {
                val densityPoints = geographicService.getDensityMap(
                    latitude = _state.value.userLatitude!!,
                    longitude = _state.value.userLongitude!!,
                    radius = _state.value.searchRadius.toDouble()
                )

                _state.update { it.copy(densityPoints = densityPoints) }
            } catch (e: Exception) {
                _state.update { it.copy(error = "밀도 데이터 로드 실패: ${e.message}") }
            }
        }
    }

    private fun getClusterDistance(): Double {
        // 줌 레벨에 따른 클러스터링 거리 조정
        return when (_state.value.currentZoomLevel) {
            in 0..9 -> 2000.0
            in 10..11 -> 1000.0
            in 12..13 -> 500.0
            else -> 200.0
        }
    }

    override fun onCleared() {
        super.onCleared()
        searchDebounceJob?.cancel()
        locationUpdateJob?.cancel()
        webSocketJob?.cancel()
        webSocketService.disconnect()
        locationService.dispose()
    }
}

/**
 * 성능 최적화를 위한 확장
 */
class EnhancedMapViewModelPerformance(private val viewModel: EnhancedMapViewModel) {

    /**
     * 메모리 최적화
     */
    fun optimizeMemory() {
        val currentState = viewModel.state.value
        if (currentState.signals.size > currentState.maxMarkersToShow) {
            val optimizedSignals = currentState.signals
                .take(currentState.maxMarkersToShow)

            viewModel._state.update { it.copy(signals = optimizedSignals) }
        }
    }

    /**
     * 배터리 최적화 모드
     */
    fun enableBatteryOptimization() {
        viewModel._state.update {
            it.copy(
                enableClustering = true,
                maxMarkersToShow = 50
            )
        }
    }

    /**
     * 성능 모드 설정
     */
    fun setPerformanceMode(highPerformance: Boolean) {
        if (highPerformance) {
            viewModel._state.update {
                it.copy(
                    enableClustering = true,
                    maxMarkersToShow = 200
                )
            }
        } else {
            viewModel._state.update {
                it.copy(
                    enableClustering = false,
                    maxMarkersToShow = 50
                )
            }
        }
    }
}