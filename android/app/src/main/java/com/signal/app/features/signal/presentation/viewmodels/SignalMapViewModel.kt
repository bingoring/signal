package com.signal.app.features.signal.presentation.viewmodels

import android.location.Location
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.signal.app.core.services.LocationService
import com.signal.app.features.signal.data.models.MapBounds
import com.signal.app.features.signal.data.models.SignalWithDistance
import com.signal.app.features.signal.data.services.SignalApiService
import com.signal.app.features.signal.data.services.SignalWebSocketService
import com.signal.app.features.signal.data.services.WebSocketMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import javax.inject.Inject

/**
 * Signal 지도 화면 ViewModel
 * Flutter SignalMapCubit과 동일한 기능을 Android에서 제공
 */
@HiltViewModel
class SignalMapViewModel @Inject constructor(
    private val locationService: LocationService,
    private val signalApiService: SignalApiService,
    private val webSocketService: SignalWebSocketService
) : ViewModel() {

    private val _uiState = MutableStateFlow(SignalMapUiState())
    val uiState: StateFlow<SignalMapUiState> = _uiState.asStateFlow()

    private var locationTrackingJob: Job? = null
    private var webSocketJob: Job? = null
    private var locationUpdateJob: Job? = null

    init {
        initializeLocationTracking()
        connectWebSocket()
    }

    /**
     * 위치 추적 초기화
     */
    private fun initializeLocationTracking() {
        locationTrackingJob = viewModelScope.launch {
            try {
                // 현재 위치 가져오기
                val currentLocation = locationService.getCurrentLocation()
                if (currentLocation != null) {
                    updateUserLocation(currentLocation)
                }

                // 위치 추적 시작
                locationService.startLocationTracking(distanceFilter = 50f)
                    .collect { location ->
                        updateUserLocation(location)
                    }
            } catch (e: Exception) {
                updateError("위치 정보를 가져올 수 없습니다: ${e.message}")
            }
        }
    }

    /**
     * WebSocket 연결
     */
    private fun connectWebSocket() {
        webSocketJob = viewModelScope.launch {
            try {
                webSocketService.connect()
                    .collect { message ->
                        handleWebSocketMessage(message)
                    }
            } catch (e: Exception) {
                updateError("실시간 업데이트 연결에 실패했습니다: ${e.message}")
            }
        }
    }

    /**
     * WebSocket 메시지 처리
     */
    private fun handleWebSocketMessage(message: WebSocketMessage) {
        when (message) {
            is WebSocketMessage.SignalCreated -> {
                if (isSignalInBounds(message.signal)) {
                    val currentSignals = _uiState.value.signals.toMutableList()
                    currentSignals.add(message.signal)
                    _uiState.value = _uiState.value.copy(
                        signals = currentSignals,
                        lastUpdateTime = LocalDateTime.now()
                    )
                }
            }
            is WebSocketMessage.SignalUpdated -> {
                val currentSignals = _uiState.value.signals.toMutableList()
                val index = currentSignals.indexOfFirst { it.signal.id == message.signal.signal.id }
                if (index >= 0) {
                    currentSignals[index] = message.signal
                    _uiState.value = _uiState.value.copy(
                        signals = currentSignals,
                        lastUpdateTime = LocalDateTime.now()
                    )
                }
            }
            is WebSocketMessage.SignalDeleted -> {
                val currentSignals = _uiState.value.signals.filterNot { it.signal.id == message.signalId }
                _uiState.value = _uiState.value.copy(
                    signals = currentSignals,
                    lastUpdateTime = LocalDateTime.now()
                )
            }
            is WebSocketMessage.SignalJoined, is WebSocketMessage.SignalLeft -> {
                val signalId = when (message) {
                    is WebSocketMessage.SignalJoined -> message.signalId
                    is WebSocketMessage.SignalLeft -> message.signalId
                    else -> null
                }
                val newParticipants = when (message) {
                    is WebSocketMessage.SignalJoined -> message.currentParticipants
                    is WebSocketMessage.SignalLeft -> message.currentParticipants
                    else -> null
                }
                
                if (signalId != null && newParticipants != null) {
                    val currentSignals = _uiState.value.signals.toMutableList()
                    val index = currentSignals.indexOfFirst { it.signal.id == signalId }
                    if (index >= 0) {
                        val updatedSignal = currentSignals[index].signal.copy(currentParticipants = newParticipants)
                        currentSignals[index] = currentSignals[index].copy(signal = updatedSignal)
                        _uiState.value = _uiState.value.copy(
                            signals = currentSignals,
                            lastUpdateTime = LocalDateTime.now()
                        )
                    }
                }
            }
            is WebSocketMessage.Error -> {
                updateError("서버 오류: ${message.message}")
            }
            else -> {
                // 기타 메시지 처리
            }
        }
    }

    /**
     * 사용자 위치 업데이트
     */
    private suspend fun updateUserLocation(location: Location) {
        _uiState.value = _uiState.value.copy(
            userLocation = location,
            hasLocationPermission = true
        )

        // WebSocket으로 위치 업데이트 전송
        webSocketService.sendLocationUpdate(
            location.latitude, 
            location.longitude, 
            _uiState.value.searchRadius
        )

        // 처음 위치를 얻었거나 일정 시간이 지났으면 근처 시그널 로드
        val shouldRefresh = _uiState.value.signals.isEmpty() || shouldRefreshSignals()
        if (shouldRefresh) {
            loadNearbySignals(location.latitude, location.longitude)
        }
    }

    /**
     * 근처 시그널 로드
     */
    fun loadNearbySignals(latitude: Double, longitude: Double, radius: Double? = null) {
        viewModelScope.launch {
            try {
                _uiState.value = _uiState.value.copy(isLoading = true, error = null)

                val searchRadius = radius ?: _uiState.value.searchRadius
                val categories = _uiState.value.selectedCategories.takeIf { it.isNotEmpty() }

                val signals = signalApiService.getNearbySignals(
                    latitude = latitude,
                    longitude = longitude,
                    radius = searchRadius,
                    categories = categories
                )

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    signals = signals,
                    lastUpdateTime = LocalDateTime.now(),
                    error = null
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "근처 시그널을 불러오는데 실패했습니다: ${e.message}"
                )
            }
        }
    }

    /**
     * 지도 범위 업데이트
     */
    fun updateMapBounds(centerLat: Double, centerLon: Double) {
        val radiusInDegrees = _uiState.value.searchRadius / 111320.0 // 대략적인 변환

        val bounds = MapBounds(
            minLat = centerLat - radiusInDegrees,
            maxLat = centerLat + radiusInDegrees,
            minLon = centerLon - radiusInDegrees,
            maxLon = centerLon + radiusInDegrees
        )

        _uiState.value = _uiState.value.copy(mapBounds = bounds)

        // 범위가 크게 변경되었으면 새로운 시그널 로드
        scheduleLocationUpdate(centerLat, centerLon)
    }

    /**
     * 지연된 위치 업데이트 스케줄링
     */
    private fun scheduleLocationUpdate(lat: Double, lon: Double) {
        locationUpdateJob?.cancel()
        locationUpdateJob = viewModelScope.launch {
            delay(500) // 500ms 지연
            loadNearbySignals(lat, lon)
        }
    }

    /**
     * 시그널 검색
     */
    fun searchSignals(query: String) {
        viewModelScope.launch {
            try {
                _uiState.value = _uiState.value.copy(isLoading = true, error = null)

                val userLocation = _uiState.value.userLocation
                val results = signalApiService.searchSignals(
                    query = query,
                    latitude = userLocation?.latitude,
                    longitude = userLocation?.longitude,
                    radius = _uiState.value.searchRadius
                )

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    signals = results,
                    searchQuery = query,
                    lastUpdateTime = LocalDateTime.now()
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "검색에 실패했습니다: ${e.message}"
                )
            }
        }
    }

    /**
     * 수동 새로고침
     */
    fun refreshNearbySignals() {
        _uiState.value.userLocation?.let { location ->
            loadNearbySignals(location.latitude, location.longitude)
        }
    }

    /**
     * 필터 업데이트
     */
    fun updateFilters(categories: List<String>, radius: Double) {
        _uiState.value = _uiState.value.copy(
            selectedCategories = categories,
            searchRadius = radius
        )

        _uiState.value.userLocation?.let { location ->
            loadNearbySignals(location.latitude, location.longitude, radius)
        }
    }

    /**
     * 시그널 참여
     */
    fun joinSignal(signalId: Int, message: String?) {
        viewModelScope.launch {
            try {
                signalApiService.joinSignal(signalId, com.signal.app.features.signal.data.services.JoinSignalRequest(message))
                _uiState.value = _uiState.value.copy(error = null)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(error = "시그널 참여에 실패했습니다: ${e.message}")
            }
        }
    }

    /**
     * 시그널 나가기
     */
    fun leaveSignal(signalId: Int) {
        viewModelScope.launch {
            try {
                signalApiService.leaveSignal(signalId)
                _uiState.value = _uiState.value.copy(error = null)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(error = "시그널 나가기에 실패했습니다: ${e.message}")
            }
        }
    }

    /**
     * 내 위치로 이동
     */
    suspend fun moveToMyLocation(): Location? {
        return try {
            locationService.getCurrentLocation()
        } catch (e: Exception) {
            updateError("현재 위치를 가져올 수 없습니다: ${e.message}")
            null
        }
    }

    /**
     * 에러 정리
     */
    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    /**
     * Helper functions
     */
    private fun isSignalInBounds(signal: SignalWithDistance): Boolean {
        val bounds = _uiState.value.mapBounds ?: return true
        return bounds.contains(signal.signal.latitude, signal.signal.longitude)
    }

    private fun shouldRefreshSignals(): Boolean {
        val lastUpdate = _uiState.value.lastUpdateTime ?: return true
        val timeDiff = java.time.Duration.between(lastUpdate, LocalDateTime.now())
        return timeDiff.toMinutes() >= 2 // 2분마다 새로고침
    }

    private fun updateError(message: String) {
        _uiState.value = _uiState.value.copy(error = message)
    }

    override fun onCleared() {
        super.onCleared()
        locationTrackingJob?.cancel()
        webSocketJob?.cancel()
        locationUpdateJob?.cancel()
        locationService.cleanup()
        webSocketService.disconnect()
    }
}

/**
 * UI 상태 데이터 클래스
 */
data class SignalMapUiState(
    val isLoading: Boolean = false,
    val signals: List<SignalWithDistance> = emptyList(),
    val userLocation: Location? = null,
    val hasLocationPermission: Boolean = false,
    val selectedCategories: List<String> = emptyList(),
    val searchRadius: Double = 1000.0, // 미터
    val searchQuery: String = "",
    val mapBounds: MapBounds? = null,
    val lastUpdateTime: LocalDateTime? = null,
    val error: String? = null
) {
    val hasActiveFilters: Boolean
        get() = selectedCategories.isNotEmpty() || searchRadius != 1000.0
}