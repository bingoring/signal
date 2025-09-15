package com.signal.app.features.signal.presentation.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.model.*
import com.signal.app.features.signal.data.services.DensityPoint
import com.signal.app.features.signal.data.services.SignalCluster
import com.signal.app.features.signal.data.services.Hotspot
import com.signal.app.features.signal.presentation.state.MapViewMode
import kotlin.math.max
import kotlin.math.min

/**
 * 지도 시각화 레이어 (밀도 맵, 클러스터, 핫스팟)
 */
object MapVisualizationLayer {

    /**
     * 밀도 맵을 위한 히트맵 오버레이 생성
     */
    fun createDensityHeatmap(
        densityPoints: List<DensityPoint>,
        gridSize: Double = 0.01,
        baseColor: Color = Color.Blue
    ): Set<Polygon> {
        val polygons = mutableSetOf<Polygon>()

        densityPoints.forEachIndexed { index, point ->
            val opacity = calculateOpacity(point.density, point.weight)

            // 그리드 셀을 다각형으로 변환
            val polygon = Polygon.Builder()
                .addAll(createGridCell(point.latitude, point.longitude, gridSize))
                .fillColor(baseColor.copy(alpha = opacity).toArgb())
                .strokeColor(baseColor.copy(alpha = opacity * 0.7f).toArgb())
                .strokeWidth(1f)
                .clickable(false)
                .build()

            polygons.add(polygon)
        }

        return polygons
    }

    /**
     * 클러스터 마커 생성
     */
    fun createClusterMarkers(
        clusters: List<SignalCluster>,
        onClusterTap: (SignalCluster) -> Unit
    ): Set<Marker> {
        val markers = mutableSetOf<Marker>()

        clusters.forEach { cluster ->
            val marker = MarkerOptions()
                .position(LatLng(cluster.centerLat, cluster.centerLon))
                .icon(createClusterIcon(cluster.signalCount))
                .title("클러스터")
                .snippet("${cluster.signalCount}개 시그널")

            markers.add(marker)
        }

        return markers
    }

    /**
     * 핫스팟 마커 생성
     */
    fun createHotspotMarkers(
        hotspots: List<Hotspot>,
        onHotspotTap: (Hotspot) -> Unit
    ): Set<Marker> {
        val markers = mutableSetOf<Marker>()

        hotspots.forEach { hotspot ->
            val marker = MarkerOptions()
                .position(LatLng(hotspot.latitude, hotspot.longitude))
                .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_ORANGE))
                .title("핫스팟: ${hotspot.name}")
                .snippet("인기 지역")

