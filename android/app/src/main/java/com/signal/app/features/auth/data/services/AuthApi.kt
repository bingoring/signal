package com.signal.app.features.auth.data.services

import com.signal.app.features.auth.data.models.AuthRequest
import com.signal.app.features.auth.data.models.AuthResponse
import com.signal.app.features.auth.data.models.TokenVerifyResponse
import com.signal.app.features.auth.data.models.UserProfile
import retrofit2.Response
import retrofit2.http.*

interface AuthApi {
    @POST("auth/magic-link")
    suspend fun sendMagicLink(@Body authRequest: AuthRequest): Response<AuthResponse>
    
    @GET("auth/verify")
    suspend fun verifyMagicLink(@Query("token") token: String): Response<TokenVerifyResponse>
    
    @GET("auth/profile")
    suspend fun getCurrentUser(@Header("Authorization") token: String): Response<UserProfile>
    
    @POST("auth/logout")
    suspend fun logout(@Header("Authorization") token: String): Response<Unit>
}