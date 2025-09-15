import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/signal_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';

/// PostGIS 기반 고급 지리적 검색 서비스
class EnhancedGeographicService {
  final ApiClient _apiClient;

  EnhancedGeographicService(this._apiClient);

  /// 고급 지리적 검색
  Future<GeographicSearchResult> advancedSearch({
    required double latitude,
    required double longitude,
    double? radius,
    double? minRadius,
    double? maxRadius,
    List<String>? categories,
    String searchType = 'radius',
    List<List<double>>? polygon,
    RouteSearchParams? route,
    TimeFilterParams? timeFilter,
    bool density = false,
    ClusteringParams? clustering,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final requestBody = {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius ?? 5000,
        if (minRadius != null) 'min_radius': minRadius,
        if (maxRadius != null) 'max_radius': maxRadius,
        if (categories != null && categories.isNotEmpty) 'categories': categories,
        'search_type': searchType,
        if (polygon != null) 'polygon': polygon,
        if (route != null) 'route': route.toJson(),
        if (timeFilter != null) 'time_filter': timeFilter.toJson(),
        'density': density,
        if (clustering != null) 'clustering': clustering.toJson(),
        'page': page,
        'limit': limit,
      };

      final response = await _apiClient.post(
        '/geographic/search',
        requestBody,
      );

      return GeographicSearchResult.fromJson(response);
    } catch (e) {
      throw ApiException('고급 검색에 실패했습니다: $e');
    }
  }

  /// 밀도 맵 조회
  Future<List<DensityPoint>> getDensityMap({
    required double latitude,
    required double longitude,
    double radius = 5000,
    double gridSize = 0.01,
  }) async {
    try {
      final response = await _apiClient.get(
        '/geographic/density',
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'radius': radius.toString(),
          'grid_size': gridSize.toString(),
        },
      );

      final List<dynamic> densityData = response['data'] as List<dynamic>;
      return densityData
          .map((item) => DensityPoint.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException('밀도 맵 조회에 실패했습니다: $e');
    }
  }

  /// 핫스팟 분석
  Future<List<Hotspot>> getHotspots({
    required double latitude,
    required double longitude,
    double radius = 10000,
    int minSignals = 5,
  }) async {
    try {
      final response = await _apiClient.get(
        '/geographic/hotspots',
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'radius': radius.toString(),
          'min_signals': minSignals.toString(),
        },
      );

      final List<dynamic> hotspotsData = response['data'] as List<dynamic>;
      return hotspotsData
          .map((item) => Hotspot.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException('핫스팟 분석에 실패했습니다: $e');
    }
  }

  /// 다각형 영역 검색
  Future<List<SignalWithDistance>> searchInPolygon({
    required List<List<double>> polygon,
    List<String>? categories,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final requestBody = {
        'polygon': polygon,
        if (categories != null) 'categories': categories,
        'page': page,
        'limit': limit,
      };

      final response = await _apiClient.post(
        '/geographic/polygon',
        requestBody,
      );

      final List<dynamic> signalsData = response['data'] as List<dynamic>;
      return signalsData
          .map((item) => SignalWithDistance.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException('다각형 검색에 실패했습니다: $e');
    }
  }

  /// 경로 기반 검색
  Future<List<SignalWithDistance>> searchAlongRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    double bufferWidth = 1000,
    List<String>? categories,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final requestBody = {
        'start_lat': startLat,
        'start_lon': startLon,
        'end_lat': endLat,
        'end_lon': endLon,
        'buffer_width': bufferWidth,
        if (categories != null) 'categories': categories,
        'page': page,
        'limit': limit,
      };

      final response = await _apiClient.post(
        '/geographic/route',
        requestBody,
      );

      final List<dynamic> signalsData = response['data'] as List<dynamic>;
      return signalsData
          .map((item) => SignalWithDistance.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiException('경로 검색에 실패했습니다: $e');
    }
  }

  /// 지역 통계
  Future<GeographicStatistics> getLocationStatistics({
    required double latitude,
    required double longitude,
    double radius = 5000,
  }) async {
    try {
      final response = await _apiClient.get(
        '/geographic/statistics',
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'radius': radius.toString(),
        },
      );

      return GeographicStatistics.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiException('지역 통계 조회에 실패했습니다: $e');
    }
  }

  /// POI 분석
  Future<PoiAnalysisResult> getPoiAnalysis({
    required double latitude,
    required double longitude,
    double radius = 2000,
  }) async {
    try {
      final response = await _apiClient.get(
        '/geographic/poi-analysis',
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'radius': radius.toString(),
        },
      );

      return PoiAnalysisResult.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiException('POI 분석에 실패했습니다: $e');
    }
  }
}

/// 고급 검색 결과
class GeographicSearchResult {
  final List<SignalWithDistance> signals;
  final List<SignalCluster>? clusters;
  final List<DensityPoint>? densityMap;
  final GeographicStatistics statistics;

  GeographicSearchResult({
    required this.signals,
    this.clusters,
    this.densityMap,
    required this.statistics,
  });

