import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/services/enhanced_geographic_service.dart';
import '../cubit/enhanced_map_state.dart';

/// 지도 시각화 레이어 (밀도 맵, 클러스터, 핫스팟)
class MapVisualizationLayer {
  /// 밀도 맵을 위한 히트맵 오버레이 생성
  static Set<Polygon> createDensityHeatmap(
    List<DensityPoint> densityPoints, {
    double gridSize = 0.01,
    Color baseColor = Colors.blue,
  }) {
    final polygons = <Polygon>{};
    
    for (int i = 0; i < densityPoints.length; i++) {
      final point = densityPoints[i];
      final opacity = _calculateOpacity(point.density, point.weight);
      
      // 그리드 셀을 다각형으로 변환
      final polygon = Polygon(
        polygonId: PolygonId('density_$i'),
        points: _createGridCell(point.latitude, point.longitude, gridSize),
        fillColor: baseColor.withOpacity(opacity),
        strokeColor: baseColor.withOpacity(opacity * 0.7),
        strokeWidth: 1,
        consumeTapEvents: false,
      );
      
      polygons.add(polygon);
    }
    
    return polygons;
  }

  /// 클러스터 마커 생성
  static Set<Marker> createClusterMarkers(
    List<SignalCluster> clusters, {
    required Function(SignalCluster) onClusterTap,
  }) {
    final markers = <Marker>{};
    
    for (final cluster in clusters) {
      final marker = Marker(
        markerId: MarkerId('cluster_${cluster.id}'),
        position: LatLng(cluster.centerLat, cluster.centerLon),
        icon: _createClusterIcon(cluster.signalCount),
        onTap: () => onClusterTap(cluster),
        infoWindow: InfoWindow(
          title: '클러스터',
          snippet: '${cluster.signalCount}개 시그널',
        ),
      );
      
      markers.add(marker);
    }
    
    return markers;
  }

