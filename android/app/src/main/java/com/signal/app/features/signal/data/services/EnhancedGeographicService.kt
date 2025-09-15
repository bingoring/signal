package com.signal.app.features.signal.data.services

import com.signal.app.core.network.ApiClient
import com.signal.app.core.network.ApiException
import com.signal.app.features.signal.data.models.Signal
import com.signal.app.features.signal.data.models.SignalWithDistance
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * PostGIS 기반 고급 지리적 검색 서비스
 */
@Singleton
class EnhancedGeographicService @Inject constructor(
    private val apiClient: ApiClient
) {

    /**
     * 고급 지리적 검색
     */
    suspend fun advancedSearch(
        latitude: Double,
        longitude: Double,
        radius: Double? = null,
        minRadius: Double? = null,
        maxRadius: Double? = null,
        categories: List<String>? = null,
        searchType: String = "radius",
        polygon: List<List<Double>>? = null,
        route: RouteSearchParams? = null,
        timeFilter: TimeFilterParams? = null,
        density: Boolean = false,
        clustering: ClusteringParams? = null,
        page: Int = 1,
        limit: Int = 20
    ): GeographicSearchResult = withContext(Dispatchers.IO) {
        try {
            val requestBody = buildMap<String, Any> {
                put("latitude", latitude)
                put("longitude", longitude)
                put("radius", radius ?: 5000.0)
                minRadius?.let { put("min_radius", it) }
                maxRadius?.let { put("max_radius", it) }
                categories?.takeIf { it.isNotEmpty() }?.let { put("categories", it) }
                put("search_type", searchType)
                polygon?.let { put("polygon", it) }
                route?.let { put("route", it.toMap()) }
                timeFilter?.let { put("time_filter", it.toMap()) }
                put("density", density)
                clustering?.let { put("clustering", it.toMap()) }
                put("page", page)
                put("limit", limit)
            }

            val response = apiClient.post<Map<String, Any>>(
                "/geographic/search",
                requestBody
            )

            GeographicSearchResult.fromMap(response)
        } catch (e: Exception) {
            throw ApiException("고급 검색에 실패했습니다: ${e.message}")
        }
    }

    /**
     * 밀도 맵 조회
     */
    suspend fun getDensityMap(
        latitude: Double,
        longitude: Double,
        radius: Double = 5000.0,
        gridSize: Double = 0.01
    ): List<DensityPoint> = withContext(Dispatchers.IO) {
        try {
            val queryParams = mapOf(
                "lat" to latitude.toString(),
                "lon" to longitude.toString(),
                "radius" to radius.toString(),
                "grid_size" to gridSize.toString()
            )

            val response = apiClient.get<Map<String, Any>>(
                "/geographic/density",
                queryParams
            )

            @Suppress("UNCHECKED_CAST")
            val densityData = response["data"] as List<Map<String, Any>>
            densityData.map { DensityPoint.fromMap(it) }
        } catch (e: Exception) {
            throw ApiException("밀도 맵 조회에 실패했습니다: ${e.message}")
        }
    }

    /**
     * 핫스팟 분석
     */
    suspend fun getHotspots(
        latitude: Double,
        longitude: Double,
        radius: Double = 10000.0,
        minSignals: Int = 5
    ): List<Hotspot> = withContext(Dispatchers.IO) {
        try {
            val queryParams = mapOf(
                "lat" to latitude.toString(),
                "lon" to longitude.toString(),
                "radius" to radius.toString(),
                "min_signals" to minSignals.toString()
            )

            val response = apiClient.get<Map<String, Any>>(
                "/geographic/hotspots",
                queryParams
            )

            @Suppress("UNCHECKED_CAST")
            val hotspotsData = response["data"] as List<Map<String, Any>>
            hotspotsData.map { Hotspot.fromMap(it) }
        } catch (e: Exception) {
            throw ApiException("핫스팟 분석에 실패했습니다: ${e.message}")
        }
    }

    /**
     * 다각형 영역 검색
     */
    suspend fun searchInPolygon(
        polygon: List<List<Double>>,
        categories: List<String>? = null,
        page: Int = 1,
        limit: Int = 20
    ): List<SignalWithDistance> = withContext(Dispatchers.IO) {
        try {
            val requestBody = buildMap<String, Any> {
                put("polygon", polygon)
                categories?.let { put("categories", it) }
                put("page", page)
                put("limit", limit)
            }

            val response = apiClient.post<Map<String, Any>>(
                "/geographic/polygon",
                requestBody
            )

            @Suppress("UNCHECKED_CAST")
            val signalsData = response["data"] as List<Map<String, Any>>
            signalsData.map { SignalWithDistance.fromMap(it) }
        } catch (e: Exception) {
            throw ApiException("다각형 검색에 실패했습니다: ${e.message}")
        }
    }

    /**
     * 경로 기반 검색
     */
    suspend fun searchAlongRoute(
        startLat: Double,
        startLon: Double,
        endLat: Double,
        endLon: Double,
        bufferWidth: Double = 1000.0,
        categories: List<String>? = null,
        page: Int = 1,
        limit: Int = 20
    ): List<SignalWithDistance> = withContext(Dispatchers.IO) {
        try {
            val requestBody = buildMap<String, Any> {
                put("start_lat", startLat)
                put("start_lon", startLon)
                put("end_lat", endLat)
                put("end_lon", endLon)
                put("buffer_width", bufferWidth)
                categories?.let { put("categories", it) }
                put("page", page)
                put("limit", limit)
            }

            val response = apiClient.post<Map<String, Any>>(
                "/geographic/route",
                requestBody
            )

            @Suppress("UNCHECKED_CAST")
            val signalsData = response["data"] as List<Map<String, Any>>
            signalsData.map { SignalWithDistance.fromMap(it) }
        } catch (e: Exception) {
            throw ApiException("경로 검색에 실패했습니다: ${e.message}")
        }
    }

    /**
     * 지역 통계
     */
    suspend fun getLocationStatistics(
        latitude: Double,
        longitude: Double,
        radius: Double = 5000.0
    ): GeographicStatistics = withContext(Dispatchers.IO) {
        try {
            val queryParams = mapOf(
                "lat" to latitude.toString(),
                "lon" to longitude.toString(),
                "radius" to radius.toString()
            )

            val response = apiClient.get<Map<String, Any>>(
                "/geographic/statistics",
                queryParams
            )

            @Suppress("UNCHECKED_CAST")
            val statisticsData = response["data"] as Map<String, Any>
            GeographicStatistics.fromMap(statisticsData)
        } catch (e: Exception) {
            throw ApiException("지역 통계 조회에 실패했습니다: ${e.message}")
        }
    }

    /**
     * POI 분석
     */
    suspend fun getPoiAnalysis(
        latitude: Double,
        longitude: Double,
        radius: Double = 2000.0
    ): PoiAnalysisResult = withContext(Dispatchers.IO) {
        try {
            val queryParams = mapOf(
                "lat" to latitude.toString(),
                "lon" to longitude.toString(),
                "radius" to radius.toString()
            )

            val response = apiClient.get<Map<String, Any>>(
                "/geographic/poi-analysis",
                queryParams
            )

            @Suppress("UNCHECKED_CAST")
            val analysisData = response["data"] as Map<String, Any>
            PoiAnalysisResult.fromMap(analysisData)
        } catch (e: Exception) {
            throw ApiException("POI 분석에 실패했습니다: ${e.message}")
        }
    }
}

