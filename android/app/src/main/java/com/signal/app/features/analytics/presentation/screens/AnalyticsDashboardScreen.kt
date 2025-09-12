package com.signal.app.features.analytics.presentation.screens

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.signal.app.R
import com.signal.app.features.analytics.data.models.*
import com.signal.app.features.analytics.presentation.viewmodel.AnalyticsViewModel
import com.signal.app.features.analytics.presentation.components.*
import com.signal.app.ui.components.LoadingOverlay
import com.signal.app.ui.components.ErrorSnackbar

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsDashboardScreen(
    userId: Int,
    onNavigateBack: () -> Unit,
    viewModel: AnalyticsViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val selectedTab by viewModel.selectedTab.collectAsStateWithLifecycle()

    LaunchedEffect(userId) {
        viewModel.loadAnalyticsData(userId)
    }

    Scaffold(
        topBar = {
            AnalyticsDashboardTopBar(
                onNavigateBack = onNavigateBack,
                onRefresh = { viewModel.refreshData(userId) },
                isLoading = state.isLoading
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            Column {
                // Tab selector
                AnalyticsTabRow(
                    selectedTab = selectedTab,
                    onTabSelected = viewModel::selectTab
                )

                // Tab content
                when (selectedTab) {
                    AnalyticsTab.OVERVIEW -> {
                        OverviewTabContent(
                            summary = state.summary,
                            currentWeekAnalytics = state.currentWeekAnalytics,
                            viewModel = viewModel
                        )
                    }
                    AnalyticsTab.ACTIVITY -> {
                        ActivityTabContent(
                            analytics = state.currentWeekAnalytics,
                            history = state.analyticsHistory,
                            viewModel = viewModel
                        )
                    }
                    AnalyticsTab.SOCIAL_IMPACT -> {
                        SocialImpactTabContent(
                            analytics = state.currentWeekAnalytics,
                            viewModel = viewModel
                        )
                    }
                    AnalyticsTab.TRENDS -> {
                        TrendsTabContent(
                            analytics = state.currentWeekAnalytics,
                            history = state.analyticsHistory,
                            viewModel = viewModel
                        )
                    }
                    AnalyticsTab.ACHIEVEMENTS -> {
                        AchievementsTabContent(
                            achievements = state.achievements,
                            viewModel = viewModel
                        )
                    }
                }
            }

            // Loading overlay
            if (state.isLoading) {
                LoadingOverlay()
            }

            // Error snackbar
            state.error?.let { error ->
                ErrorSnackbar(
                    message = error,
                    onDismiss = viewModel::clearError,
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AnalyticsDashboardTopBar(
    onNavigateBack: () -> Unit,
    onRefresh: () -> Unit,
    isLoading: Boolean
) {
    TopAppBar(
        title = {
            Text(
                text = stringResource(R.string.analytics_dashboard),
                style = MaterialTheme.typography.titleLarge
            )
        },
        navigationIcon = {
            IconButton(onClick = onNavigateBack) {
                Icon(
                    imageVector = Icons.Default.ArrowBack,
                    contentDescription = stringResource(R.string.back)
                )
            }
        },
        actions = {
            IconButton(
                onClick = onRefresh,
                enabled = !isLoading
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = stringResource(R.string.refresh)
                    )
                }
            }
        }
    )
}

@Composable
private fun AnalyticsTabRow(
    selectedTab: AnalyticsTab,
    onTabSelected: (AnalyticsTab) -> Unit
) {
    ScrollableTabRow(
        selectedTabIndex = selectedTab.ordinal,
        modifier = Modifier.fillMaxWidth()
    ) {
        AnalyticsTab.values().forEach { tab ->
            Tab(
                selected = selectedTab == tab,
                onClick = { onTabSelected(tab) },
                text = {
                    Text(
                        text = when (tab) {
                            AnalyticsTab.OVERVIEW -> stringResource(R.string.overview)
                            AnalyticsTab.ACTIVITY -> stringResource(R.string.activity)
                            AnalyticsTab.SOCIAL_IMPACT -> stringResource(R.string.social_impact)
                            AnalyticsTab.TRENDS -> stringResource(R.string.trends)
                            AnalyticsTab.ACHIEVEMENTS -> stringResource(R.string.achievements)
                        }
                    )
                },
                icon = {
                    Icon(
                        imageVector = when (tab) {
                            AnalyticsTab.OVERVIEW -> Icons.Default.Dashboard
                            AnalyticsTab.ACTIVITY -> Icons.Default.Activity
                            AnalyticsTab.SOCIAL_IMPACT -> Icons.Default.Group
                            AnalyticsTab.TRENDS -> Icons.Default.TrendingUp
                            AnalyticsTab.ACHIEVEMENTS -> Icons.Default.EmojiEvents
                        },
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                }
            )
        }
    }
}

@Composable
private fun OverviewTabContent(
    summary: AnalyticsSummary?,
    currentWeekAnalytics: UserAnalytics?,
    viewModel: AnalyticsViewModel
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Weekly summary
        item {
            WeeklySummaryCard(
                totalActivities = viewModel.getTotalActivitiesThisWeek(),
                completionRate = viewModel.getCompletionRate(),
                communityScore = viewModel.getCommunityScore(),
                weekComparisonText = viewModel.getWeekComparisonText(),
                engagementTrendIcon = viewModel.getEngagementTrendIcon()
            )
        }

        // Quick metrics
        item {
            QuickMetricsRow(
                newBuddies = viewModel.getNewBuddiesCount(),
                averageRating = viewModel.getAverageRating(),
                influenceRating = viewModel.getInfluenceRating()
            )
        }

        // Recent achievements
        if (viewModel.getRecentAchievements().isNotEmpty()) {
            item {
                RecentAchievementsCard(
                    achievements = viewModel.getRecentAchievements().take(3)
                )
            }
        }

        // Personal insights
        item {
            PersonalInsightsCard(
                favoriteCategories = viewModel.getFavoriteCategories(),
                popularTimeSlots = viewModel.getPopularTimeSlots(),
                preferredLocations = viewModel.getPreferredLocations()
            )
        }
    }
}

@Composable
private fun ActivityTabContent(
    analytics: UserAnalytics?,
    history: List<UserAnalytics>,
    viewModel: AnalyticsViewModel
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Activity overview
        item {
            ActivityOverviewCard(
                weeklyStats = analytics?.weeklyStats,
                chartData = viewModel.getActivityChartData()
            )
        }

        // Activity trend chart
        if (history.isNotEmpty()) {
            item {
                ActivityTrendCard(
                    history = history,
                    trendData = viewModel.getTrendData()
                )
            }
        }

        // Activity breakdown
        analytics?.weeklyStats?.let { stats ->
            item {
                ActivityBreakdownCard(stats)
            }
        }
    }
}

@Composable
private fun SocialImpactTabContent(
    analytics: UserAnalytics?,
    viewModel: AnalyticsViewModel
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Social impact overview
        item {
            SocialImpactOverviewCard(
                socialImpact = analytics?.socialImpact,
                chartData = viewModel.getSocialImpactChartData()
            )
        }

        // Leadership & community
        analytics?.socialImpact?.let { impact ->
            item {
                LeadershipCard(impact)
            }
        }

        // Mentorship activity
        analytics?.socialImpact?.let { impact ->
            item {
                MentorshipCard(impact)
            }
        }
    }
}

@Composable
private fun TrendsTabContent(
    analytics: UserAnalytics?,
    history: List<UserAnalytics>,
    viewModel: AnalyticsViewModel
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Time patterns
        item {
            TimePatternCard(
                timeSlots = viewModel.getPopularTimeSlots()
            )
        }

        // Location preferences
        item {
            LocationPreferenceCard(
                locations = viewModel.getPreferredLocations()
            )
        }

        // Engagement trends
        if (history.isNotEmpty()) {
            item {
                EngagementTrendsCard(
                    history = history,
                    currentTrend = analytics?.trendAnalysis?.engagementTrend
                )
            }
        }
    }
}

@Composable
private fun AchievementsTabContent(
    achievements: AchievementData?,
    viewModel: AnalyticsViewModel
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Achievement progress
        item {
            AchievementProgressCard(
                unlockedCount = viewModel.getUnlockedAchievementsCount(),
                totalCount = viewModel.getTotalAchievementsCount()
            )
        }

        // Achievement categories
        achievements?.let { achievementData ->
            val topAchievements = viewModel.getTopAchievementsByCategory()
            items(topAchievements.toList()) { (category, categoryAchievements) ->
                AchievementCategoryCard(
                    category = category,
                    achievements = categoryAchievements
                )
            }
        }
    }
}