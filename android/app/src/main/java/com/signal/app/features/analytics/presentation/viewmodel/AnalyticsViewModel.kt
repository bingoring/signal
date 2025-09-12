package com.signal.app.features.analytics.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.signal.app.core.network.ApiResult
import com.signal.app.features.analytics.data.models.*
import com.signal.app.features.analytics.data.repository.AnalyticsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import javax.inject.Inject

@HiltViewModel
class AnalyticsViewModel @Inject constructor(
    private val analyticsRepository: AnalyticsRepository
) : ViewModel() {

    private val _state = MutableStateFlow(AnalyticsState())
    val state: StateFlow<AnalyticsState> = _state.asStateFlow()

    private val _selectedTab = MutableStateFlow(AnalyticsTab.OVERVIEW)
    val selectedTab: StateFlow<AnalyticsTab> = _selectedTab.asStateFlow()

    init {
        // Initialize with current week analytics
        loadCurrentWeekData()
    }

    fun loadAnalyticsData(userId: Int) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)

            // Load summary first for quick overview
            loadAnalyticsSummary(userId)
            
            // Then load detailed data
            loadCurrentWeekAnalytics(userId)
            loadAnalyticsHistory(userId)
            loadAchievements(userId)
        }
    }

    fun loadCurrentWeekData() {
        val currentWeek = getCurrentWeekString()
        _state.value = _state.value.copy(selectedWeek = currentWeek)
    }

    private fun loadAnalyticsSummary(userId: Int) {
        viewModelScope.launch {
            analyticsRepository.getAnalyticsSummary(userId).collect { result ->
                when (result) {
                    is ApiResult.Loading -> {
                        _state.value = _state.value.copy(isLoading = true)
                    }
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            summary = result.data,
                            error = null
                        )
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            error = result.message
                        )
                    }
                }
            }
        }
    }

    private fun loadCurrentWeekAnalytics(userId: Int) {
        viewModelScope.launch {
            val week = _state.value.selectedWeek
            analyticsRepository.getUserAnalytics(userId, week).collect { result ->
                when (result) {
                    is ApiResult.Loading -> {
                        _state.value = _state.value.copy(isLoading = true)
                    }
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            currentWeekAnalytics = result.data,
                            isLoading = false,
                            error = null
                        )
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            error = result.message
                        )
                    }
                }
            }
        }
    }

    private fun loadAnalyticsHistory(userId: Int, weeks: Int = 8) {
        viewModelScope.launch {
            analyticsRepository.getUserAnalyticsHistory(userId, weeks).collect { result ->
                when (result) {
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            analyticsHistory = result.data,
                            error = null
                        )
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            error = result.message
                        )
                    }
                    else -> {}
                }
            }
        }
    }

    private fun loadAchievements(userId: Int) {
        viewModelScope.launch {
            analyticsRepository.getUserAchievements(userId).collect { result ->
                when (result) {
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            achievements = result.data,
                            error = null
                        )
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            error = result.message
                        )
                    }
                    else -> {}
                }
            }
        }
    }

    fun selectWeek(userId: Int, week: String) {
        _state.value = _state.value.copy(selectedWeek = week)
        loadWeekAnalytics(userId, week)
    }

    private fun loadWeekAnalytics(userId: Int, week: String) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true)
            
            analyticsRepository.getUserAnalytics(userId, week).collect { result ->
                when (result) {
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            currentWeekAnalytics = result.data,
                            isLoading = false,
                            error = null
                        )
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            error = result.message
                        )
                    }
                    else -> {}
                }
            }
        }
    }

    fun refreshData(userId: Int) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            
            // Regenerate current week analytics
            val currentWeek = _state.value.selectedWeek
            analyticsRepository.regenerateAnalytics(userId, currentWeek).collect { result ->
                when (result) {
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            currentWeekAnalytics = result.data,
                            isLoading = false,
                            error = null
                        )
                        // Reload all data
                        loadAnalyticsData(userId)
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            error = result.message
                        )
                    }
                    else -> {}
                }
            }
        }
    }

    fun selectTab(tab: AnalyticsTab) {
        _selectedTab.value = tab
    }

    fun clearError() {
        _state.value = _state.value.copy(error = null)
    }

    // Helper functions for UI data
    fun getActivityChartData(): List<ChartDataPoint> {
        return _state.value.currentWeekAnalytics?.weeklyStats?.toChartData() ?: emptyList()
    }

    fun getSocialImpactChartData(): List<ChartDataPoint> {
        return _state.value.currentWeekAnalytics?.socialImpact?.toChartData() ?: emptyList()
    }

    fun getTrendData(): List<ChartDataPoint> {
        val history = _state.value.analyticsHistory
        if (history.size < 2) return emptyList()

        return history.takeLast(4).mapIndexed { index, analytics ->
            ChartDataPoint(
                label = formatWeekLabel(analytics.weekStartDate),
                value = analytics.weeklyStats.totalParticipation.toDouble(),
                color = when (index) {
                    0 -> "#E3F2FD"
                    1 -> "#BBDEFB"
                    2 -> "#64B5F6"
                    else -> "#2196F3"
                }
            )
        }
    }

    fun getEngagementTrendIcon(): String {
        return when (_state.value.currentWeekAnalytics?.trendAnalysis?.engagementTrend) {
            "increasing" -> "📈"
            "decreasing" -> "📉"
            else -> "➡️"
        }
    }

    fun getTopAchievementsByCategory(): Map<String, List<Achievement>> {
        val achievements = _state.value.achievements ?: return emptyMap()
        return achievements.byCategory.mapValues { (_, achievements) ->
            achievements.sortedByDescending { it.progressPercentage }.take(3)
        }
    }

    fun getWeeklyGrowthPercentage(): Double {
        return _state.value.currentWeekAnalytics?.trendAnalysis?.weekOverWeekGrowth ?: 0.0
    }

    fun getCompletionRateLevel(): String {
        val rate = _state.value.currentWeekAnalytics?.weeklyStats?.completionRate ?: 0.0
        return AnalyticsConstants.getScoreLevel(rate)
    }

    fun getCommunityScoreLevel(): String {
        val score = _state.value.currentWeekAnalytics?.socialImpact?.communityScore ?: 0.0
        return AnalyticsConstants.getScoreLevel(score)
    }

    private fun getCurrentWeekString(): String {
        val now = LocalDate.now()
        val monday = now.minusDays(now.dayOfWeek.value - 1L)
        return monday.format(DateTimeFormatter.ofPattern("yyyy-MM-dd"))
    }

    private fun formatWeekLabel(weekStartDate: String): String {
        return try {
            val date = LocalDate.parse(weekStartDate)
            "${date.monthValue}/${date.dayOfMonth}"
        } catch (e: Exception) {
            weekStartDate
        }
    }

    // Summary calculations
    fun getTotalActivitiesThisWeek(): Int {
        return _state.value.currentWeekAnalytics?.weeklyStats?.totalParticipation ?: 0
    }

    fun getCompletionRate(): Double {
        return _state.value.currentWeekAnalytics?.weeklyStats?.completionRate ?: 0.0
    }

    fun getCommunityScore(): Double {
        return _state.value.currentWeekAnalytics?.socialImpact?.communityScore ?: 0.0
    }

    fun getNewBuddiesCount(): Int {
        return _state.value.currentWeekAnalytics?.weeklyStats?.newBuddiesMade ?: 0
    }

    fun getAverageRating(): Double {
        return _state.value.currentWeekAnalytics?.weeklyStats?.averageRating ?: 0.0
    }

    fun getInfluenceRating(): Double {
        return _state.value.currentWeekAnalytics?.socialImpact?.influenceRating ?: 0.0
    }

    fun getPopularTimeSlots(): List<TimeSlot> {
        return _state.value.currentWeekAnalytics?.trendAnalysis?.popularTimeSlots?.take(3) ?: emptyList()
    }

    fun getPreferredLocations(): List<LocationTrend> {
        return _state.value.currentWeekAnalytics?.trendAnalysis?.preferredLocations?.take(3) ?: emptyList()
    }

    fun getFavoriteCategories(): List<String> {
        return _state.value.currentWeekAnalytics?.weeklyStats?.favoriteCategories?.take(3) ?: emptyList()
    }

    fun getUnlockedAchievementsCount(): Int {
        return _state.value.achievements?.totalUnlocked ?: 0
    }

    fun getTotalAchievementsCount(): Int {
        return _state.value.achievements?.totalAvailable ?: 0
    }

    fun getRecentAchievements(): List<Achievement> {
        return _state.value.summary?.achievements?.recentAchievements ?: emptyList()
    }

    fun getWeekComparisonText(): String {
        val growth = getWeeklyGrowthPercentage()
        return when {
            growth > 10 -> "지난 주보다 ${growth.toInt()}% 더 활발했어요! 🎉"
            growth > 0 -> "지난 주보다 ${growth.toInt()}% 증가했습니다 📈"
            growth < -10 -> "지난 주보다 ${(-growth).toInt()}% 감소했습니다 📉"
            growth < 0 -> "지난 주보다 ${(-growth).toInt()}% 다소 감소했습니다"
            else -> "지난 주와 비슷한 활동량을 보였습니다 ➡️"
        }
    }
}

enum class AnalyticsTab {
    OVERVIEW,
    ACTIVITY,
    SOCIAL_IMPACT,
    TRENDS,
    ACHIEVEMENTS
}