/**
 * 고급 검색 결과
 */
data class GeographicSearchResult(
    val signals: List<SignalWithDistance>,
    val clusters: List<SignalCluster>? = null,
    val densityMap: List<DensityPoint>? = null,
    val statistics: GeographicStatistics
) {
    companion object {
        fun fromMap(map: Map<String, Any>): GeographicSearchResult {
            @Suppress("UNCHECKED_CAST")
            return GeographicSearchResult(
                signals = (map["signals"] as? List<Map<String, Any>>)
                    ?.map { SignalWithDistance.fromMap(it) } ?: emptyList(),
                clusters = (map["clusters"] as? List<Map<String, Any>>)
                    ?.map { SignalCluster.fromMap(it) },
                densityMap = (map["density_map"] as? List<Map<String, Any>>)
                    ?.map { DensityPoint.fromMap(it) },
                statistics = GeographicStatistics.fromMap(map["statistics"] as Map<String, Any>)
            )
        }
    }
}

/**
 * 시그널 클러스터
 */
data class SignalCluster(
    val id: String,
    val centerLat: Double,
    val centerLon: Double,
    val radius: Double,
    val signalCount: Int,
    val signals: List<SignalWithDistance>? = null,
    val avgDistance: Double
) {
    companion object {
        fun fromMap(map: Map<String, Any>): SignalCluster {
            @Suppress("UNCHECKED_CAST")
            return SignalCluster(
                id = map["id"] as String,
                centerLat = (map["center_lat"] as Number).toDouble(),
                centerLon = (map["center_lon"] as Number).toDouble(),
                radius = (map["radius"] as Number).toDouble(),
                signalCount = map["signal_count"] as Int,
                signals = (map["signals"] as? List<Map<String, Any>>)
                    ?.map { SignalWithDistance.fromMap(it) },
                avgDistance = (map["avg_distance"] as Number).toDouble()
            )
        }
    }
}

/**
 * 밀도 포인트
 */
