package com.signal.app.features.signal.presentation.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.signal.app.features.signal.presentation.viewmodels.EnhancedMapViewModel
import com.signal.app.features.signal.presentation.state.EnhancedMapState
import com.signal.app.features.signal.presentation.state.MapViewMode
import com.signal.app.features.signal.presentation.state.MapSearchMode

/**
 * 향상된 지도 컨트롤 패널
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EnhancedMapControls(
    viewModel: EnhancedMapViewModel = hiltViewModel(),
    modifier: Modifier = Modifier
) {
    val state by viewModel.state.collectAsState()
    var isExpanded by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    val keyboardController = LocalSoftwareKeyboardController.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        // 메인 검색바
        MainSearchBar(
            query = searchQuery,
            onQueryChange = { searchQuery = it },
            onSearch = {
                viewModel.searchSignals(it)
                keyboardController?.hide()
            },
            isExpanded = isExpanded,
            onExpandToggle = { isExpanded = !isExpanded }
        )

        Spacer(modifier = Modifier.height(12.dp))

        // 컨트롤 패널
        ControlPanel(
            state = state,
            isExpanded = isExpanded,
            onFilterClick = { viewModel.showFilterDialog() },
            onDensityToggle = { viewModel.toggleDensityMode() },
            onClusterToggle = { viewModel.toggleClusterMode() },
            onStatisticsClick = { viewModel.showStatistics() },
            onRadiusChange = { viewModel.updateSearchRadius(it) }
        )

        // 확장된 모드 선택기
        AnimatedVisibility(
            visible = isExpanded,
            enter = expandVertically(animationSpec = tween(300)),
            exit = shrinkVertically(animationSpec = tween(300))
        ) {
            Column {
                Spacer(modifier = Modifier.height(12.dp))
                ModeSelector(
                    selectedMode = state.searchMode,
                    onModeSelected = { viewModel.setSearchMode(it) }
                )
            }
        }
    }
}

@Composable
private fun MainSearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    onSearch: (String) -> Unit,
    isExpanded: Boolean,
    onExpandToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    val keyboardController = LocalSoftwareKeyboardController.current
    val expandRotation by animateFloatAsState(
        targetValue = if (isExpanded) 180f else 0f,
        animationSpec = tween(200)
    )

    Card(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = RoundedCornerShape(28.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 검색 입력 필드
            OutlinedTextField(
                value = query,
                onValueChange = onQueryChange,
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 12.dp),
                placeholder = { Text("위치나 시그널 검색...") },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "검색",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color.Transparent,
                    unfocusedBorderColor = Color.Transparent
                ),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(
                    onSearch = {
                        onSearch(query)
                        keyboardController?.hide()
                    }
                ),
                singleLine = true
            )

            // 음성 검색 버튼
            IconButton(
                onClick = { /* TODO: 음성 검색 구현 */ }
            ) {
                Icon(
                    imageVector = Icons.Default.Mic,
                    contentDescription = "음성 검색",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // 확장 토글 버튼
            IconButton(
                onClick = onExpandToggle
            ) {
                Icon(
                    imageVector = Icons.Default.ExpandMore,
                    contentDescription = if (isExpanded) "축소" else "확장",
                    modifier = Modifier.rotate(expandRotation),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun ControlPanel(
    state: EnhancedMapState,
    isExpanded: Boolean,
    onFilterClick: () -> Unit,
    onDensityToggle: () -> Unit,
    onClusterToggle: () -> Unit,
    onStatisticsClick: () -> Unit,
    onRadiusChange: (Float) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            // 기본 컨트롤 행
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // 필터 버튼
                ControlButton(
                    icon = Icons.Default.FilterAlt,
                    label = "필터",
                    isActive = state.hasActiveAdvancedFilters,
                    onClick = onFilterClick
                )

                // 밀도 모드 토글
                ControlButton(
                    icon = Icons.Default.Map,
                    label = "밀도",
                    isActive = state.viewMode == MapViewMode.DENSITY,
                    onClick = onDensityToggle
                )

                // 클러스터 모드 토글
                ControlButton(
                    icon = Icons.Default.GroupWork,
                    label = "클러스터",
                    isActive = state.viewMode == MapViewMode.CLUSTER,
                    onClick = onClusterToggle
                )

                Spacer(modifier = Modifier.weight(1f))

                // 통계 버튼
                ControlButton(
                    icon = Icons.Default.Analytics,
                    label = "통계",
                    onClick = onStatisticsClick
                )
            }

            // 확장된 컨트롤들
            AnimatedVisibility(
                visible = isExpanded,
                enter = expandVertically(animationSpec = tween(300)),
                exit = shrinkVertically(animationSpec = tween(300))
            ) {
                Column {
                    Spacer(modifier = Modifier.height(16.dp))

                    // 반경 슬라이더
                    Column {
                        Text(
                            text = "검색 반경: ${(state.searchRadius / 1000).toString().take(3)}km",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(8.dp))

                        Slider(
                            value = state.searchRadius,
                            onValueChange = onRadiusChange,
                            valueRange = 500f..20000f,
                            steps = 39,
                            colors = SliderDefaults.colors(
                                thumbColor = MaterialTheme.colorScheme.primary,
                                activeTrackColor = MaterialTheme.colorScheme.primary
                            )
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ControlButton(
    icon: ImageVector,
    label: String,
    isActive: Boolean = false,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val backgroundColor = if (isActive) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }

    val contentColor = if (isActive) {
        MaterialTheme.colorScheme.onPrimary
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }

    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .clickable { onClick() },
        color = backgroundColor,
        shape = RoundedCornerShape(20.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = contentColor,
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = label,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = contentColor
            )
        }
    }
}

@Composable
private fun ModeSelector(
    selectedMode: MapSearchMode,
    onModeSelected: (MapSearchMode) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(25.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        LazyRow(
            modifier = Modifier.padding(8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            items(MapSearchMode.values()) { mode ->
                ModeButton(
                    mode = mode,
                    isSelected = selectedMode == mode,
                    onSelected = { onModeSelected(mode) }
                )
            }
        }
    }
}

@Composable
private fun ModeButton(
    mode: MapSearchMode,
    isSelected: Boolean,
    onSelected: () -> Unit,
    modifier: Modifier = Modifier
) {
    val (icon, label) = when (mode) {
        MapSearchMode.RADIUS -> Icons.Default.LocationOn to "반경"
        MapSearchMode.POLYGON -> Icons.Default.CropFree to "다각형"
        MapSearchMode.ROUTE -> Icons.Default.Route to "경로"
        MapSearchMode.POI -> Icons.Default.Explore to "POI"
    }

    val backgroundColor = if (isSelected) {
        MaterialTheme.colorScheme.primary
    } else {
        Color.Transparent
    }

    val contentColor = if (isSelected) {
        MaterialTheme.colorScheme.onPrimary
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }

    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .clickable { onSelected() },
        color = backgroundColor,
        shape = RoundedCornerShape(20.dp)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = contentColor,
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = label,
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = contentColor
            )
        }
    }
}

// 확장된 필터 다이얼로그는 별도 파일로 분리하는 것이 좋습니다.
// EnhancedFilterDialog.kt