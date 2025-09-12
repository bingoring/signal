package com.signal.app.features.analytics.presentation.components

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.signal.app.R
import com.signal.app.features.analytics.data.models.*

@Composable
fun SocialImpactOverviewCard(
    socialImpact: SocialImpactMetrics?,
    chartData: List<ChartDataPoint>
) {
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
                    text = stringResource(R.string.social_impact_overview),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Icon(
                    imageVector = Icons.Default.Group,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            socialImpact?.let { impact ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    SocialMetric(
                        label = stringResource(R.string.community),
                        value = impact.communityScore.toInt().toString(),
                        color = Color(0xFFFF9800)
                    )
                    SocialMetric(
                        label = stringResource(R.string.influence),
                        value = String.format("%.1f", impact.influenceRating),
                        color = Color(0xFF9C27B0)
                    )
                    SocialMetric(
                        label = stringResource(R.string.helpfulness),
                        value = impact.helpfulnessScore.toInt().toString(),
                        color = Color(0xFF00BCD4)
                    )
                }
                
                if (chartData.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(16.dp))
                    SimpleBarChart(data = chartData)
                }
            }
        }
    }
}

@Composable
private fun SocialMetric(
    label: String,
    value: String,
    color: Color
) {
    Column(
        horizontalAlignment = Alignment.CenterVertically
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
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
fun LeadershipCard(socialImpact: SocialImpactMetrics) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Star,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(R.string.leadership_community),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            LeadershipMetricRow(
                icon = Icons.Default.EmojiEvents,
                label = stringResource(R.string.leadership_events),
                value = socialImpact.leadershipEvents.toString(),
                description = stringResource(R.string.times_led_activities)
            )
            
            LeadershipMetricRow(
                icon = Icons.Default.ThumbUp,
                label = stringResource(R.string.positive_feedback),
                value = socialImpact.positiveFeedback.toString(),
                description = stringResource(R.string.positive_reviews_received)
            )
            
            LeadershipMetricRow(
                icon = Icons.Default.TrendingUp,
                label = stringResource(R.string.influence_score),
                value = String.format("%.1f", socialImpact.influenceRating),
                description = stringResource(R.string.overall_influence_rating)
            )
        }
    }
}

@Composable
private fun LeadershipMetricRow(
    icon: ImageVector,
    label: String,
    value: String,
    description: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
    }
}

