import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../data/models/signal.dart';
import '../../data/services/enhanced_geographic_service.dart';

enum MapSearchMode {
  radius,    // 반경 검색
  polygon,   // 다각형 검색
  route,     // 경로 검색
  poi,       // POI 기반 검색
}

enum MapViewMode {
  normal,    // 일반 마커
  density,   // 밀도 히트맵
  cluster,   // 클러스터링
}

enum DrawingMode {
  none,      // 그리기 없음
  polygon,   // 다각형 그리기
  route,     // 경로 설정
}

class EnhancedMapState extends Equatable {
  // 기본 지도 상태
  final bool isLoading;
  final String? error;
  final List<SignalWithDistance> signals;
  final Signal? selectedSignal;
  final double? userLatitude;
  final double? userLongitude;
  
  // 고급 검색 모드
  final MapSearchMode searchMode;
  final MapViewMode viewMode;
  final DrawingMode drawingMode;
  final String searchQuery;
  
  // 검색 파라미터
  final double searchRadius;
  final double? minRadius;
  final double? maxRadius;
  final List<String> selectedCategories;
  final List<String> selectedTimeSlots;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool todayOnly;
  final double minDistance;
  final double maxDistance;
  final int minAge;
  final int maxAge;
  final int? minParticipants;
  final int? maxParticipants;
  final bool availableOnly;
  
  // 다각형 검색
  final List<List<double>>? polygonPoints;
  final bool isDrawingPolygon;
  
  // 경로 검색
  final double? routeStartLat;
  final double? routeStartLon;
  final double? routeEndLat;
  final double? routeEndLon;
  final bool isSelectingRoute;
  final double routeBufferWidth;
  
  // 시각화 데이터
  final List<SignalCluster>? clusters;
  final List<DensityPoint>? densityPoints;
  final GeographicStatistics? statistics;
  final PoiAnalysisResult? poiAnalysis;
  final List<Hotspot>? hotspots;
  
  // 클러스터링 설정
  final bool clusteringEnabled;
  final double clusterDistance;
  final int minClusterPoints;
  
  // 밀도 맵 설정
  final bool densityMapEnabled;
  final double densityGridSize;
  
  // 성능 및 상태
  final DateTime? lastUpdateTime;
  final bool isCacheEnabled;
  final int totalSignalsFound;
  final int currentZoomLevel;
  final bool enableClustering;
  final int maxMarkersToShow;
  
  const EnhancedMapState({
    this.isLoading = false,
    this.error,
    this.signals = const [],
    this.selectedSignal,
    this.userLatitude,
    this.userLongitude,
    
    this.searchMode = MapSearchMode.radius,
    this.viewMode = MapViewMode.normal,
    this.drawingMode = DrawingMode.none,
    this.searchQuery = '',
    
    this.searchRadius = 5000,
    this.minRadius,
    this.maxRadius,
    this.selectedCategories = const [],
    this.selectedTimeSlots = const [],
    this.startTime,
    this.endTime,
    this.todayOnly = false,
    this.minDistance = 0.0,
    this.maxDistance = 20000.0,
    this.minAge = 18,
    this.maxAge = 65,
    this.minParticipants,
    this.maxParticipants,
    this.availableOnly = false,
    
    this.polygonPoints,
    this.isDrawingPolygon = false,
    
    this.routeStartLat,
    this.routeStartLon,
    this.routeEndLat,
    this.routeEndLon,
    this.isSelectingRoute = false,
    this.routeBufferWidth = 1000,
    
    this.clusters,
    this.densityPoints,
    this.statistics,
    this.poiAnalysis,
    this.hotspots,
    
    this.clusteringEnabled = false,
    this.clusterDistance = 500,
    this.minClusterPoints = 2,
    
    this.densityMapEnabled = false,
    this.densityGridSize = 0.01,
    
    this.lastUpdateTime,
    this.isCacheEnabled = true,
    this.totalSignalsFound = 0,
    this.currentZoomLevel = 12,
    this.enableClustering = false,
    this.maxMarkersToShow = 100,
  });

