package com.signal.app.features.signal.presentation.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.signal.app.features.signal.data.models.Signal
import com.signal.app.features.signal.data.models.SignalCategory

/**
 * 시그널 마커 컴포넌트
 * Flutter에서 사용되는 시그널 마커와 동일한 기능
 */
@Composable
fun SignalMarker(
    signal: Signal,
    isSelected: Boolean = false,
    onClick: (Signal) -> Unit
) {
    val markerState = MarkerState(
        position = LatLng(signal.latitude, signal.longitude)
    )

    Marker(
        state = markerState,
        title = signal.title,
        snippet = "${signal.currentParticipants}/${signal.maxParticipants}명",
        icon = getMarkerIcon(signal, isSelected),
        onInfoWindowClick = { onClick(signal) },
        onClick = { 
            onClick(signal)
            false // false를 반환하면 정보창이 표시됨
        }
    )
}

/**
 * 시그널 상태에 따른 마커 아이콘 생성
 */
private fun getMarkerIcon(signal: Signal, isSelected: Boolean): BitmapDescriptor {
    return when {
        isSelected -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_ORANGE)
        signal.isActive() -> {
            when (SignalCategory.fromString(signal.category)) {
                SignalCategory.FOOD -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_RED)
                SignalCategory.COFFEE -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_YELLOW)
                SignalCategory.CULTURE -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_VIOLET)
                SignalCategory.SPORTS -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN)
                SignalCategory.STUDY -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_BLUE)
                SignalCategory.WORK -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_CYAN)
                SignalCategory.SOCIAL -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_MAGENTA)
                SignalCategory.TRAVEL -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE)
                SignalCategory.SHOPPING -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_ROSE)
                SignalCategory.OTHER -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_BLUE)
            }
        }
        else -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE)
    }
}