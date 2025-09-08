package com.signal.app.features.auth.data.services

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.gson.Gson
import com.signal.app.features.auth.data.models.AuthRequest
import com.signal.app.features.auth.data.models.AuthResponse
import com.signal.app.features.auth.data.models.TokenVerifyResponse
import com.signal.app.features.auth.data.models.UserProfile
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "auth_preferences")

@Singleton
class AuthService @Inject constructor(
    private val authApi: AuthApi,
    @ApplicationContext private val context: Context,
    private val gson: Gson
) {
    companion object {
        private val TOKEN_KEY = stringPreferencesKey("auth_token")
        private val USER_KEY = stringPreferencesKey("user_profile")
    }

    // Send magic link to email
    suspend fun sendMagicLink(email: String): AuthResponse {
        val response = authApi.sendMagicLink(AuthRequest(email))
        if (response.isSuccessful) {
            return response.body() ?: throw Exception("매직링크 전송에 실패했습니다.")
        } else {
            throw Exception(response.errorBody()?.string() ?: "매직링크 전송에 실패했습니다.")
        }
    }

    // Verify magic link token
    suspend fun verifyMagicLink(token: String): TokenVerifyResponse {
        val response = authApi.verifyMagicLink(token)
        if (response.isSuccessful) {
            val result = response.body() ?: throw Exception("인증에 실패했습니다.")
            
            // Save token and user data
            saveAuthData(result.token, result.user)
            
            return result
        } else {
            throw Exception(response.errorBody()?.string() ?: "인증에 실패했습니다.")
        }
    }

    // Get current user profile
    suspend fun getCurrentUser(): UserProfile? {
        return try {
            val token = getToken()
            if (token.isNullOrEmpty()) return null
            
            val response = authApi.getCurrentUser("Bearer $token")
            if (response.isSuccessful) {
                response.body()
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    // Logout user
    suspend fun logout() {
        try {
            val token = getToken()
            if (!token.isNullOrEmpty()) {
                authApi.logout("Bearer $token")
            }
        } catch (e: Exception) {
            // Ignore logout errors
        } finally {
            clearAuthData()
        }
    }

    // Check if user is authenticated
    suspend fun isAuthenticated(): Boolean {
        val token = getToken()
        if (token.isNullOrEmpty()) return false
        
        return try {
            getCurrentUser() != null
        } catch (e: Exception) {
            false
        }
    }

    // Get stored auth token
    suspend fun getToken(): String? {
        return context.dataStore.data.map { preferences ->
            preferences[TOKEN_KEY]
        }.first()
    }

    // Get stored user profile
    suspend fun getStoredUser(): UserProfile? {
        return try {
            val userJson = context.dataStore.data.map { preferences ->
                preferences[USER_KEY]
            }.first()
            
            if (userJson != null) {
                gson.fromJson(userJson, UserProfile::class.java)
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    // Get auth state flow
    fun getAuthState(): Flow<Boolean> {
        return context.dataStore.data.map { preferences ->
            preferences[TOKEN_KEY] != null
        }
    }

    // Save authentication data
    private suspend fun saveAuthData(token: String, userProfile: UserProfile) {
        context.dataStore.edit { preferences ->
            preferences[TOKEN_KEY] = token
            preferences[USER_KEY] = gson.toJson(userProfile)
        }
    }

    // Clear authentication data
    private suspend fun clearAuthData() {
        context.dataStore.edit { preferences ->
            preferences.remove(TOKEN_KEY)
            preferences.remove(USER_KEY)
        }
    }
}