            markers.add(marker)
        }

        return markers
    }

    /**
     * 다각형 검색 영역 표시
     */
    fun createPolygonSearchArea(
        polygonPoints: List<List<Double>>,
        fillColor: Color = Color.Blue,
        strokeColor: Color = Color.Blue
    ): Set<Polygon> {
        if (polygonPoints.size < 3) return emptySet()

        val points = polygonPoints.map { point ->
            LatLng(point[1], point[0]) // [lon, lat] -> LatLng
        }

        val polygon = Polygon.Builder()
            .addAll(points)
            .fillColor(fillColor.copy(alpha = 0.2f).toArgb())
            .strokeColor(strokeColor.toArgb())
            .strokeWidth(2f)
            .clickable(false)
            .build()

        return setOf(polygon)
    }

    /**
     * 경로 검색 영역 표시
     */
    fun createRouteSearchArea(
        startLat: Double,
        startLon: Double,
        endLat: Double,
        endLon: Double,
        bufferWidth: Double = 1000.0,
        color: Color = Color.Green
    ): Set<Polyline> {
        val polyline = PolylineOptions()
            .add(LatLng(startLat, startLon))
            .add(LatLng(endLat, endLon))
            .color(color.toArgb())
            .width(5f)
            .pattern(listOf(Dash(20f), Gap(10f)))

        return setOf(polyline)
    }

    /**
     * 반경 검색 영역 표시
     */
    fun createRadiusSearchArea(
        centerLat: Double,
        centerLon: Double,
        radius: Double,
        fillColor: Color = Color.Blue,
        strokeColor: Color = Color.Blue
    ): Set<Circle> {
        val circle = CircleOptions()
            .center(LatLng(centerLat, centerLon))
            .radius(radius)
            .fillColor(fillColor.copy(alpha = 0.1f).toArgb())
            .strokeColor(strokeColor.toArgb())
            .strokeWidth(2f)

        return setOf(circle)
    }

    // Private Helper Methods

    private fun calculateOpacity(density: Int, weight: Double): Float {
        // 밀도와 가중치를 기반으로 투명도 계산
        val normalizedDensity = min(density / 10.0, 1.0)
        val normalizedWeight = min(weight / 5.0, 1.0)
        return max(normalizedDensity * normalizedWeight, 0.1).toFloat()
    }

    private fun createGridCell(
        centerLat: Double,
        centerLon: Double,
        gridSize: Double
    ): List<LatLng> {
        val halfGrid = gridSize / 2
        return listOf(
            LatLng(centerLat - halfGrid, centerLon - halfGrid),
            LatLng(centerLat - halfGrid, centerLon + halfGrid),
            LatLng(centerLat + halfGrid, centerLon + halfGrid),
            LatLng(centerLat + halfGrid, centerLon - halfGrid)
        )
    }

    private fun createClusterIcon(count: Int): BitmapDescriptor {
        // 클러스터 크기에 따른 아이콘 선택
        return when {
            count < 5 -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_BLUE)
            count < 10 -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN)
            count < 20 -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_YELLOW)
            else -> BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_RED)
        }
    }
}

/**
 * 실시간 애니메이션을 위한 커스텀 컴포저블
 */
@Composable
fun AnimatedMapOverlay(
    densityPoints: List<DensityPoint>,
    clusters: List<SignalCluster>,
    viewMode: MapViewMode,
    onClusterTap: (SignalCluster) -> Unit,
    modifier: Modifier = Modifier
) {
    val pulseAnimation = rememberInfiniteTransition()
    val pulseScale by pulseAnimation.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000),
            repeatMode = RepeatMode.Reverse
        )
    )

    var previousViewMode by remember { mutableStateOf(viewMode) }
    val fadeAnimation = remember { Animatable(1f) }

    LaunchedEffect(viewMode) {
        if (previousViewMode != viewMode) {
            fadeAnimation.animateTo(0f, animationSpec = tween(250))
            fadeAnimation.animateTo(1f, animationSpec = tween(250))
            previousViewMode = viewMode
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .graphicsLayer(alpha = fadeAnimation.value)
    ) {
        when (viewMode) {
            MapViewMode.DENSITY -> DensityOverlay(
                densityPoints = densityPoints,
                pulseScale = pulseScale
            )
            MapViewMode.CLUSTER -> ClusterOverlay(
                clusters = clusters,
                onClusterTap = onClusterTap
            )
            else -> { /* 일반 모드 - 오버레이 없음 */ }
        }
    }
}

@Composable
private fun DensityOverlay(
    densityPoints: List<DensityPoint>,
    pulseScale: Float,
    modifier: Modifier = Modifier
) {
    Canvas(
        modifier = modifier.fillMaxSize()
    ) {
        densityPoints.forEach { point ->
            val opacity = calculateOpacity(point.density, point.weight)
            val radius = 20.dp.toPx() * pulseScale

            drawCircle(
                color = Color.Red.copy(alpha = opacity),
                radius = radius,
                center = Offset(
                    x = point.longitude.toFloat() * size.width, // 실제 좌표 변환 필요
                    y = point.latitude.toFloat() * size.height
                )
            )
        }
    }
}

@Composable
private fun ClusterOverlay(
    clusters: List<SignalCluster>,
    onClusterTap: (SignalCluster) -> Unit,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier.fillMaxSize()) {
        clusters.forEach { cluster ->
            ClusterMarker(
                cluster = cluster,
                onTap = { onClusterTap(cluster) },
                modifier = Modifier.offset(
                    x = (cluster.centerLon * 100).dp, // 실제 좌표 변환 필요
                    y = (cluster.centerLat * 100).dp
                )
            )
        }
    }
}

