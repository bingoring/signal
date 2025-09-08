package com.signal.app.features.signal.presentation.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInFromBottom
import androidx.compose.animation.slideOutToBottom
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.maps.android.compose.*
import com.signal.app.R
import com.signal.app.features.signal.data.models.Signal
import com.signal.app.features.signal.data.models.SignalWithDistance
import com.signal.app.features.signal.presentation.components.SignalBottomSheet
import com.signal.app.features.signal.presentation.components.SignalFilterSheet
import com.signal.app.features.signal.presentation.components.SignalMarker
import com.signal.app.features.signal.presentation.viewmodels.SignalMapViewModel
import kotlinx.coroutines.launch

/**
 * Signal 지도 화면
 * Flutter SignalMapPage와 동일한 기능을 Android에서 제공
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignalMapScreen(
    onNavigateToSignalCreate: (Double, Double) -> Unit,
    viewModel: SignalMapViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    
    val uiState by viewModel.uiState.collectAsState()
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(
            LatLng(37.5665, 126.9780), // 서울 중심
            11f
        )
    }
    
    var showFilterSheet by remember { mutableStateOf(false) }
    var selectedSignal by remember { mutableStateOf<Signal?>(null) }
    var searchQuery by remember { mutableStateOf("") }

    // 위치 업데이트 처리
    LaunchedEffect(uiState.userLocation) {
        uiState.userLocation?.let { location ->
            val latLng = LatLng(location.latitude, location.longitude)
            cameraPositionState.animate(
                CameraUpdateFactory.newLatLngZoom(latLng, 15f),
                1000
            )
        }
    }

    // 카메라 이동 감지
    LaunchedEffect(cameraPositionState.position) {
        val target = cameraPositionState.position.target
        viewModel.updateMapBounds(target.latitude, target.longitude)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // Google Maps
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            properties = MapProperties(
                isMyLocationEnabled = uiState.hasLocationPermission,
                mapType = MapType.NORMAL
            ),
            uiSettings = MapUiSettings(
                myLocationButtonEnabled = false,
                zoomControlsEnabled = false,
                mapToolbarEnabled = false,
                compassEnabled = true,
                tiltGesturesEnabled = false
            ),
            onMapClick = {
                selectedSignal = null
            }
        ) {
            // 내 위치 마커
            uiState.userLocation?.let { location ->
                Marker(
                    state = MarkerState(LatLng(location.latitude, location.longitude)),
                    title = "내 위치",
                    icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN)
                )
            }

            // 시그널 마커들
            uiState.signals.forEach { signalWithDistance ->
                SignalMarker(
                    signal = signalWithDistance.signal,
                    isSelected = selectedSignal?.id == signalWithDistance.signal.id,
                    onClick = { signal ->
                        selectedSignal = signal
                    }
                )
            }
        }

        // 상단 검색바 및 필터
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .shadow(8.dp, RoundedCornerShape(24.dp)),
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 검색 필드
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("위치나 시그널 검색...") },
                    leadingIcon = {
                        Icon(Icons.Default.Search, contentDescription = "검색")
                    },
                    trailingIcon = if (uiState.isLoading) {
                        {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp
                            )
                        }
                    } else null,
                    singleLine = true,
                    shape = RoundedCornerShape(16.dp),
                    keyboardOptions = androidx.compose.ui.text.input.KeyboardOptions(
                        imeAction = androidx.compose.ui.text.input.ImeAction.Search
                    ),
                    keyboardActions = androidx.compose.foundation.text.KeyboardActions(
                        onSearch = {
                            if (searchQuery.isNotEmpty()) {
                                viewModel.searchSignals(searchQuery)
                            }
                        }
                    )
                )

                Spacer(modifier = Modifier.width(8.dp))

                // 필터 버튼
                FilledIconButton(
                    onClick = { showFilterSheet = true },
                    modifier = Modifier.size(48.dp),
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = if (uiState.hasActiveFilters) 
                            MaterialTheme.colorScheme.primary 
                        else 
                            MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Icon(
                        Icons.Default.Tune,
                        contentDescription = "필터",
                        tint = if (uiState.hasActiveFilters) 
                            MaterialTheme.colorScheme.onPrimary 
                        else 
                            MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        // 우하단 컨트롤 버튼들
        Column(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp, bottom = 100.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // 내 위치로 이동
            SmallFloatingActionButton(
                onClick = {
                    scope.launch {
                        viewModel.moveToMyLocation()?.let { location ->
                            val latLng = LatLng(location.latitude, location.longitude)
                            cameraPositionState.animate(
                                CameraUpdateFactory.newLatLngZoom(latLng, 17f)
                            )
                        }
                    }
                },
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface
            ) {
                Icon(Icons.Default.MyLocation, contentDescription = "내 위치")
            }

            // 새로고침
            SmallFloatingActionButton(
                onClick = { viewModel.refreshNearbySignals() },
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface
            ) {
                if (uiState.isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Icon(Icons.Default.Refresh, contentDescription = "새로고침")
                }
            }
        }

        // 시그널 생성 버튼
        ExtendedFloatingActionButton(
            onClick = {
                uiState.userLocation?.let { location ->
                    onNavigateToSignalCreate(location.latitude, location.longitude)
                }
            },
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 32.dp)
                .clip(CircleShape),
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary
        ) {
            Icon(Icons.Default.Add, contentDescription = "시그널 생성")
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "시그널 생성",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold
            )
        }

        // 로딩 오버레이
        AnimatedVisibility(
            visible = uiState.isLoading && uiState.signals.isEmpty(),
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                Card(
                    modifier = Modifier.padding(32.dp),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        CircularProgressIndicator()
                        Text(
                            text = "근처 시그널을 찾고 있어요...",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
        }

        // 에러 스낵바
        uiState.error?.let { error ->
            LaunchedEffect(error) {
                // 스낵바 표시 로직
                viewModel.clearError()
            }
        }
    }

    // 필터 바텀시트
    if (showFilterSheet) {
        SignalFilterSheet(
            currentFilters = uiState.selectedCategories,
            currentRadius = uiState.searchRadius,
            onFiltersChanged = { categories, radius ->
                viewModel.updateFilters(categories, radius)
            },
            onDismiss = { showFilterSheet = false }
        )
    }

    // 시그널 상세 바텀시트
    selectedSignal?.let { signal ->
        SignalBottomSheet(
            signal = signal,
            onJoinSignal = { signalId, message ->
                viewModel.joinSignal(signalId, message)
            },
            onLeaveSignal = { signalId ->
                viewModel.leaveSignal(signalId)
            },
            onDismiss = { selectedSignal = null }
        )
    }
}

/**
 * 배경색 확장 함수
 */
@Composable
fun Modifier.background(color: Color): Modifier {
    return this.then(
        androidx.compose.foundation.background(color)
    )
}