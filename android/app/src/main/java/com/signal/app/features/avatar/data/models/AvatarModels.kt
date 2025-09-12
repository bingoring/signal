package com.signal.app.features.avatar.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class AvatarCategory(
    val id: Int,
    val name: String,
    val description: String? = null,
    val emoji: String,
    @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("sort_order") val sortOrder: Int = 0
)

@Serializable
data class Avatar(
    val id: Int,
    @SerialName("category_id") val categoryId: Int,
    val emoji: String,
    val name: String,
    val description: String? = null,
    val tags: List<String> = emptyList(),
    val personality: String? = null,
    @SerialName("usage_count") val usageCount: Int = 0,
    @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("sort_order") val sortOrder: Int = 0,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
    
    // Computed properties
    val category: AvatarCategory? = null
)

@Serializable
data class UserAvatar(
    val id: Int,
    @SerialName("user_id") val userId: Int,
    @SerialName("avatar_id") val avatarId: Int,
    @SerialName("is_current") val isCurrent: Boolean = false,
    @SerialName("is_favorite") val isFavorite: Boolean = false,
    @SerialName("usage_count") val usageCount: Int = 0,
    @SerialName("last_used") val lastUsed: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
    
    // Relations
    val avatar: Avatar? = null
)

@Serializable
data class AvatarPersonality(
    @SerialName("personality_type") val personalityType: String,
    val description: String,
    val traits: List<String>,
    val score: Double,
    @SerialName("match_percentage") val matchPercentage: Double? = null
)

@Serializable
data class AvatarSearchResult(
    val avatars: List<Avatar>,
    val categories: List<AvatarCategory> = emptyList(),
    @SerialName("total_count") val totalCount: Int = 0,
    val page: Int = 1,
    @SerialName("page_size") val pageSize: Int = 20,
    @SerialName("has_more") val hasMore: Boolean = false
)

@Serializable
data class UserAvatarData(
    @SerialName("current_avatar") val currentAvatar: UserAvatar? = null,
    @SerialName("favorite_avatars") val favoriteAvatars: List<UserAvatar> = emptyList(),
    @SerialName("recent_avatars") val recentAvatars: List<UserAvatar> = emptyList(),
    @SerialName("personality_analysis") val personalityAnalysis: AvatarPersonality? = null,
    val categories: List<AvatarCategory> = emptyList(),
    @SerialName("usage_stats") val usageStats: AvatarUsageStats? = null
)

@Serializable
data class AvatarUsageStats(
    @SerialName("total_changes") val totalChanges: Int,
    @SerialName("favorite_category") val favoriteCategory: String? = null,
    @SerialName("most_used_avatar") val mostUsedAvatar: Avatar? = null,
    @SerialName("personality_consistency") val personalityConsistency: Double = 0.0,
    @SerialName("change_frequency") val changeFrequency: String = "low" // low, medium, high
)

// UI State Models
data class AvatarSelectionState(
    val isLoading: Boolean = false,
    val categories: List<AvatarCategory> = emptyList(),
    val avatars: List<Avatar> = emptyList(),
    val selectedCategory: AvatarCategory? = null,
    val searchQuery: String = "",
    val searchResults: List<Avatar> = emptyList(),
    val userAvatarData: UserAvatarData? = null,
    val isSearching: Boolean = false,
    val error: String? = null,
    val currentTab: AvatarTab = AvatarTab.CATEGORIES
)

enum class AvatarTab {
    CATEGORIES,
    FAVORITES, 
    RECENT,
    SEARCH,
    PERSONALITY
}

data class PersonalityInsight(
    val type: String,
    val title: String,
    val description: String,
    val percentage: Double,
    val color: String,
    val traits: List<String> = emptyList()
)

// Extension functions for UI
fun Avatar.getDisplayName(): String = name.takeIf { it.isNotBlank() } ?: emoji

fun Avatar.matchesSearch(query: String): Boolean {
    if (query.isBlank()) return true
    val searchTerm = query.lowercase()
    return name.lowercase().contains(searchTerm) ||
           description?.lowercase()?.contains(searchTerm) == true ||
           tags.any { it.lowercase().contains(searchTerm) } ||
           personality?.lowercase()?.contains(searchTerm) == true
}

fun AvatarCategory.getDisplayName(): String = "$emoji $name"

fun List<Avatar>.sortedByUsage(): List<Avatar> = sortedByDescending { it.usageCount }

fun List<Avatar>.filterByCategory(categoryId: Int): List<Avatar> = 
    filter { it.categoryId == categoryId }

fun List<Avatar>.searchByQuery(query: String): List<Avatar> = 
    filter { it.matchesSearch(query) }

// Personality type mappings
object PersonalityTypes {
    const val EXPRESSIVE = "expressive"
    const val ACTIVE = "active" 
    const val ADVENTURER = "adventurer"
    const val CREATIVE = "creative"
    const val BALANCED = "balanced"
    const val SOCIAL = "social"
    
    fun getDisplayName(type: String): String = when(type) {
        EXPRESSIVE -> "표현적"
        ACTIVE -> "활동적"
        ADVENTURER -> "모험가"
        CREATIVE -> "창조적"
        BALANCED -> "균형잡힌"
        SOCIAL -> "사교적"
        else -> type.replaceFirstChar { it.uppercase() }
    }
    
    fun getDescription(type: String): String = when(type) {
        EXPRESSIVE -> "감정 표현이 풍부하고 다양한 감정 아바타를 선호합니다"
        ACTIVE -> "운동과 활동적인 아바타를 즐겨 사용합니다"
        ADVENTURER -> "여행과 탐험 관련 아바타로 새로운 경험을 추구합니다"
        CREATIVE -> "창조적이고 예술적인 아바타로 개성을 표현합니다"
        BALANCED -> "다양한 카테고리의 아바타를 골고루 사용합니다"
        SOCIAL -> "사람들과의 관계와 소통을 중시하는 아바타를 선호합니다"
        else -> "독특한 개성을 가진 사용자입니다"
    }
    
    fun getColor(type: String): String = when(type) {
        EXPRESSIVE -> "#FF6B6B"
        ACTIVE -> "#4ECDC4"
        ADVENTURER -> "#45B7D1"
        CREATIVE -> "#96CEB4"
        BALANCED -> "#FFEAA7"
        SOCIAL -> "#DDA0DD"
        else -> "#A8A8A8"
    }
}