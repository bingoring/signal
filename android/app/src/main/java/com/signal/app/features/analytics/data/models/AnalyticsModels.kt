package com.signal.app.features.analytics.data.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class UserAnalytics(
    val id: Int,
    @SerialName("user_id") val userId: Int,
    @SerialName("week_start_date") val weekStartDate: String,
    @SerialName("weekly_stats") val weeklyStats: WeeklyActivityStats,
    @SerialName("social_impact") val socialImpact: SocialImpactMetrics,
    @SerialName("trend_analysis") val trendAnalysis: TrendData,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
data class WeeklyActivityStats(
    @SerialName("signals_created") val signalsCreated: Int,
    @SerialName("signals_joined") val signalsJoined: Int,
    @SerialName("total_participation") val totalParticipation: Int,
    @SerialName("completion_rate") val completionRate: Double,
    @SerialName("average_rating") val averageRating: Double,
    @SerialName("new_buddies_made") val newBuddiesMade: Int,
    @SerialName("messages_exchanged") val messagesExchanged: Int,
    @SerialName("favorite_categories") val favoriteCategories: List<String>
)

@Serializable
data class SocialImpactMetrics(
    @SerialName("community_score") val communityScore: Double,
    @SerialName("influence_rating") val influenceRating: Double,
    @SerialName("helpfulness_score") val helpfulnessScore: Double,
    @SerialName("leadership_events") val leadershipEvents: Int,
    @SerialName("positive_feedback") val positiveFeedback: Int,
    @SerialName("mentorship_activity") val mentorshipActivity: Int
)

@Serializable
data class TrendData(
    @SerialName("week_over_week_growth") val weekOverWeekGrowth: Double,
    @SerialName("popular_time_slots") val popularTimeSlots: List<TimeSlot>,
    @SerialName("preferred_locations") val preferredLocations: List<LocationTrend>,
    @SerialName("social_network_growth") val socialNetworkGrowth: Double,
    @SerialName("engagement_trend") val engagementTrend: String
)

@Serializable
data class TimeSlot(
    val hour: Int,
    @SerialName("day_of_week") val dayOfWeek: Int,
    @SerialName("activity_count") val activityCount: Int,
    val probability: Double
) {
    val dayName: String
        get() = when (dayOfWeek) {
            0 -> "일"
            1 -> "월"
            2 -> "화"
            3 -> "수"
            4 -> "목"
            5 -> "금"
            6 -> "토"
            else -> "알 수 없음"
        }
    
    val timeRange: String
        get() {
            val startHour = hour
            val endHour = (hour + 1) % 24
            return "${startHour.toString().padStart(2, '0')}:00-${endHour.toString().padStart(2, '0')}:00"
        }
}

@Serializable
data class LocationTrend(
    val district: String,
    @SerialName("visit_frequency") val visitFrequency: Int,
    @SerialName("preference_score") val preferenceScore: Double,
    val category: String
)

@Serializable
data class Achievement(
    val id: Int,
    @SerialName("user_id") val userId: Int,
    val type: String,
    val title: String,
    val description: String,
    @SerialName("icon_url") val iconUrl: String? = null,
    val category: String,
    val difficulty: String,
    val progress: Int,
    @SerialName("max_progress") val maxProgress: Int,
    @SerialName("is_unlocked") val isUnlocked: Boolean,
    @SerialName("unlocked_at") val unlockedAt: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String
) {
    val progressPercentage: Double
        get() = if (maxProgress == 0) 0.0 else (progress.toDouble() / maxProgress * 100).coerceIn(0.0, 100.0)
    
    val difficultyEmoji: String
        get() = when (difficulty.lowercase()) {
            "bronze" -> "🥉"
            "silver" -> "🥈"
            "gold" -> "🥇"
            "platinum" -> "💎"
            else -> "🏆"
        }
    
    val categoryEmoji: String
        get() = when (category.lowercase()) {
            "social" -> "👥"
            "participation" -> "🎯"
            "leadership" -> "👑"
            "exploration" -> "🗺️"
            "communication" -> "💬"
            "consistency" -> "📅"
            "helpfulness" -> "🤝"
            "creativity" -> "🎨"
            else -> "⭐"
        }
    
    val isCompleted: Boolean
        get() = progress >= maxProgress
}

@Serializable
data class AchievementData(
    val achievements: List<Achievement>,
    @SerialName("by_category") val byCategory: Map<String, List<Achievement>>,
    @SerialName("total_unlocked") val totalUnlocked: Int,
    @SerialName("total_available") val totalAvailable: Int
) {
    val completionRate: Double
        get() = if (totalAvailable == 0) 0.0 else (totalUnlocked.toDouble() / totalAvailable * 100).coerceIn(0.0, 100.0)
    
    val unlockedAchievements: List<Achievement>
        get() = achievements.filter { it.isUnlocked }
    
    val inProgressAchievements: List<Achievement>
        get() = achievements.filter { !it.isUnlocked && it.progress > 0 }
    
    val lockedAchievements: List<Achievement>
        get() = achievements.filter { !it.isUnlocked && it.progress == 0 }
    
    val availableCategories: List<String>
        get() = byCategory.keys.sorted()
}

@Serializable
data class AnalyticsSummary(
    @SerialName("current_week") val currentWeek: CurrentWeekSummary,
    val achievements: AchievementSummary,
    @SerialName("social_impact") val socialImpact: SocialImpactSummary,
    @SerialName("personal_insights") val personalInsights: PersonalInsightsSummary
)

@Serializable
data class CurrentWeekSummary(
    @SerialName("week_start_date") val weekStartDate: String,
    @SerialName("total_participation") val totalParticipation: Int,
    @SerialName("completion_rate") val completionRate: Double,
    @SerialName("community_score") val communityScore: Double,
    @SerialName("week_over_week_growth") val weekOverWeekGrowth: Double,
    @SerialName("engagement_trend") val engagementTrend: String
)

@Serializable
data class AchievementSummary(
    @SerialName("total_unlocked") val totalUnlocked: Int,
    @SerialName("total_available") val totalAvailable: Int,
    @SerialName("completion_rate") val completionRate: Double,
    @SerialName("recent_achievements") val recentAchievements: List<Achievement>
)

@Serializable
data class SocialImpactSummary(
    @SerialName("influence_rating") val influenceRating: Double,
    @SerialName("helpfulness_score") val helpfulnessScore: Double,
    @SerialName("leadership_events") val leadershipEvents: Int,
    @SerialName("new_buddies_made") val newBuddiesMade: Int
)

@Serializable
data class PersonalInsightsSummary(
    @SerialName("favorite_categories") val favoriteCategories: List<String>,
    @SerialName("popular_time_slots") val popularTimeSlots: List<TimeSlot>,
    @SerialName("preferred_locations") val preferredLocations: List<LocationTrend>
)

// UI State Models
data class AnalyticsState(
    val isLoading: Boolean = false,
    val currentWeekAnalytics: UserAnalytics? = null,
    val analyticsHistory: List<UserAnalytics> = emptyList(),
    val summary: AnalyticsSummary? = null,
    val achievements: AchievementData? = null,
    val selectedWeek: String? = null,
    val error: String? = null
)

// Extension functions for UI formatting
fun Double.toPercentageString(): String = "${this.toInt()}%"

fun Double.toScoreString(): String = String.format("%.1f", this)

fun Int.toFormattedCount(): String = when {
    this < 1000 -> this.toString()
    this < 1000000 -> "${(this / 1000)}K"
    else -> "${(this / 1000000)}M"
}

fun String.toEngagementTrendKorean(): String = when (this.lowercase()) {
    "increasing" -> "상승 중"
    "decreasing" -> "하락 중"
    "stable" -> "안정"
    else -> this
}

fun List<String>.joinToDisplayString(maxItems: Int = 3): String {
    return if (size <= maxItems) {
        joinToString(", ")
    } else {
        "${take(maxItems).joinToString(", ")} 외 ${size - maxItems}개"
    }
}

// Helper for chart data
data class ChartDataPoint(
    val label: String,
    val value: Double,
    val color: String = "#4285F4"
)

fun WeeklyActivityStats.toChartData(): List<ChartDataPoint> {
    return listOf(
        ChartDataPoint("생성", signalsCreated.toDouble(), "#4CAF50"),
        ChartDataPoint("참여", signalsJoined.toDouble(), "#2196F3")
    )
}

fun SocialImpactMetrics.toChartData(): List<ChartDataPoint> {
    return listOf(
        ChartDataPoint("커뮤니티", communityScore, "#FF9800"),
        ChartDataPoint("영향력", influenceRating * 20, "#9C27B0"), // Scale to 0-100
        ChartDataPoint("도움", helpfulnessScore, "#00BCD4")
    )
}

object AnalyticsConstants {
    const val EXCELLENT_SCORE_THRESHOLD = 80.0
    const val GOOD_SCORE_THRESHOLD = 60.0
    const val AVERAGE_SCORE_THRESHOLD = 40.0
    
    fun getScoreLevel(score: Double): String = when {
        score >= EXCELLENT_SCORE_THRESHOLD -> "우수"
        score >= GOOD_SCORE_THRESHOLD -> "좋음"
        score >= AVERAGE_SCORE_THRESHOLD -> "보통"
        else -> "향상 필요"
    }
    
    fun getScoreColor(score: Double): String = when {
        score >= EXCELLENT_SCORE_THRESHOLD -> "#4CAF50"
        score >= GOOD_SCORE_THRESHOLD -> "#8BC34A"
        score >= AVERAGE_SCORE_THRESHOLD -> "#FFC107"
        else -> "#FF5722"
    }
}