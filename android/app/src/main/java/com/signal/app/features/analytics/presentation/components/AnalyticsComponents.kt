package com.signal.app.features.analytics.presentation.components

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
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.signal.app.R
import com.signal.app.features.analytics.data.models.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WeeklySummaryCard(
    totalActivities: Int,
    completionRate: Double,
    communityScore: Double,
    weekComparisonText: String,
    engagementTrendIcon: String
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.weekly_summary),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = engagementTrendIcon,
                    style = MaterialTheme.typography.headlineLarge
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                MetricItem(
                    label = stringResource(R.string.total_activities),
                    value = totalActivities.toString(),
                    color = MaterialTheme.colorScheme.primary
                )
                MetricItem(
                    label = stringResource(R.string.completion_rate),
                    value = "${completionRate.toInt()}%",
                    color = MaterialTheme.colorScheme.secondary
                )
                MetricItem(
                    label = stringResource(R.string.community_score),
                    value = "${communityScore.toInt()}",
                    color = MaterialTheme.colorScheme.tertiary
                )
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            Text(
                text = weekComparisonText,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun MetricItem(
    label: String,
    value: String,
    color: Color
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
fun QuickMetricsRow(
    newBuddies: Int,
    averageRating: Double,
    influenceRating: Double
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        QuickMetricCard(
            modifier = Modifier.weight(1f),
            icon = Icons.Default.Group,
            label = stringResource(R.string.new_buddies),
            value = newBuddies.toString(),
            color = MaterialTheme.colorScheme.primary
        )
        QuickMetricCard(
            modifier = Modifier.weight(1f),
            icon = Icons.Default.Star,
            label = stringResource(R.string.avg_rating),
            value = String.format("%.1f", averageRating),
            color = MaterialTheme.colorScheme.secondary
        )
        QuickMetricCard(
            modifier = Modifier.weight(1f),
            icon = Icons.Default.TrendingUp,
            label = stringResource(R.string.influence),
            value = String.format("%.1f", influenceRating),
            color = MaterialTheme.colorScheme.tertiary
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun QuickMetricCard(
    modifier: Modifier = Modifier,
    icon: ImageVector,
    label: String,
    value: String,
    color: Color
) {
    Card(
        modifier = modifier,
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
fun RecentAchievementsCard(
    achievements: List<Achievement>
) {
    if (achievements.isEmpty()) return
    
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.recent_achievements),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Icon(
                    imageVector = Icons.Default.EmojiEvents,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary
                )
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            achievements.take(3).forEach { achievement ->
                AchievementItem(achievement = achievement)
                if (achievement != achievements.last()) {
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }
        }
    }
}

@Composable
private fun AchievementItem(achievement: Achievement) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = achievement.categoryEmoji,
            style = MaterialTheme.typography.headlineMedium
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = achievement.title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = achievement.description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(
            text = achievement.difficultyEmoji,
            style = MaterialTheme.typography.titleMedium
        )
    }
}

@Composable
fun PersonalInsightsCard(
    favoriteCategories: List<String>,
    popularTimeSlots: List<TimeSlot>,
    preferredLocations: List<LocationTrend>
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = stringResource(R.string.personal_insights),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (favoriteCategories.isNotEmpty()) {
                InsightSection(
                    title = stringResource(R.string.favorite_categories),
                    icon = Icons.Default.Category,
                    content = favoriteCategories.joinToDisplayString(3)
                )
            }
            
            if (popularTimeSlots.isNotEmpty()) {
                InsightSection(
                    title = stringResource(R.string.popular_times),
                    icon = Icons.Default.Schedule,
                    content = popularTimeSlots.take(2).joinToString(", ") { 
                        "${it.dayName} ${it.timeRange}" 
                    }
                )
            }
            
            if (preferredLocations.isNotEmpty()) {
                InsightSection(
                    title = stringResource(R.string.preferred_locations),
                    icon = Icons.Default.LocationOn,
                    content = preferredLocations.take(3).joinToString(", ") { it.district }
                )
            }
        }
    }
}

