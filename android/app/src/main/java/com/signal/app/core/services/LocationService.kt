package com.signal.app.core.services

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.*
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 위치 서비스 관리 클래스
 * Flutter LocationService와 동일한 기능을 Android에서 제공
 */
@Singleton
class LocationService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val fusedLocationClient: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(context)
    }

    private var locationCallback: LocationCallback? = null
    private var isTracking = false
    private var lastKnownLocation: Location? = null

    /**
     * 위치 권한 상태
     */
    enum class LocationPermissionResult {
        GRANTED,
        DENIED,
        PERMANENTLY_DENIED,
        SERVICE_DISABLED,
        ERROR
    }

    /**
     * 위치 권한 확인
     */
    fun checkLocationPermission(): LocationPermissionResult {
        return when {
            ActivityCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                    ActivityCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED -> {
                LocationPermissionResult.GRANTED
            }
            else -> LocationPermissionResult.DENIED
        }
    }

    /**
     * 현재 위치 가져오기 (일회성)
     */
    @SuppressLint("MissingPermission")
    suspend fun getCurrentLocation(): Location? {
        return try {
            if (checkLocationPermission() != LocationPermissionResult.GRANTED) {
                throw LocationPermissionException(LocationPermissionResult.DENIED)
            }

            var location: Location? = null
            
            // 마지막 알려진 위치 먼저 시도
            fusedLocationClient.lastLocation.addOnSuccessListener { lastLocation ->
                if (lastLocation != null) {
                    lastKnownLocation = lastLocation
                    location = lastLocation
                }
            }.addOnFailureListener { exception ->
                throw exception
            }

            // 캐시된 위치가 있다면 반환
            if (lastKnownLocation != null) {
                return lastKnownLocation
            }

            // 새로운 위치 요청
            val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 15000)
                .setWaitForAccurateLocation(false)
                .setMinUpdateIntervalMillis(5000)
                .setMaxUpdateDelayMillis(30000)
                .build()

            fusedLocationClient.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
                .addOnSuccessListener { currentLocation ->
                    if (currentLocation != null) {
                        lastKnownLocation = currentLocation
                        location = currentLocation
                    }
                }

            location
        } catch (e: Exception) {
            println("현재 위치 가져오기 실패: ${e.message}")
            lastKnownLocation // 캐시된 위치 반환
        }
    }

    /**
     * 위치 추적 시작
     */
    @SuppressLint("MissingPermission")
    fun startLocationTracking(
        accuracy: Int = Priority.PRIORITY_HIGH_ACCURACY,
        distanceFilter: Float = 10f, // 최소 이동 거리 (미터)
        timeInterval: Long = 5000L // 업데이트 간격 (밀리초)
    ): Flow<Location> = callbackFlow {
        if (checkLocationPermission() != LocationPermissionResult.GRANTED) {
            close(LocationPermissionException(LocationPermissionResult.DENIED))
            return@callbackFlow
        }

        val locationRequest = LocationRequest.Builder(accuracy, timeInterval)
            .setWaitForAccurateLocation(false)
            .setMinUpdateIntervalMillis(timeInterval)
            .setMinUpdateDistanceMeters(distanceFilter)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.locations.forEach { location ->
                    lastKnownLocation = location
                    trySend(location)
                }
            }

            override fun onLocationAvailability(availability: LocationAvailability) {
                if (!availability.isLocationAvailable) {
                    println("위치 서비스를 사용할 수 없습니다")
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback!!,
                Looper.getMainLooper()
            )
            isTracking = true

            // 초기 위치 가져오기
            getCurrentLocation()?.let { initialLocation ->
                trySend(initialLocation)
            }
        } catch (e: Exception) {
            close(e)
        }

        awaitClose {
            stopLocationTracking()
        }
    }.distinctUntilChanged { old, new ->
        // 위치 변화가 distanceFilter 이하이면 중복 제거
        old.distanceTo(new) < distanceFilter
    }

    /**
     * 위치 추적 중지
     */
    fun stopLocationTracking() {
        locationCallback?.let { callback ->
            fusedLocationClient.removeLocationUpdates(callback)
            locationCallback = null
            isTracking = false
        }
    }

    /**
     * 두 지점 간 거리 계산 (미터)
     */
    fun calculateDistance(
        startLat: Double,
        startLon: Double,
        endLat: Double,
        endLon: Double
    ): Float {
        val results = FloatArray(1)
        Location.distanceBetween(startLat, startLon, endLat, endLon, results)
        return results[0]
    }

    /**
     * 위치 정확도 레벨별 설명
     */
    fun getAccuracyDescription(accuracy: Int): String {
        return when (accuracy) {
            Priority.PRIORITY_NO_POWER -> "전력 사용 없음 (~수 킬로미터)"
            Priority.PRIORITY_LOW_POWER -> "저전력 (~1000m)"
            Priority.PRIORITY_BALANCED_POWER_ACCURACY -> "균형 (~100m)"
            Priority.PRIORITY_HIGH_ACCURACY -> "높은 정확도 (~10m)"
            else -> "알 수 없음"
        }
    }

    /**
     * 마지막 알려진 위치
     */
    fun getLastKnownLocation(): Location? = lastKnownLocation

    /**
     * 위치 추적 상태
     */
    fun isLocationTrackingActive(): Boolean = isTracking

    /**
     * 리소스 정리
     */
    fun cleanup() {
        stopLocationTracking()
    }
}

/**
 * 위치 권한 예외
 */
class LocationPermissionException(val result: LocationService.LocationPermissionResult) : Exception() {
    override val message: String
        get() = when (result) {
            LocationService.LocationPermissionResult.DENIED -> "위치 권한이 거부되었습니다."
            LocationService.LocationPermissionResult.PERMANENTLY_DENIED -> "위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해 주세요."
            LocationService.LocationPermissionResult.SERVICE_DISABLED -> "위치 서비스가 비활성화되어 있습니다. 설정에서 위치 서비스를 활성화해 주세요."
            LocationService.LocationPermissionResult.ERROR -> "위치 권한 확인 중 오류가 발생했습니다."
            else -> "알 수 없는 위치 권한 오류가 발생했습니다."
        }

    fun getUserFriendlyMessage(): String {
        return when (result) {
            LocationService.LocationPermissionResult.DENIED -> "정확한 시그널 정보를 위해 위치 권한이 필요합니다."
            LocationService.LocationPermissionResult.PERMANENTLY_DENIED -> "설정에서 위치 권한을 허용한 후 다시 시도해 주세요."
            LocationService.LocationPermissionResult.SERVICE_DISABLED -> "기기의 위치 서비스를 활성화해 주세요."
            LocationService.LocationPermissionResult.ERROR -> "위치 권한을 확인할 수 없습니다. 다시 시도해 주세요."
            else -> "위치 서비스를 사용할 수 없습니다."
        }
    }
}