@Composable
private fun ClusterMarker(
    cluster: SignalCluster,
    onTap: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scale by animateFloatAsState(
        targetValue = 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy)
    )

    Box(
        modifier = modifier
            .scale(scale)
            .size((40 + cluster.signalCount * 2).dp)
            .clip(CircleShape)
            .background(getClusterColor(cluster.signalCount))
            .border(2.dp, Color.White, CircleShape)
            .clickable { onTap() },
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = cluster.signalCount.toString(),
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 12.sp
        )
    }
}

private fun getClusterColor(count: Int): Color {
    return when {
        count < 5 -> Color.Blue
        count < 10 -> Color.Green
        count < 20 -> Color(0xFFFFA500) // Orange
        else -> Color.Red
    }
}

private fun calculateOpacity(density: Int, weight: Double): Float {
    val normalizedDensity = min(density / 10.0, 1.0)
    val normalizedWeight = min(weight / 5.0, 1.0)
    return max(normalizedDensity * normalizedWeight, 0.1).toFloat()
}

/**
 * 지도 레전드 위젯
 */
@Composable
fun MapLegend(
    viewMode: MapViewMode,
    densityPoints: List<DensityPoint>? = null,
    clusters: List<SignalCluster>? = null,
    modifier: Modifier = Modifier
) {
    AnimatedVisibility(
        visible = viewMode != MapViewMode.NORMAL,
        enter = slideInVertically() + fadeIn(),
        exit = slideOutVertically() + fadeOut(),
        modifier = modifier
    ) {
        Card(
            modifier = Modifier.padding(16.dp),
            shape = RoundedCornerShape(8.dp),
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
        ) {
            Column(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = getLegendTitle(viewMode),
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )

                when (viewMode) {
                    MapViewMode.DENSITY -> DensityLegendItems()
                    MapViewMode.CLUSTER -> ClusterLegendItems()
                    else -> {
                        Text(
                            text = "기본 마커 표시",
                            fontSize = 12.sp
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DensityLegendItems() {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        LegendItem(Color.Blue.copy(alpha = 0.3f), "낮음 (1-2개)")
        LegendItem(Color.Blue.copy(alpha = 0.6f), "보통 (3-5개)")
        LegendItem(Color.Blue.copy(alpha = 0.9f), "높음 (6개 이상)")
    }
}

@Composable
private fun ClusterLegendItems() {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        LegendItem(Color.Blue, "소규모 (2-4개)")
        LegendItem(Color.Green, "중간 (5-9개)")
        LegendItem(Color(0xFFFFA500), "대규모 (10-19개)")
        LegendItem(Color.Red, "초대규모 (20개 이상)")
    }
}

@Composable
private fun LegendItem(
    color: Color,
    label: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .clip(CircleShape)
                .background(color)
        )
        Text(
            text = label,
            fontSize = 12.sp
        )
    }
}

private fun getLegendTitle(viewMode: MapViewMode): String {
    return when (viewMode) {
        MapViewMode.DENSITY -> "밀도 범례"
        MapViewMode.CLUSTER -> "클러스터 범례"
        else -> "일반 지도"
    }
}

/**
 * 지도 성능 모니터 위젯
 */
@Composable
fun MapPerformanceMonitor(
    signalCount: Int,
    clusterCount: Int,
    isLoading: Boolean,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = Color.Black.copy(alpha = 0.7f),
            contentColor = Color.White
        ),
        shape = RoundedCornerShape(4.dp)
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = "Signals: $signalCount",
                fontSize = 10.sp
            )

            if (clusterCount > 0) {
                Text(
                    text = "Clusters: $clusterCount",
                    fontSize = 10.sp
                )
            }

            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(12.dp),
                    strokeWidth = 1.dp,
                    color = Color.White
                )
            }
        }
    }
}