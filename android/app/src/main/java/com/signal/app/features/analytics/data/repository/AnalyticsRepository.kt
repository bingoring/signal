package com.signal.app.features.analytics.data.repository

import com.signal.app.core.network.ApiResult
import com.signal.app.core.network.NetworkClient
import com.signal.app.features.analytics.data.models.*
import io.ktor.client.request.*
import io.ktor.http.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import javax.inject.Inject
import javax.inject.Singleton

interface AnalyticsRepository {
    suspend fun getUserAnalytics(userId: Int, week: String? = null): Flow<ApiResult<UserAnalytics>>
    suspend fun getUserAnalyticsHistory(userId: Int, weeks: Int = 4): Flow<ApiResult<List<UserAnalytics>>>
    suspend fun getUserAchievements(userId: Int): Flow<ApiResult<AchievementData>>
    suspend fun getAnalyticsSummary(userId: Int): Flow<ApiResult<AnalyticsSummary>>
    suspend fun regenerateAnalytics(userId: Int, week: String? = null): Flow<ApiResult<UserAnalytics>>
}

@Singleton
class AnalyticsRepositoryImpl @Inject constructor(
    private val networkClient: NetworkClient
) : AnalyticsRepository {

    override suspend fun getUserAnalytics(userId: Int, week: String?): Flow<ApiResult<UserAnalytics>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.get("/api/analytics/user/$userId") {
                week?.let { parameter("week", it) }
            }
            
            if (response.status.isSuccess()) {
                val apiResponse = networkClient.handleResponse<ApiResponse<UserAnalytics>>(response)
                if (apiResponse.success) {
                    emit(ApiResult.Success(apiResponse.data))
                } else {
                    emit(ApiResult.Error(apiResponse.message ?: "Unknown error"))
                }
            } else {
                emit(ApiResult.Error("Failed to fetch user analytics"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Network error occurred"))
        }
    }

    override suspend fun getUserAnalyticsHistory(userId: Int, weeks: Int): Flow<ApiResult<List<UserAnalytics>>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.get("/api/analytics/user/$userId/history") {
                parameter("weeks", weeks)
            }
            
            if (response.status.isSuccess()) {
                val apiResponse = networkClient.handleResponse<ApiResponse<AnalyticsHistoryResponse>>(response)
                if (apiResponse.success) {
                    emit(ApiResult.Success(apiResponse.data.history))
                } else {
                    emit(ApiResult.Error(apiResponse.message ?: "Unknown error"))
                }
            } else {
                emit(ApiResult.Error("Failed to fetch analytics history"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Network error occurred"))
        }
    }

    override suspend fun getUserAchievements(userId: Int): Flow<ApiResult<AchievementData>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.get("/api/analytics/user/$userId/achievements")
            
            if (response.status.isSuccess()) {
                val apiResponse = networkClient.handleResponse<ApiResponse<AchievementData>>(response)
                if (apiResponse.success) {
                    emit(ApiResult.Success(apiResponse.data))
                } else {
                    emit(ApiResult.Error(apiResponse.message ?: "Unknown error"))
                }
            } else {
                emit(ApiResult.Error("Failed to fetch user achievements"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Network error occurred"))
        }
    }

    override suspend fun getAnalyticsSummary(userId: Int): Flow<ApiResult<AnalyticsSummary>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.get("/api/analytics/user/$userId/summary")
            
            if (response.status.isSuccess()) {
                val apiResponse = networkClient.handleResponse<ApiResponse<AnalyticsSummary>>(response)
                if (apiResponse.success) {
                    emit(ApiResult.Success(apiResponse.data))
                } else {
                    emit(ApiResult.Error(apiResponse.message ?: "Unknown error"))
                }
            } else {
                emit(ApiResult.Error("Failed to fetch analytics summary"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Network error occurred"))
        }
    }

    override suspend fun regenerateAnalytics(userId: Int, week: String?): Flow<ApiResult<UserAnalytics>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.post("/api/analytics/user/$userId/regenerate") {
                contentType(ContentType.Application.Json)
                week?.let { parameter("week", it) }
            }
            
            if (response.status.isSuccess()) {
                val apiResponse = networkClient.handleResponse<ApiResponse<UserAnalytics>>(response)
                if (apiResponse.success) {
                    emit(ApiResult.Success(apiResponse.data))
                } else {
                    emit(ApiResult.Error(apiResponse.message ?: "Unknown error"))
                }
            } else {
                emit(ApiResult.Error("Failed to regenerate analytics"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Network error occurred"))
        }
    }
}

// Helper data classes for API responses
@kotlinx.serialization.Serializable
private data class ApiResponse<T>(
    val success: Boolean,
    val data: T,
    val message: String? = null
)

@kotlinx.serialization.Serializable
private data class AnalyticsHistoryResponse(
    val history: List<UserAnalytics>,
    @kotlinx.serialization.SerialName("total_weeks") val totalWeeks: Int
)

// Extension functions for easier usage
suspend fun AnalyticsRepository.getCurrentWeekAnalytics(userId: Int): UserAnalytics? {
    var result: UserAnalytics? = null
    getUserAnalytics(userId).collect { apiResult ->
        if (apiResult is ApiResult.Success) {
            result = apiResult.data
        }
    }
    return result
}

suspend fun AnalyticsRepository.getLastNWeeksAnalytics(userId: Int, weeks: Int): List<UserAnalytics> {
    var result: List<UserAnalytics> = emptyList()
    getUserAnalyticsHistory(userId, weeks).collect { apiResult ->
        if (apiResult is ApiResult.Success) {
            result = apiResult.data
        }
    }
    return result
}

suspend fun AnalyticsRepository.getUnlockedAchievements(userId: Int): List<Achievement> {
    var result: List<Achievement> = emptyList()
    getUserAchievements(userId).collect { apiResult ->
        if (apiResult is ApiResult.Success) {
            result = apiResult.data.unlockedAchievements
        }
    }
    return result
}

// Cache management for better performance
class AnalyticsCacheManager {
    private val cache = mutableMapOf<String, Pair<Any, Long>>()
    private val cacheTimeout = 5 * 60 * 1000L // 5 minutes

    fun <T> getCachedData(key: String): T? {
        val cached = cache[key]
        return if (cached != null && System.currentTimeMillis() - cached.second < cacheTimeout) {
            @Suppress("UNCHECKED_CAST")
            cached.first as T
        } else {
            cache.remove(key)
            null
        }
    }

    fun <T> cacheData(key: String, data: T) {
        cache[key] = Pair(data as Any, System.currentTimeMillis())
    }

    fun clearCache() {
        cache.clear()
    }

    fun clearExpiredCache() {
        val currentTime = System.currentTimeMillis()
        val expiredKeys = cache.filter { currentTime - it.value.second >= cacheTimeout }.keys
        expiredKeys.forEach { cache.remove(it) }
    }
}

// Repository with caching
@Singleton
class CachedAnalyticsRepository @Inject constructor(
    private val repository: AnalyticsRepository,
    private val cacheManager: AnalyticsCacheManager
) : AnalyticsRepository by repository {

    override suspend fun getUserAnalytics(userId: Int, week: String?): Flow<ApiResult<UserAnalytics>> = flow {
        val cacheKey = "analytics_${userId}_${week ?: "current"}"
        
        // Check cache first
        cacheManager.getCachedData<UserAnalytics>(cacheKey)?.let { cached ->
            emit(ApiResult.Success(cached))
            return@flow
        }

        // Fetch from network
        repository.getUserAnalytics(userId, week).collect { result ->
            if (result is ApiResult.Success) {
                cacheManager.cacheData(cacheKey, result.data)
            }
            emit(result)
        }
    }

    override suspend fun getAnalyticsSummary(userId: Int): Flow<ApiResult<AnalyticsSummary>> = flow {
        val cacheKey = "summary_$userId"
        
        // Check cache first
        cacheManager.getCachedData<AnalyticsSummary>(cacheKey)?.let { cached ->
            emit(ApiResult.Success(cached))
            return@flow
        }

        // Fetch from network
        repository.getAnalyticsSummary(userId).collect { result ->
            if (result is ApiResult.Success) {
                cacheManager.cacheData(cacheKey, result.data)
            }
            emit(result)
        }
    }
}