  EnhancedMapState copyWith({
    bool? isLoading,
    String? error,
    List<SignalWithDistance>? signals,
    Signal? selectedSignal,
    double? userLatitude,
    double? userLongitude,

    MapSearchMode? searchMode,
    MapViewMode? viewMode,
    DrawingMode? drawingMode,
    String? searchQuery,

    double? searchRadius,
    double? minRadius,
    double? maxRadius,
    List<String>? selectedCategories,
    List<String>? selectedTimeSlots,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? todayOnly,
    double? minDistance,
    double? maxDistance,
    int? minAge,
    int? maxAge,
    int? minParticipants,
    int? maxParticipants,
    bool? availableOnly,

    List<List<double>>? polygonPoints,
    bool? isDrawingPolygon,

    double? routeStartLat,
    double? routeStartLon,
    double? routeEndLat,
    double? routeEndLon,
    bool? isSelectingRoute,
    double? routeBufferWidth,

    List<SignalCluster>? clusters,
    List<DensityPoint>? densityPoints,
    GeographicStatistics? statistics,
    PoiAnalysisResult? poiAnalysis,
    List<Hotspot>? hotspots,

    bool? clusteringEnabled,
    double? clusterDistance,
    int? minClusterPoints,

    bool? densityMapEnabled,
    double? densityGridSize,

    DateTime? lastUpdateTime,
    bool? isCacheEnabled,
    int? totalSignalsFound,
    int? currentZoomLevel,
    bool? enableClustering,
    int? maxMarkersToShow,
  }) {
    return EnhancedMapState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      signals: signals ?? this.signals,
      selectedSignal: selectedSignal,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,

      searchMode: searchMode ?? this.searchMode,
      viewMode: viewMode ?? this.viewMode,
      drawingMode: drawingMode ?? this.drawingMode,
      searchQuery: searchQuery ?? this.searchQuery,

      searchRadius: searchRadius ?? this.searchRadius,
      minRadius: minRadius ?? this.minRadius,
      maxRadius: maxRadius ?? this.maxRadius,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedTimeSlots: selectedTimeSlots ?? this.selectedTimeSlots,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      todayOnly: todayOnly ?? this.todayOnly,
      minDistance: minDistance ?? this.minDistance,
      maxDistance: maxDistance ?? this.maxDistance,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      minParticipants: minParticipants ?? this.minParticipants,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      availableOnly: availableOnly ?? this.availableOnly,

      polygonPoints: polygonPoints ?? this.polygonPoints,
      isDrawingPolygon: isDrawingPolygon ?? this.isDrawingPolygon,

      routeStartLat: routeStartLat ?? this.routeStartLat,
      routeStartLon: routeStartLon ?? this.routeStartLon,
      routeEndLat: routeEndLat ?? this.routeEndLat,
      routeEndLon: routeEndLon ?? this.routeEndLon,
      isSelectingRoute: isSelectingRoute ?? this.isSelectingRoute,
      routeBufferWidth: routeBufferWidth ?? this.routeBufferWidth,

      clusters: clusters ?? this.clusters,
      densityPoints: densityPoints ?? this.densityPoints,
      statistics: statistics ?? this.statistics,
      poiAnalysis: poiAnalysis ?? this.poiAnalysis,
      hotspots: hotspots ?? this.hotspots,

      clusteringEnabled: clusteringEnabled ?? this.clusteringEnabled,
      clusterDistance: clusterDistance ?? this.clusterDistance,
      minClusterPoints: minClusterPoints ?? this.minClusterPoints,

      densityMapEnabled: densityMapEnabled ?? this.densityMapEnabled,
      densityGridSize: densityGridSize ?? this.densityGridSize,

      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      isCacheEnabled: isCacheEnabled ?? this.isCacheEnabled,
      totalSignalsFound: totalSignalsFound ?? this.totalSignalsFound,
      currentZoomLevel: currentZoomLevel ?? this.currentZoomLevel,
      enableClustering: enableClustering ?? this.enableClustering,
      maxMarkersToShow: maxMarkersToShow ?? this.maxMarkersToShow,
    );
  }

  // 편의 메서드들
  bool get hasActiveAdvancedFilters {
    return selectedCategories.isNotEmpty ||
           selectedTimeSlots.isNotEmpty ||
           startTime != null ||
           endTime != null ||
           minRadius != null ||
           maxRadius != null ||
           searchRadius != 5000;
  }

  bool get hasResults {
    return signals.isNotEmpty;
  }

  bool get isAdvancedSearchMode {
    return searchMode != MapSearchMode.radius;
  }

  bool get isAdvancedVisualizationMode {
    return viewMode != MapViewMode.normal;
  }

  bool get hasUserLocation {
    return userLatitude != null && userLongitude != null;
  }

  bool get canPerformSearch {
    return hasUserLocation;
  }

  bool get isPolygonComplete {
    return polygonPoints != null && polygonPoints!.length >= 3;
  }

  bool get isRouteComplete {
    return routeStartLat != null && routeStartLon != null &&
           routeEndLat != null && routeEndLon != null;
  }

  bool get shouldEnableClustering {
    return enableClustering || (signals.length > maxMarkersToShow);
  }

  String get searchModeDescription {
    switch (searchMode) {
      case MapSearchMode.radius:
        return '반경 ${(searchRadius / 1000).toStringAsFixed(1)}km 검색';
      case MapSearchMode.polygon:
        return isPolygonComplete ? '다각형 영역 검색' : '다각형 영역 설정 중';
      case MapSearchMode.route:
        return isRouteComplete ? '경로 기반 검색' : '경로 설정 중';
      case MapSearchMode.poi:
        return 'POI 기반 검색';
    }
  }

  String get visualizationModeDescription {
    switch (viewMode) {
      case MapViewMode.normal:
        return '일반 지도';
      case MapViewMode.density:
        return '밀도 히트맵';
      case MapViewMode.cluster:
        return '클러스터 보기';
    }
  }

  // 검색 결과 요약
  Map<String, dynamic> get searchSummary {
    return {
      'total_signals': totalSignalsFound,
      'visible_signals': signals.length,
      'search_mode': searchMode.toString().split('.').last,
      'visualization_mode': viewMode.toString().split('.').last,
      'has_clusters': clusters?.isNotEmpty ?? false,
      'has_density_data': densityPoints?.isNotEmpty ?? false,
      'search_radius_km': searchRadius / 1000,
      'has_filters': hasActiveAdvancedFilters,
    };
  }

  @override
  List<Object?> get props => [
        isLoading,
        error,
        signals,
        selectedSignal,
        userLatitude,
        userLongitude,
        searchMode,
        viewMode,
        drawingMode,
        searchQuery,
        searchRadius,
        minRadius,
        maxRadius,
        selectedCategories,
        selectedTimeSlots,
        startTime,
        endTime,
        todayOnly,
        minDistance,
        maxDistance,
        minAge,
        maxAge,
        minParticipants,
        maxParticipants,
        availableOnly,
        polygonPoints,
        isDrawingPolygon,
        routeStartLat,
        routeStartLon,
        routeEndLat,
        routeEndLon,
        isSelectingRoute,
        routeBufferWidth,
        clusters,
        densityPoints,
        statistics,
        poiAnalysis,
        hotspots,
        clusteringEnabled,
        clusterDistance,
        minClusterPoints,
        densityMapEnabled,
        densityGridSize,
        lastUpdateTime,
        isCacheEnabled,
        totalSignalsFound,
        currentZoomLevel,
        enableClustering,
        maxMarkersToShow,
      ];
}