@Composable
fun MentorshipCard(socialImpact: SocialImpactMetrics) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.School,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(R.string.mentorship_activity),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = stringResource(R.string.mentorship_sessions),
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = stringResource(R.string.helped_other_users),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                
                Box(
                    modifier = Modifier
                        .size(60.dp)
                        .background(
                            brush = Brush.radialGradient(
                                colors = listOf(
                                    MaterialTheme.colorScheme.secondary.copy(alpha = 0.2f),
                                    MaterialTheme.colorScheme.secondary.copy(alpha = 0.1f)
                                )
                            ),
                            shape = CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = socialImpact.mentorshipActivity.toString(),
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.secondary
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            val helpfulnessLevel = when {
                socialImpact.helpfulnessScore >= 80 -> stringResource(R.string.exceptional_helper)
                socialImpact.helpfulnessScore >= 60 -> stringResource(R.string.active_helper)
                socialImpact.helpfulnessScore >= 40 -> stringResource(R.string.helpful_member)
                else -> stringResource(R.string.growing_helper)
            }
            
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Psychology,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.tertiary,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = helpfulnessLevel,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.tertiary,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

@Composable
fun TimePatternCard(timeSlots: List<TimeSlot>) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Schedule,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(R.string.time_patterns),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (timeSlots.isNotEmpty()) {
                timeSlots.take(3).forEachIndexed { index, timeSlot ->
                    TimeSlotItem(
                        timeSlot = timeSlot,
                        rank = index + 1
                    )
                    if (index < timeSlots.size - 1 && index < 2) {
                        Spacer(modifier = Modifier.height(12.dp))
                    }
                }
            } else {
                Text(
                    text = stringResource(R.string.no_pattern_data),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

@Composable
private fun TimeSlotItem(timeSlot: TimeSlot, rank: Int) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val rankColor = when (rank) {
            1 -> Color(0xFFFFD700) // Gold
            2 -> Color(0xFFC0C0C0) // Silver
            3 -> Color(0xFFCD7F32) // Bronze
            else -> MaterialTheme.colorScheme.outline
        }
        
        Box(
            modifier = Modifier
                .size(32.dp)
                .background(
                    color = rankColor.copy(alpha = 0.2f),
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = rank.toString(),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = rankColor
            )
        }
        
        Spacer(modifier = Modifier.width(12.dp))
        
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "${timeSlot.dayName} ${timeSlot.timeRange}",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = "${stringResource(R.string.activity_count)}: ${timeSlot.activityCount}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        Text(
            text = "${(timeSlot.probability * 100).toInt()}%",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
    }
}

@Composable
fun LocationPreferenceCard(locations: List<LocationTrend>) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.LocationOn,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(R.string.location_preferences),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (locations.isNotEmpty()) {
                locations.take(3).forEach { location ->
                    LocationItem(location = location)
                    Spacer(modifier = Modifier.height(8.dp))
                }
            } else {
                Text(
                    text = stringResource(R.string.no_location_data),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

@Composable
private fun LocationItem(location: LocationTrend) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = when (location.category) {
                "cafe" -> Icons.Default.LocalCafe
                "park" -> Icons.Default.Park
                "restaurant" -> Icons.Default.Restaurant
                "shopping" -> Icons.Default.ShoppingBag
                "culture" -> Icons.Default.Museum
                else -> Icons.Default.Place
            },
            contentDescription = null,
            tint = MaterialTheme.colorScheme.secondary,
            modifier = Modifier.size(20.dp)
        )
        
        Spacer(modifier = Modifier.width(12.dp))
        
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = location.district,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = "${location.category} • ${location.visitFrequency}회 방문",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        LinearProgressIndicator(
            progress = (location.preferenceScore / 100.0f).coerceAtMost(1.0f),
            modifier = Modifier
                .width(60.dp)
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp)),
            color = MaterialTheme.colorScheme.secondary,
            trackColor = MaterialTheme.colorScheme.surfaceVariant
        )
    }
}

@Composable
fun EngagementTrendsCard(
    history: List<UserAnalytics>,
    currentTrend: String?
) {
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
                    text = stringResource(R.string.engagement_trends),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                
                currentTrend?.let { trend ->
                    val (trendIcon, trendColor) = when (trend.lowercase()) {
                        "increasing" -> "📈" to Color(0xFF4CAF50)
                        "decreasing" -> "📉" to Color(0xFFFF5722)
                        else -> "➡️" to MaterialTheme.colorScheme.outline
                    }
                    
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = trendIcon,
                            style = MaterialTheme.typography.bodyLarge
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = trend.toEngagementTrendKorean(),
                            style = MaterialTheme.typography.bodyMedium,
                            color = trendColor,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            if (history.size >= 2) {
                val trendPoints = history.takeLast(4).map { analytics ->
                    ChartDataPoint(
                        label = formatWeekLabel(analytics.weekStartDate),
                        value = analytics.weeklyStats.totalParticipation.toDouble(),
                        color = "#2196F3"
                    )
                }
                SimpleLineChart(data = trendPoints)
            } else {
                Text(
                    text = stringResource(R.string.need_more_data_for_trends),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

private fun formatWeekLabel(weekStartDate: String): String {
    return try {
        val parts = weekStartDate.split("-")
        if (parts.size >= 3) {
            "${parts[1]}/${parts[2]}"
        } else {
            weekStartDate
        }
    } catch (e: Exception) {
        weekStartDate
    }
}