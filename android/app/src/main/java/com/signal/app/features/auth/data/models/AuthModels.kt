package com.signal.app.features.auth.data.models

import com.google.gson.annotations.SerializedName
import java.util.Date

data class AuthRequest(
    val email: String
)

data class AuthResponse(
    val message: String,
    val success: Boolean
)

data class TokenVerifyResponse(
    val token: String,
    @SerializedName("is_new_user")
    val isNewUser: Boolean,
    val user: UserProfile
)

data class UserProfile(
    val id: Int,
    val email: String,
    val username: String,
    @SerializedName("is_active")
    val isActive: Boolean,
    @SerializedName("created_at")
    val createdAt: Date?,
    @SerializedName("updated_at")
    val updatedAt: Date?
)