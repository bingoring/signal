package com.signal.app.features.signal.data.services

import com.signal.app.features.signal.data.models.*
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
    suspend fun createSignal(@Body signalRequest: CreateSignalRequest): ApiResponse<Signal>

    /**
     * 시그널 수정
     */
    @PUT("api/signals/{id}")
    suspend fun updateSignal(
        @Path("id") signalId: Int,
        @Body signalRequest: UpdateSignalRequest
    ): ApiResponse<Signal>

    /**
     * 시그널 삭제
     */
    @DELETE("api/signals/{id}")
    suspend fun deleteSignal(@Path("id") signalId: Int): ApiResponse<Unit>

    /**
     * 시그널 참여 (즉시 참가)
     */
    @POST("api/signals/{id}/join")
    suspend fun joinSignal(
        @Path("id") signalId: Int,
        @Body joinRequest: JoinSignalRequest
    ): ApiResponse<Unit>

    /**
     * 시그널 나가기
     */
    @POST("api/signals/{id}/leave")
    suspend fun leaveSignal(@Path("id") signalId: Int): ApiResponse<Unit>

    /**
     * 내가 참여한 시그널 목록
     */
    @GET("api/signals/my-signals")
    suspend fun getMySignals(): ApiResponse<List<Signal>>

    /**
     * 내가 생성한 시그널 목록
     */
    @GET("api/signals/my-created-signals")
    suspend fun getMyCreatedSignals(): ApiResponse<List<Signal>>

    /**
     * 시그널 참가 신청서 목록 조회
     */
    @GET("api/signals/{id}/join-requests")
    suspend fun getJoinRequests(@Path("id") signalId: Int): ApiResponse<List<SignalJoinRequest>>

    /**
     * 참가 신청서 승인
     */
    @POST("api/signals/{id}/join-requests/approve")
    suspend fun approveJoinRequest(
        @Path("id") signalId: Int,
        @Body request: ApproveJoinRequestRequest
    ): ApiResponse<Unit>

    /**
     * 참가 신청서 거절
     */
    @POST("api/signals/{id}/join-requests/reject")
    suspend fun rejectJoinRequest(
        @Path("id") signalId: Int,
        @Body request: RejectJoinRequestRequest
    ): ApiResponse<Unit>

    /**
     * 내 참가 신청 상태 조회
     */
    @GET("api/signals/{id}/my-join-status")
    suspend fun getMyJoinStatus(@Path("id") signalId: Int): ApiResponse<SignalJoinRequest?>
}

/**
 * 시그널 수정 요청 모델
 */
data class UpdateSignalRequest(
    val title: String?,
    val description: String?,
    val category: String?,
    val maxParticipants: Int?,
    val scheduledAt: String?, // ISO 8601 format
    val minAge: Int?,
    val maxAge: Int?,
    val allowInstantJoin: Boolean?,
    val requireApproval: Boolean?,
    val genderPreference: String?
)