  factory GeographicSearchResult.fromJson(Map<String, dynamic> json) {
    return GeographicSearchResult(
      signals: (json['signals'] as List<dynamic>?)
          ?.map((item) => SignalWithDistance.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      clusters: (json['clusters'] as List<dynamic>?)
          ?.map((item) => SignalCluster.fromJson(item as Map<String, dynamic>))
          .toList(),
      densityMap: (json['density_map'] as List<dynamic>?)
          ?.map((item) => DensityPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      statistics: GeographicStatistics.fromJson(json['statistics'] as Map<String, dynamic>),
    );
  }
}

/// 시그널 클러스터
class SignalCluster {
  final String id;
  final double centerLat;
  final double centerLon;
  final double radius;
  final int signalCount;
  final List<SignalWithDistance>? signals;
  final double avgDistance;

  SignalCluster({
    required this.id,
    required this.centerLat,
    required this.centerLon,
    required this.radius,
    required this.signalCount,
    this.signals,
    required this.avgDistance,
  });

  factory SignalCluster.fromJson(Map<String, dynamic> json) {
    return SignalCluster(
      id: json['id'] as String,
      centerLat: (json['center_lat'] as num).toDouble(),
      centerLon: (json['center_lon'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      signalCount: json['signal_count'] as int,
      signals: (json['signals'] as List<dynamic>?)
          ?.map((item) => SignalWithDistance.fromJson(item as Map<String, dynamic>))
          .toList(),
      avgDistance: (json['avg_distance'] as num).toDouble(),
    );
  }
}

/// 밀도 포인트
class DensityPoint {
  final double latitude;
  final double longitude;
  final int density;
  final double weight;

  DensityPoint({
    required this.latitude,
    required this.longitude,
    required this.density,
    required this.weight,
  });

  factory DensityPoint.fromJson(Map<String, dynamic> json) {
    return DensityPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      density: json['density'] as int,
      weight: (json['weight'] as num).toDouble(),
    );
  }
}

/// 지리적 통계
class GeographicStatistics {
  final int totalSignals;
  final double averageDistance;
  final Map<String, int> categories;
  final Map<String, int> timeDistribution;
  final List<RadialBucket> radialDistribution;

  GeographicStatistics({
    required this.totalSignals,
    required this.averageDistance,
    required this.categories,
    required this.timeDistribution,
    required this.radialDistribution,
  });

  factory GeographicStatistics.fromJson(Map<String, dynamic> json) {
    return GeographicStatistics(
      totalSignals: json['total_signals'] as int,
      averageDistance: (json['average_distance'] as num).toDouble(),
      categories: Map<String, int>.from(json['categories'] as Map),
      timeDistribution: Map<String, int>.from(json['time_distribution'] as Map),
      radialDistribution: (json['radial_distribution'] as List<dynamic>)
          .map((item) => RadialBucket.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 반경별 분포
class RadialBucket {
  final double minDistance;
  final double maxDistance;
  final int count;

  RadialBucket({
    required this.minDistance,
    required this.maxDistance,
    required this.count,
  });

  factory RadialBucket.fromJson(Map<String, dynamic> json) {
    return RadialBucket(
      minDistance: (json['min_distance'] as num).toDouble(),
      maxDistance: (json['max_distance'] as num).toDouble(),
      count: json['count'] as int,
    );
  }
}

/// 경로 검색 파라미터
class RouteSearchParams {
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final double bufferWidth;

  RouteSearchParams({
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    this.bufferWidth = 1000,
  });

  Map<String, dynamic> toJson() {
    return {
      'start_lat': startLat,
      'start_lon': startLon,
      'end_lat': endLat,
      'end_lon': endLon,
      'buffer_width': bufferWidth,
    };
  }
}

/// 시간 필터 파라미터
class TimeFilterParams {
  final DateTime? startTime;
  final DateTime? endTime;
  final List<String>? timeSlots;
  final List<int>? weekdays;

  TimeFilterParams({
    this.startTime,
    this.endTime,
    this.timeSlots,
    this.weekdays,
  });

  Map<String, dynamic> toJson() {
    return {
      if (startTime != null) 'start_time': startTime!.toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toIso8601String(),
      if (timeSlots != null) 'time_slots': timeSlots,
      if (weekdays != null) 'weekdays': weekdays,
    };
  }
}

/// 클러스터링 파라미터
class ClusteringParams {
  final bool enabled;
  final double distance;
  final int minPoints;

  ClusteringParams({
    this.enabled = true,
    this.distance = 500,
    this.minPoints = 2,
  });

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'distance': distance,
      'min_points': minPoints,
    };
  }
}

/// 핫스팟 정보
class Hotspot {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int signalCount;
  final String category;
  final double score;

  Hotspot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.signalCount,
    required this.category,
    required this.score,
  });

  factory Hotspot.fromJson(Map<String, dynamic> json) {
    return Hotspot(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      signalCount: json['signal_count'] as int,
      category: json['category'] as String,
      score: (json['score'] as num).toDouble(),
    );
  }
}

/// POI 분석 결과
class PoiAnalysisResult {
  final int totalSignals;
  final List<SignalCluster> clusters;
  final List<DensityPoint> densityPoints;
  final Map<String, int> categoryDistribution;
  final Map<String, int> timeDistribution;
  final double averageDistance;
  final Map<String, double> analysisCenter;
  final double analysisRadius;

  PoiAnalysisResult({
    required this.totalSignals,
    required this.clusters,
    required this.densityPoints,
    required this.categoryDistribution,
    required this.timeDistribution,
    required this.averageDistance,
    required this.analysisCenter,
    required this.analysisRadius,
  });

  factory PoiAnalysisResult.fromJson(Map<String, dynamic> json) {
    return PoiAnalysisResult(
      totalSignals: json['total_signals'] as int,
      clusters: (json['clusters'] as List<dynamic>)
          .map((item) => SignalCluster.fromJson(item as Map<String, dynamic>))
          .toList(),
      densityPoints: (json['density_points'] as List<dynamic>)
          .map((item) => DensityPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      categoryDistribution: Map<String, int>.from(json['category_distribution'] as Map),
      timeDistribution: Map<String, int>.from(json['time_distribution'] as Map),
      averageDistance: (json['average_distance'] as num).toDouble(),
      analysisCenter: Map<String, double>.from(json['analysis_center'] as Map),
      analysisRadius: (json['analysis_radius'] as num).toDouble(),
    );
  }
}