  /// 핫스팟 마커 생성
  static Set<Marker> createHotspotMarkers(
    List<Hotspot> hotspots, {
    required Function(Hotspot) onHotspotTap,
  }) {
    final markers = <Marker>{};
    
    for (final hotspot in hotspots) {
      final marker = Marker(
        markerId: MarkerId('hotspot_${hotspot.id}'),
        position: LatLng(hotspot.latitude, hotspot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () => onHotspotTap(hotspot),
        infoWindow: InfoWindow(
          title: '핫스팟: ${hotspot.name}',
          snippet: '인기 지역',
        ),
      );
      
      markers.add(marker);
    }
    
    return markers;
  }

  /// 다각형 검색 영역 표시
  static Set<Polygon> createPolygonSearchArea(
    List<List<double>> polygonPoints, {
    Color fillColor = Colors.blue,
    Color strokeColor = Colors.blue,
  }) {
    if (polygonPoints.length < 3) return {};
    
    final points = polygonPoints
        .map((point) => LatLng(point[1], point[0])) // [lon, lat] -> LatLng
        .toList();
    
    return {
      Polygon(
        polygonId: const PolygonId('search_polygon'),
        points: points,
        fillColor: fillColor.withOpacity(0.2),
        strokeColor: strokeColor,
        strokeWidth: 2,
        consumeTapEvents: false,
      ),
    };
  }

  /// 경로 검색 영역 표시
  static Set<Polyline> createRouteSearchArea(
    double startLat,
    double startLon,
    double endLat,
    double endLon, {
    double bufferWidth = 1000,
    Color color = Colors.green,
  }) {
    return {
      Polyline(
        polylineId: const PolylineId('search_route'),
        points: [
          LatLng(startLat, startLon),
          LatLng(endLat, endLon),
        ],
        color: color,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  /// 반경 검색 영역 표시
  static Set<Circle> createRadiusSearchArea(
    double centerLat,
    double centerLon,
    double radius, {
    Color fillColor = Colors.blue,
    Color strokeColor = Colors.blue,
  }) {
    return {
      Circle(
        circleId: const CircleId('search_radius'),
        center: LatLng(centerLat, centerLon),
        radius: radius,
        fillColor: fillColor.withOpacity(0.1),
        strokeColor: strokeColor,
        strokeWidth: 2,
      ),
    };
  }

  // Private Helper Methods

  static double _calculateOpacity(int density, double weight) {
    // 밀도와 가중치를 기반으로 투명도 계산
    final normalizedDensity = math.min(density / 10.0, 1.0);
    final normalizedWeight = math.min(weight / 5.0, 1.0);
    return math.max(normalizedDensity * normalizedWeight, 0.1);
  }

  static List<LatLng> _createGridCell(
    double centerLat,
    double centerLon,
    double gridSize,
  ) {
    final halfGrid = gridSize / 2;
    return [
      LatLng(centerLat - halfGrid, centerLon - halfGrid),
      LatLng(centerLat - halfGrid, centerLon + halfGrid),
      LatLng(centerLat + halfGrid, centerLon + halfGrid),
      LatLng(centerLat + halfGrid, centerLon - halfGrid),
    ];
  }

  static BitmapDescriptor _createClusterIcon(int count) {
    // 클러스터 크기에 따른 아이콘 선택
    if (count < 5) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    } else if (count < 10) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (count < 20) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }
}

/// 실시간 애니메이션을 위한 커스텀 위젯
class AnimatedMapOverlay extends StatefulWidget {
  final List<DensityPoint> densityPoints;
  final List<SignalCluster> clusters;
  final MapViewMode viewMode;
  final Function(SignalCluster) onClusterTap;

  const AnimatedMapOverlay({
    super.key,
    required this.densityPoints,
    required this.clusters,
    required this.viewMode,
    required this.onClusterTap,
  });

  @override
  State<AnimatedMapOverlay> createState() => _AnimatedMapOverlayState();
}

class _AnimatedMapOverlayState extends State<AnimatedMapOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(AnimatedMapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewMode != widget.viewMode) {
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _fadeController]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeController.value,
          child: _buildOverlayContent(),
        );
      },
    );
  }

  Widget _buildOverlayContent() {
    switch (widget.viewMode) {
      case MapViewMode.density:
        return _buildDensityOverlay();
      case MapViewMode.cluster:
        return _buildClusterOverlay();
      case MapViewMode.normal:
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDensityOverlay() {
    return Stack(
      children: widget.densityPoints.map((point) {
        return Positioned(
          left: point.longitude * 100, // 임시 좌표 변환
          top: point.latitude * 100,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(
                0.3 + (0.7 * _pulseController.value),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClusterOverlay() {
    return Stack(
      children: widget.clusters.map((cluster) {
        return Positioned(
          left: cluster.centerLon * 100, // 임시 좌표 변환
          top: cluster.centerLat * 100,
          child: GestureDetector(
            onTap: () => widget.onClusterTap(cluster),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 40 + (cluster.signalCount * 2),
              height: 40 + (cluster.signalCount * 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getClusterColor(cluster.signalCount),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${cluster.signalCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getClusterColor(int count) {
    if (count < 5) {
      return Colors.blue;
    } else if (count < 10) {
      return Colors.green;
    } else if (count < 20) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

/// 지도 레전드 위젯
class MapLegend extends StatelessWidget {
  final MapViewMode viewMode;
  final List<DensityPoint>? densityPoints;
  final List<SignalCluster>? clusters;

  const MapLegend({
    super.key,
    required this.viewMode,
    this.densityPoints,
    this.clusters,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getLegendTitle(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildLegendItems(),
          ],
        ),
      ),
    );
  }

  String _getLegendTitle() {
    switch (viewMode) {
      case MapViewMode.density:
        return '밀도 범례';
      case MapViewMode.cluster:
        return '클러스터 범례';
      case MapViewMode.normal:
      default:
        return '일반 지도';
    }
  }

  List<Widget> _buildLegendItems() {
    switch (viewMode) {
      case MapViewMode.density:
        return _buildDensityLegend();
      case MapViewMode.cluster:
        return _buildClusterLegend();
      case MapViewMode.normal:
      default:
        return [const Text('기본 마커 표시')];
    }
  }

  List<Widget> _buildDensityLegend() {
    return [
      _buildLegendItem(Colors.blue.withOpacity(0.3), '낮음 (1-2개)'),
      _buildLegendItem(Colors.blue.withOpacity(0.6), '보통 (3-5개)'),
      _buildLegendItem(Colors.blue.withOpacity(0.9), '높음 (6개 이상)'),
    ];
  }

  List<Widget> _buildClusterLegend() {
    return [
      _buildLegendItem(Colors.blue, '소규모 (2-4개)'),
      _buildLegendItem(Colors.green, '중간 (5-9개)'),
      _buildLegendItem(Colors.orange, '대규모 (10-19개)'),
      _buildLegendItem(Colors.red, '초대규모 (20개 이상)'),
    ];
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 지도 성능 모니터 위젯
class MapPerformanceMonitor extends StatefulWidget {
  final int signalCount;
  final int clusterCount;
  final bool isLoading;

  const MapPerformanceMonitor({
    super.key,
    required this.signalCount,
    required this.clusterCount,
    required this.isLoading,
  });

  @override
  State<MapPerformanceMonitor> createState() => _MapPerformanceMonitorState();
}

class _MapPerformanceMonitorState extends State<MapPerformanceMonitor> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Signals: ${widget.signalCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
            if (widget.clusterCount > 0)
              Text(
                'Clusters: ${widget.clusterCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            if (widget.isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}