package com.signal.app.features.signal.data.services

import com.signal.app.features.signal.data.models.Signal
import com.signal.app.features.signal.data.models.SignalWithDistance
import retrofit2.http.*

/**
 * Signal API 서비스 인터페이스
 * Flutter SignalApiService와 동일한 기능을 Android에서 제공
 */
interface SignalApiService {

    /**
     * 근처 시그널 검색
     */
    @GET("api/signals/nearby")
    suspend fun getNearbySignals(
        @Query("latitude") latitude: Double,
        @Query("longitude") longitude: Double,
        @Query("radius") radius: Double = 1000.0,
        @Query("categories") categories: List<String>? = null
    ): List<SignalWithDistance>

    /**
     * 시그널 검색
     */
    @GET("api/signals/search")
    suspend fun searchSignals(
        @Query("query") query: String,
        @Query("latitude") latitude: Double? = null,
        @Query("longitude") longitude: Double? = null,
        @Query("radius") radius: Double = 1000.0
    ): List<SignalWithDistance>

    /**
     * 시그널 상세 조회
     */
    @GET("api/signals/{id}")
    suspend fun getSignal(@Path("id") signalId: Int): Signal

    /**
     * 시그널 생성
     */
    @POST("api/signals")
    suspend fun createSignal(@Body signalRequest: CreateSignalRequest): Signal

    /**
     * 시그널 수정
     */
    @PUT("api/signals/{id}")
    suspend fun updateSignal(
        @Path("id") signalId: Int,
        @Body signalRequest: UpdateSignalRequest
    ): Signal

    /**
     * 시그널 삭제
     */
    @DELETE("api/signals/{id}")
    suspend fun deleteSignal(@Path("id") signalId: Int)

    /**
     * 시그널 참여
     */
    @POST("api/signals/{id}/join")
    suspend fun joinSignal(
        @Path("id") signalId: Int,
        @Body joinRequest: JoinSignalRequest? = null
    )

    /**
     * 시그널 나가기
     */
    @POST("api/signals/{id}/leave")
    suspend fun leaveSignal(@Path("id") signalId: Int)

    /**
     * 내가 참여한 시그널 목록
     */
    @GET("api/signals/my-signals")
    suspend fun getMySignals(): List<Signal>

    /**
     * 내가 생성한 시그널 목록
     */
    @GET("api/signals/my-created-signals")
    suspend fun getMyCreatedSignals(): List<Signal>
}

/**
 * 시그널 생성 요청 모델
 */
data class CreateSignalRequest(
    val title: String,
    val description: String,
    val category: String,
    val latitude: Double,
    val longitude: Double,
    val address: String,
    val maxParticipants: Int,
    val scheduledTime: String? = null, // ISO 8601 format
    val isPrivate: Boolean = false,
    val tags: List<String> = emptyList()
)

/**
 * 시그널 수정 요청 모델
 */
data class UpdateSignalRequest(
    val title: String?,
    val description: String?,
    val category: String?,
    val maxParticipants: Int?,
    val scheduledTime: String?, // ISO 8601 format
    val isPrivate: Boolean?,
    val tags: List<String>?
)

/**
 * 시그널 참여 요청 모델
 */
data class JoinSignalRequest(
    val message: String? = null
)