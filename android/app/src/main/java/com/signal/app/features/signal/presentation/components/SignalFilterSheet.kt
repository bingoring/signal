package com.signal.app.features.signal.presentation.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.signal.app.features.signal.data.models.SignalCategory

/**
 * 시그널 필터 바텀시트
 * Flutter SignalFilterSheet와 동일한 기능을 Android에서 제공
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignalFilterSheet(
    currentFilters: List<String>,
    currentRadius: Double,
    onFiltersChanged: (List<String>, Double) -> Unit,
    onDismiss: () -> Unit
) {
    var selectedCategories by remember { mutableStateOf(currentFilters.toSet()) }
    var searchRadius by remember { mutableStateOf(currentRadius) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface,
        contentColor = MaterialTheme.colorScheme.onSurface,
        dragHandle = {
            Surface(
                modifier = Modifier
                    .width(32.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
            ) {}
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // 헤더
            Text(
                text = "필터 설정",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )

            // 카테고리 필터
            CategoryFilterSection(
                selectedCategories = selectedCategories,
                onCategoryToggle = { category ->
                    selectedCategories = if (selectedCategories.contains(category)) {
                        selectedCategories - category
                    } else {
                        selectedCategories + category
                    }
                }
            )

            // 검색 반경 필터
            RadiusFilterSection(
                currentRadius = searchRadius,
                onRadiusChange = { searchRadius = it }
            )

            // 액션 버튼들
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // 초기화 버튼
                OutlinedButton(
                    onClick = {
                        selectedCategories = emptySet()
                        searchRadius = 1000.0
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("초기화")
                }

                // 적용 버튼
                Button(
                    onClick = {
                        onFiltersChanged(selectedCategories.toList(), searchRadius)
                        onDismiss()
                    },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("적용")
                }
            }
        }
    }
}

@Composable
private fun CategoryFilterSection(
    selectedCategories: Set<String>,
    onCategoryToggle: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            text = "카테고리",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )

        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(horizontal = 4.dp)
        ) {
            items(SignalCategory.entries.toList()) { category ->
                CategoryChip(
                    category = category,
                    isSelected = selectedCategories.contains(category.name),
                    onClick = { onCategoryToggle(category.name) }
                )
            }
        }

        // 선택된 카테고리 개수 표시
        if (selectedCategories.isNotEmpty()) {
            Text(
                text = "${selectedCategories.size}개 카테고리 선택됨",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun CategoryChip(
    category: SignalCategory,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    FilterChip(
        onClick = onClick,
        label = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = getCategoryIcon(category),
                    contentDescription = category.displayName,
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    text = category.displayName,
                    fontSize = 14.sp
                )
            }
        },
        selected = isSelected,
        colors = FilterChipDefaults.filterChipColors(
            selectedContainerColor = MaterialTheme.colorScheme.primary,
            selectedLabelColor = MaterialTheme.colorScheme.onPrimary
        )
    )
}

@Composable
private fun RadiusFilterSection(
    currentRadius: Double,
    onRadiusChange: (Double) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "검색 반경",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = formatRadius(currentRadius),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Medium
            )
        }

        // 반경 슬라이더
        Slider(
            value = currentRadius.toFloat(),
            onValueChange = { onRadiusChange(it.toDouble()) },
            valueRange = 200f..5000f,
            steps = 19, // 200m부터 5km까지 250m 간격
            colors = SliderDefaults.colors(
                thumbColor = MaterialTheme.colorScheme.primary,
                activeTrackColor = MaterialTheme.colorScheme.primary
            )
        )

        // 반경 프리셋 버튼들
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            val presetRadiuses = listOf(500.0, 1000.0, 2000.0, 3000.0)
            
            presetRadiuses.forEach { radius ->
                val isSelected = currentRadius == radius
                
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .selectable(
                            selected = isSelected,
                            onClick = { onRadiusChange(radius) }
                        ),
                    shape = RoundedCornerShape(8.dp),
                    color = if (isSelected) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.surfaceVariant
                    }
                ) {
                    Box(
                        modifier = Modifier.padding(vertical = 8.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = formatRadius(radius),
                            style = MaterialTheme.typography.bodySmall,
                            color = if (isSelected) {
                                MaterialTheme.colorScheme.onPrimary
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            },
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                        )
                    }
                }
            }
        }
    }
}

// Helper functions
private fun formatRadius(radius: Double): String {
    return when {
        radius < 1000 -> "${radius.toInt()}m"
        else -> String.format("%.1fkm", radius / 1000.0)
    }
}

private fun getCategoryIcon(category: SignalCategory): ImageVector {
    return when (category) {
        SignalCategory.FOOD -> Icons.Default.Restaurant
        SignalCategory.COFFEE -> Icons.Default.LocalCafe
        SignalCategory.CULTURE -> Icons.Default.Theater
        SignalCategory.SPORTS -> Icons.Default.SportsBaseball
        SignalCategory.STUDY -> Icons.Default.School
        SignalCategory.WORK -> Icons.Default.Work
        SignalCategory.SOCIAL -> Icons.Default.Group
        SignalCategory.TRAVEL -> Icons.Default.Flight
        SignalCategory.SHOPPING -> Icons.Default.ShoppingCart
        SignalCategory.OTHER -> Icons.Default.MoreHoriz
    }
}