@Composable
private fun InsightSection(
    title: String,
    icon: ImageVector,
    content: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.Top
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Column {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = content,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
fun ActivityOverviewCard(
    weeklyStats: WeeklyActivityStats?,
    chartData: List<ChartDataPoint>
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = stringResource(R.string.activity_overview),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            weeklyStats?.let { stats ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    ActivityMetric(
                        label = stringResource(R.string.created),
                        value = stats.signalsCreated.toString(),
                        color = Color(0xFF4CAF50)
                    )
                    ActivityMetric(
                        label = stringResource(R.string.joined),
                        value = stats.signalsJoined.toString(),
                        color = Color(0xFF2196F3)
                    )
                    ActivityMetric(
                        label = stringResource(R.string.total),
                        value = stats.totalParticipation.toString(),
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
            
            if (chartData.isNotEmpty()) {
                Spacer(modifier = Modifier.height(16.dp))
                SimpleBarChart(data = chartData)
            }
        }
    }
}

@Composable
private fun ActivityMetric(
    label: String,
    value: String,
    color: Color
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
fun SimpleBarChart(
    data: List<ChartDataPoint>,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return
    
    val maxValue = data.maxOfOrNull { it.value } ?: 0.0
    
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(120.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.Bottom
    ) {
        data.forEach { point ->
            val barHeight = if (maxValue > 0) (point.value / maxValue * 100).dp else 0.dp
            
            Column(
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = point.value.toInt().toString(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(4.dp))
                Box(
                    modifier = Modifier
                        .width(32.dp)
                        .height(barHeight)
                        .background(
                            color = Color(android.graphics.Color.parseColor(point.color)),
                            shape = RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp)
                        )
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = point.label,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
fun ActivityTrendCard(
    history: List<UserAnalytics>,
    trendData: List<ChartDataPoint>
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = stringResource(R.string.activity_trends),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(12.dp))
            
            if (trendData.isNotEmpty()) {
                SimpleLineChart(data = trendData)
            } else {
                Text(
                    text = stringResource(R.string.no_trend_data),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

@Composable
fun SimpleLineChart(
    data: List<ChartDataPoint>,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return
    
    val maxValue = data.maxOfOrNull { it.value } ?: 0.0
    val minValue = data.minOfOrNull { it.value } ?: 0.0
    val range = maxValue - minValue
    
    Column(modifier = modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(100.dp)
        ) {
            // Simplified line representation using boxes for now
            Row(
                modifier = Modifier.fillMaxSize(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.Bottom
            ) {
                data.forEachIndexed { index, point ->
                    val normalizedValue = if (range > 0) ((point.value - minValue) / range) else 0.0
                    val barHeight = (normalizedValue * 80).dp.coerceAtLeast(4.dp)
                    
                    Box(
                        modifier = Modifier
                            .width(8.dp)
                            .height(barHeight)
                            .background(
                                Color(android.graphics.Color.parseColor(point.color)),
                                RoundedCornerShape(4.dp)
                            )
                    )
                    
                    if (index < data.size - 1) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(2.dp)
                                .background(
                                    Color(android.graphics.Color.parseColor(point.color)).copy(alpha = 0.3f)
                                )
                        )
                    }
                }
            }
        }
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            data.forEach { point ->
                Text(
                    text = point.label,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
fun ActivityBreakdownCard(stats: WeeklyActivityStats) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = stringResource(R.string.activity_breakdown),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            BreakdownItem(
                label = stringResource(R.string.completion_rate),
                value = "${stats.completionRate.toInt()}%",
                progress = (stats.completionRate / 100).toFloat()
            )
            
            BreakdownItem(
                label = stringResource(R.string.average_rating),
                value = String.format("%.1f", stats.averageRating),
                progress = (stats.averageRating / 5.0).toFloat()
            )
            
            BreakdownItem(
                label = stringResource(R.string.messages_exchanged),
                value = stats.messagesExchanged.toString(),
                progress = (stats.messagesExchanged / 100.0f).coerceAtMost(1.0f)
            )
        }
    }
}

@Composable
private fun BreakdownItem(
    label: String,
    value: String,
    progress: Float
) {
    Column(modifier = Modifier.padding(vertical = 8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold
            )
        }
        Spacer(modifier = Modifier.height(4.dp))
        LinearProgressIndicator(
            progress = progress,
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp)),
            color = MaterialTheme.colorScheme.primary,
            trackColor = MaterialTheme.colorScheme.surfaceVariant
        )
    }
}