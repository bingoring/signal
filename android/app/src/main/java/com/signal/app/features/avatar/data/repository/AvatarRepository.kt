package com.signal.app.features.avatar.data.repository

import com.signal.app.core.network.ApiResult
import com.signal.app.core.network.NetworkClient
import com.signal.app.features.avatar.data.models.*
import io.ktor.client.request.*
import io.ktor.http.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import javax.inject.Inject
import javax.inject.Singleton

interface AvatarRepository {
    suspend fun getAvatarCategories(): Flow<ApiResult<List<AvatarCategory>>>
    suspend fun getAvatarsByCategory(categoryId: Int): Flow<ApiResult<List<Avatar>>>
    suspend fun searchAvatars(query: String, categoryId: Int? = null): Flow<ApiResult<AvatarSearchResult>>
    suspend fun getUserAvatarData(userId: Int): Flow<ApiResult<UserAvatarData>>
    suspend fun setUserAvatar(userId: Int, avatarId: Int): Flow<ApiResult<UserAvatar>>
    suspend fun toggleAvatarFavorite(userId: Int, avatarId: Int, isFavorite: Boolean): Flow<ApiResult<UserAvatar>>
    suspend fun getPersonalityAnalysis(userId: Int): Flow<ApiResult<AvatarPersonality>>
}

@Singleton
class AvatarRepositoryImpl @Inject constructor(
    private val networkClient: NetworkClient
) : AvatarRepository {

    override suspend fun getAvatarCategories(): Flow<ApiResult<List<AvatarCategory>>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.get("/api/avatars/categories")
            if (response.status.isSuccess()) {
                val result = networkClient.handleResponse<List<AvatarCategory>>(response)
                emit(ApiResult.Success(result))
            } else {
                emit(ApiResult.Error("Failed to fetch avatar categories"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Unknown error occurred"))
        }
    }

    override suspend fun getAvatarsByCategory(categoryId: Int): Flow<ApiResult<List<Avatar>>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.get("/api/avatars/category/$categoryId")
            if (response.status.isSuccess()) {
                val result = networkClient.handleResponse<List<Avatar>>(response)
                emit(ApiResult.Success(result))
            } else {
                emit(ApiResult.Error("Failed to fetch avatars"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Unknown error occurred"))
        }
    }

    override suspend fun searchAvatars(query: String, categoryId: Int?): Flow<ApiResult<AvatarSearchResult>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.get("/api/avatars/search") {
                parameter("q", query)
                categoryId?.let { parameter("category_id", it) }
                parameter("page", 1)
                parameter("limit", 50)
            }
            if (response.status.isSuccess()) {
                val result = networkClient.handleResponse<AvatarSearchResult>(response)
                emit(ApiResult.Success(result))
            } else {
                emit(ApiResult.Error("Failed to search avatars"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Unknown error occurred"))
        }
    }

    override suspend fun getUserAvatarData(userId: Int): Flow<ApiResult<UserAvatarData>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.get("/api/users/$userId/avatars")
            if (response.status.isSuccess()) {
                val result = networkClient.handleResponse<UserAvatarData>(response)
                emit(ApiResult.Success(result))
            } else {
                emit(ApiResult.Error("Failed to fetch user avatar data"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Unknown error occurred"))
        }
    }

    override suspend fun setUserAvatar(userId: Int, avatarId: Int): Flow<ApiResult<UserAvatar>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.post("/api/users/$userId/avatar") {
                contentType(ContentType.Application.Json)
                setBody(mapOf("avatar_id" to avatarId))
            }
            if (response.status.isSuccess()) {
                val result = networkClient.handleResponse<UserAvatar>(response)
                emit(ApiResult.Success(result))
            } else {
                emit(ApiResult.Error("Failed to set user avatar"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Unknown error occurred"))
        }
    }

    override suspend fun toggleAvatarFavorite(userId: Int, avatarId: Int, isFavorite: Boolean): Flow<ApiResult<UserAvatar>> = flow {
        emit(ApiResult.Loading)
        try {
            val endpoint = if (isFavorite) {
                "/api/users/$userId/avatars/$avatarId/favorite"
            } else {
                "/api/users/$userId/avatars/$avatarId/unfavorite"
            }
            
            val response = networkClient.client.post(endpoint) {
                contentType(ContentType.Application.Json)
            }
            
            if (response.status.isSuccess()) {
                val result = networkClient.handleResponse<UserAvatar>(response)
                emit(ApiResult.Success(result))
            } else {
                emit(ApiResult.Error("Failed to update favorite status"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Unknown error occurred"))
        }
    }

    override suspend fun getPersonalityAnalysis(userId: Int): Flow<ApiResult<AvatarPersonality>> = flow {
        emit(ApiResult.Loading)
        try {
            val response = networkClient.client.get("/api/users/$userId/avatar/personality")
            if (response.status.isSuccess()) {
                val result = networkClient.handleResponse<AvatarPersonality>(response)
                emit(ApiResult.Success(result))
            } else {
                emit(ApiResult.Error("Failed to fetch personality analysis"))
            }
        } catch (e: Exception) {
            emit(ApiResult.Error(e.message ?: "Unknown error occurred"))
        }
    }
}

// Extension functions for easier usage
suspend fun AvatarRepository.getAvatarsForDisplay(categoryId: Int?): List<Avatar> {
    return if (categoryId != null) {
        getAvatarsByCategory(categoryId).collect { result ->
            when (result) {
                is ApiResult.Success -> return result.data
                else -> return emptyList()
            }
        }
        emptyList()
    } else {
        emptyList()
    }
}

suspend fun AvatarRepository.searchAvatarsSimple(query: String): List<Avatar> {
    searchAvatars(query).collect { result ->
        when (result) {
            is ApiResult.Success -> return result.data.avatars
            else -> return emptyList()
        }
    }
    return emptyList()
}