data class DensityPoint(
    val latitude: Double,
    val longitude: Double,
    val density: Int,
    val weight: Double
) {
    companion object {
        fun fromMap(map: Map<String, Any>): DensityPoint {
            return DensityPoint(
                latitude = (map["latitude"] as Number).toDouble(),
                longitude = (map["longitude"] as Number).toDouble(),
                density = map["density"] as Int,
                weight = (map["weight"] as Number).toDouble()
            )
        }
    }
}

/**
 * 지리적 통계
 */
data class GeographicStatistics(
    val totalSignals: Int,
    val averageDistance: Double,
    val categories: Map<String, Int>,
    val timeDistribution: Map<String, Int>,
    val radialDistribution: List<RadialBucket>
) {
    companion object {
        fun fromMap(map: Map<String, Any>): GeographicStatistics {
            @Suppress("UNCHECKED_CAST")
            return GeographicStatistics(
                totalSignals = map["total_signals"] as Int,
                averageDistance = (map["average_distance"] as Number).toDouble(),
                categories = map["categories"] as Map<String, Int>,
                timeDistribution = map["time_distribution"] as Map<String, Int>,
                radialDistribution = (map["radial_distribution"] as List<Map<String, Any>>)
                    .map { RadialBucket.fromMap(it) }
            )
        }
    }
}

/**
 * 반경별 분포
 */
data class RadialBucket(
    val minDistance: Double,
    val maxDistance: Double,
    val count: Int
) {
    companion object {
        fun fromMap(map: Map<String, Any>): RadialBucket {
            return RadialBucket(
                minDistance = (map["min_distance"] as Number).toDouble(),
                maxDistance = (map["max_distance"] as Number).toDouble(),
                count = map["count"] as Int
            )
        }
    }
}

/**
 * 경로 검색 파라미터
 */
data class RouteSearchParams(
    val startLat: Double,
    val startLon: Double,
    val endLat: Double,
    val endLon: Double,
    val bufferWidth: Double = 1000.0
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "start_lat" to startLat,
            "start_lon" to startLon,
            "end_lat" to endLat,
            "end_lon" to endLon,
            "buffer_width" to bufferWidth
        )
    }
}

/**
 * 시간 필터 파라미터
 */
data class TimeFilterParams(
    val startTime: String? = null,
    val endTime: String? = null,
    val timeSlots: List<String>? = null,
    val weekdays: List<Int>? = null
) {
    fun toMap(): Map<String, Any> {
        return buildMap {
            startTime?.let { put("start_time", it) }
            endTime?.let { put("end_time", it) }
            timeSlots?.let { put("time_slots", it) }
            weekdays?.let { put("weekdays", it) }
        }
    }
}

/**
 * 클러스터링 파라미터
 */
data class ClusteringParams(
    val enabled: Boolean = true,
    val distance: Double = 500.0,
    val minPoints: Int = 2
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "enabled" to enabled,
            "distance" to distance,
            "min_points" to minPoints
        )
    }
}

/**
 * 핫스팟 정보
 */
data class Hotspot(
    val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val signalCount: Int,
    val category: String,
    val score: Double
) {
    companion object {
        fun fromMap(map: Map<String, Any>): Hotspot {
            return Hotspot(
                id = map["id"] as String,
                name = map["name"] as String,
                latitude = (map["latitude"] as Number).toDouble(),
                longitude = (map["longitude"] as Number).toDouble(),
                signalCount = map["signal_count"] as Int,
                category = map["category"] as String,
                score = (map["score"] as Number).toDouble()
            )
        }
    }
}

/**
 * POI 분석 결과
 */
data class PoiAnalysisResult(
    val totalSignals: Int,
    val clusters: List<SignalCluster>,
    val densityPoints: List<DensityPoint>,
    val categoryDistribution: Map<String, Int>,
    val timeDistribution: Map<String, Int>,
    val averageDistance: Double,
    val analysisCenter: Map<String, Double>,
    val analysisRadius: Double
) {
    companion object {
        fun fromMap(map: Map<String, Any>): PoiAnalysisResult {
            @Suppress("UNCHECKED_CAST")
            return PoiAnalysisResult(
                totalSignals = map["total_signals"] as Int,
                clusters = (map["clusters"] as List<Map<String, Any>>)
                    .map { SignalCluster.fromMap(it) },
                densityPoints = (map["density_points"] as List<Map<String, Any>>)
                    .map { DensityPoint.fromMap(it) },
                categoryDistribution = map["category_distribution"] as Map<String, Int>,
                timeDistribution = map["time_distribution"] as Map<String, Int>,
                averageDistance = (map["average_distance"] as Number).toDouble(),
                analysisCenter = map["analysis_center"] as Map<String, Double>,
                analysisRadius = (map["analysis_radius"] as Number).toDouble()
            )
        }
    }
}