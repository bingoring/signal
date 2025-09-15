import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/models/signal.dart';
import '../../data/services/enhanced_geographic_service.dart';
import '../../data/services/websocket_service.dart';
import '../../../core/services/location_service.dart';
import 'enhanced_map_state.dart';

@injectable
class EnhancedMapCubit extends Cubit<EnhancedMapState> {
  final EnhancedGeographicService _geographicService;
  final SignalWebSocketService _webSocketService;
  final LocationService _locationService;

  Timer? _searchDebounceTimer;
  Timer? _locationUpdateTimer;
  StreamSubscription? _webSocketSubscription;
  StreamSubscription? _locationSubscription;

  EnhancedMapCubit(
    this._geographicService,
    this._webSocketService,
    this._locationService,
  ) : super(const EnhancedMapState()) {
    _initializeServices();
  }

  /// 서비스 초기화
  void _initializeServices() {
    _connectWebSocket();
    _startLocationTracking();
  }

  /// WebSocket 연결
  void _connectWebSocket() {
    try {
      _webSocketService.connect();
      _webSocketSubscription = _webSocketService.messageStream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          emit(state.copyWith(error: 'WebSocket 연결 오류: $error'));
        },
      );
    } catch (e) {
      emit(state.copyWith(error: 'WebSocket 연결 실패: $e'));
    }
  }

  /// 위치 추적 시작
  void _startLocationTracking() {
    _locationSubscription = _locationService.positionStream.listen(
      (position) {
        emit(state.copyWith(
          userLatitude: position.latitude,
          userLongitude: position.longitude,
        ));
        
        // 자동 검색 업데이트
        if (state.signals.isEmpty || _shouldRefreshSignals()) {
          _performSearch();
        }
      },
      onError: (error) {
        emit(state.copyWith(error: '위치 추적 오류: $error'));
      },
    );
  }

  /// WebSocket 메시지 처리
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      final messageType = data['type'] as String?;

      switch (messageType) {
        case 'signal_created':
          _handleSignalCreated(data);
          break;
        case 'signal_updated':
          _handleSignalUpdated(data);
          break;
        case 'signal_deleted':
          _handleSignalDeleted(data);
          break;
      }
    } catch (e) {
      // 메시지 파싱 오류는 조용히 처리
    }
  }

  void _handleSignalCreated(Map<String, dynamic> data) {
    try {
      final signalData = data['signal'] as Map<String, dynamic>?;
      if (signalData != null) {
        final signal = SignalWithDistance.fromJson(signalData);
        final updatedSignals = List<SignalWithDistance>.from(state.signals)
          ..add(signal);

        emit(state.copyWith(
          signals: updatedSignals,
          lastUpdateTime: DateTime.now(),
        ));
      }
    } catch (e) {
      // 처리 오류 무시
    }
  }

  void _handleSignalUpdated(Map<String, dynamic> data) {
    try {
      final signalData = data['signal'] as Map<String, dynamic>?;
      if (signalData != null) {
        final updatedSignal = SignalWithDistance.fromJson(signalData);
        
        final signalIndex = state.signals.indexWhere(
          (s) => s.signal.id == updatedSignal.signal.id,
        );
        
        if (signalIndex >= 0) {
          final updatedSignals = List<SignalWithDistance>.from(state.signals);
          updatedSignals[signalIndex] = updatedSignal;
          
          emit(state.copyWith(
            signals: updatedSignals,
            selectedSignal: state.selectedSignal?.id == updatedSignal.signal.id 
              ? updatedSignal.signal 
              : state.selectedSignal,
            lastUpdateTime: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      // 처리 오류 무시
    }
  }

  void _handleSignalDeleted(Map<String, dynamic> data) {
    try {
      final signalId = data['signal_id'] as int?;
      if (signalId != null) {
        final updatedSignals = state.signals
            .where((s) => s.signal.id != signalId)
            .toList();
        
        emit(state.copyWith(
          signals: updatedSignals,
          selectedSignal: state.selectedSignal?.id == signalId 
            ? null 
            : state.selectedSignal,
          lastUpdateTime: DateTime.now(),
        ));
      }
    } catch (e) {
      // 처리 오류 무시
    }
  }

  /// 사용자 위치 업데이트
  Future<void> updateUserLocation(double latitude, double longitude) async {
    emit(state.copyWith(
      userLatitude: latitude,
      userLongitude: longitude,
    ));
    
    if (state.signals.isEmpty || _shouldRefreshSignals()) {
      await _performSearch();
    }
  }

  /// 검색 모드 설정
  void setSearchMode(MapSearchMode mode) {
    emit(state.copyWith(searchMode: mode));
    
    // 모드에 따른 초기화
    switch (mode) {
      case MapSearchMode.polygon:
        emit(state.copyWith(
          polygonPoints: [],
          isDrawingPolygon: true,
        ));
        break;
      case MapSearchMode.route:
        emit(state.copyWith(
          routeStartLat: null,
          routeStartLon: null,
          routeEndLat: null,
          routeEndLon: null,
          isSelectingRoute: true,
        ));
        break;
      default:
        emit(state.copyWith(
          polygonPoints: null,
          isDrawingPolygon: false,
          isSelectingRoute: false,
        ));
    }
  }

  /// 뷰 모드 설정
  void setViewMode(MapViewMode mode) {
    emit(state.copyWith(viewMode: mode));
    
    switch (mode) {
      case MapViewMode.density:
        _loadDensityData();
        break;
      case MapViewMode.cluster:
        _performClusterSearch();
        break;
      case MapViewMode.normal:
        emit(state.copyWith(
          densityPoints: null,
          clusters: null,
        ));
        break;
    }
  }

  /// 검색 반경 업데이트
  void updateSearchRadius(double radius) {
    emit(state.copyWith(searchRadius: radius));
    _debounceSearch();
  }

  /// 카테고리 필터 토글
  void toggleCategoryFilter(String category) {
    final categories = List<String>.from(state.selectedCategories);
    if (categories.contains(category)) {
      categories.remove(category);
    } else {
      categories.add(category);
    }
    
    emit(state.copyWith(selectedCategories: categories));
    _debounceSearch();
  }

  /// 시그널 검색
  Future<void> searchSignals(String query) async {
    emit(state.copyWith(
      searchQuery: query,
      isLoading: true,
    ));
    
    await _performSearch();
  }

  /// 다각형 점 추가
  void addPolygonPoint(double lat, double lon) {
    if (!state.isDrawingPolygon) return;
    
    final points = List<List<double>>.from(state.polygonPoints ?? []);
    points.add([lon, lat]); // PostGIS 형식: [lon, lat]
    
    emit(state.copyWith(polygonPoints: points));
    
    // 3개 이상의 점이 있으면 검색 수행
    if (points.length >= 3) {
      _performPolygonSearch();
    }
  }

  /// 다각형 완성
  void completePolygon() {
    if (state.isPolygonComplete) {
      emit(state.copyWith(isDrawingPolygon: false));
      _performPolygonSearch();
    }
  }

  /// 다각형 초기화
  void clearPolygon() {
    emit(state.copyWith(
      polygonPoints: [],
      isDrawingPolygon: true,
    ));
  }

  /// 경로 시작점 설정
  void setRouteStart(double lat, double lon) {
    emit(state.copyWith(
      routeStartLat: lat,
      routeStartLon: lon,
    ));
  }

  /// 경로 끝점 설정
  void setRouteEnd(double lat, double lon) {
    emit(state.copyWith(
      routeEndLat: lat,
      routeEndLon: lon,
      isSelectingRoute: false,
    ));
    
    if (state.isRouteComplete) {
      _performRouteSearch();
    }
  }

  /// 경로 버퍼 폭 설정
  void setRouteBufferWidth(double width) {
    emit(state.copyWith(routeBufferWidth: width));
    
    if (state.isRouteComplete) {
      _debounceSearch();
    }
  }

  /// 시간 필터 설정
  void toggleTodayOnly() {
    emit(state.copyWith(todayOnly: !state.todayOnly));
    _debounceSearch();
  }

  void setStartTime(TimeOfDay time) {
    emit(state.copyWith(startTime: time));
    _debounceSearch();
  }

  void setEndTime(TimeOfDay time) {
    emit(state.copyWith(endTime: time));
    _debounceSearch();
  }

  /// 거리 범위 설정
  void setDistanceRange(double min, double max) {
    emit(state.copyWith(
      minDistance: min,
      maxDistance: max,
    ));
    _debounceSearch();
  }

  /// 연령 범위 설정
  void setAgeRange(int min, int max) {
    emit(state.copyWith(
      minAge: min,
      maxAge: max,
    ));
    _debounceSearch();
  }

  /// 참여자 수 범위 설정
  void setParticipantRange(int? min, int? max) {
    emit(state.copyWith(
      minParticipants: min,
      maxParticipants: max,
    ));
    _debounceSearch();
  }

  /// 사용 가능한 시그널만 보기 토글
  void toggleAvailableOnly() {
    emit(state.copyWith(availableOnly: !state.availableOnly));
    _debounceSearch();
  }

  /// 줌 레벨 업데이트
  void updateZoomLevel(int zoomLevel) {
    emit(state.copyWith(currentZoomLevel: zoomLevel));
    
    // 줌 레벨에 따른 성능 최적화
    if (zoomLevel < 12 && state.signals.length > 200) {
      _performClusterSearch();
    }
  }

  /// 시그널 선택
  void selectSignal(Signal signal) {
    emit(state.copyWith(selectedSignal: signal));
  }

  /// 선택 해제
  void clearSelection() {
    emit(state.copyWith(selectedSignal: null));
  }

  /// 필터 초기화
  void clearFilters() {
    emit(state.copyWith(
      selectedCategories: [],
      searchRadius: 5000.0,
      todayOnly: false,
      startTime: null,
      endTime: null,
      minDistance: 0.0,
      maxDistance: 20000.0,
      minAge: 18,
      maxAge: 65,
      minParticipants: null,
      maxParticipants: null,
      availableOnly: false,
      searchQuery: '',
    ));
    _performSearch();
  }

  /// 필터 적용
  void applyFilters() {
    _performSearch();
  }

  /// 통계 로드
  Future<void> loadStatistics() async {
    if (!state.hasUserLocation) return;
    
    try {
      final statistics = await _geographicService.getLocationStatistics(
        latitude: state.userLatitude!,
        longitude: state.userLongitude!,
        radius: state.searchRadius,
      );
      
      emit(state.copyWith(statistics: statistics));
    } catch (e) {
      emit(state.copyWith(error: '통계 로드 실패: $e'));
    }
  }

  /// POI 분석 로드
  Future<void> loadPoiAnalysis() async {
    if (!state.hasUserLocation) return;
    
    try {
      emit(state.copyWith(isLoading: true));
      
      final analysis = await _geographicService.getPoiAnalysis(
        latitude: state.userLatitude!,
        longitude: state.userLongitude!,
        radius: state.searchRadius,
      );
      
      emit(state.copyWith(
        poiAnalysis: analysis,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'POI 분석 실패: $e',
      ));
    }
  }

  /// 수동 새로고침
  Future<void> refresh() async {
    await _performSearch();
  }

  /// 핫스팟 로드
  Future<void> loadHotspots() async {
    if (!state.hasUserLocation) return;
    
    try {
      final hotspots = await _geographicService.getHotspots(
        latitude: state.userLatitude!,
        longitude: state.userLongitude!,
        radius: state.searchRadius * 2, // 더 넓은 범위에서 핫스팟 검색
      );
      
      emit(state.copyWith(hotspots: hotspots));
    } catch (e) {
      emit(state.copyWith(error: '핫스팟 로드 실패: $e'));
    }
  }

  // Private Methods

  bool _shouldRefreshSignals() {
    if (state.lastUpdateTime == null) return true;
    
    final timeDiff = DateTime.now().difference(state.lastUpdateTime!);
    return timeDiff.inMinutes >= 2;
  }

  void _debounceSearch() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    if (!state.hasUserLocation) return;
    
    try {
      emit(state.copyWith(isLoading: true, error: null));
      
      switch (state.searchMode) {
        case MapSearchMode.radius:
          await _performRadiusSearch();
          break;
        case MapSearchMode.polygon:
          if (state.isPolygonComplete) {
            await _performPolygonSearch();
          }
          break;
        case MapSearchMode.route:
          if (state.isRouteComplete) {
            await _performRouteSearch();
          }
          break;
        case MapSearchMode.poi:
          await loadPoiAnalysis();
          break;
      }
      
      emit(state.copyWith(
        isLoading: false,
        lastUpdateTime: DateTime.now(),
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '검색 실패: $e',
      ));
    }
  }

  Future<void> _performRadiusSearch() async {
    final result = await _geographicService.advancedSearch(
      latitude: state.userLatitude!,
      longitude: state.userLongitude!,
      radius: state.searchRadius,
      categories: state.selectedCategories.isNotEmpty
        ? state.selectedCategories
        : null,
      searchType: 'radius',
      clustering: state.shouldEnableClustering
        ? ClusteringParams(
            enabled: true,
            distance: 500,
            minPoints: 3,
          )
        : null,
      density: state.viewMode == MapViewMode.density,
    );

    emit(state.copyWith(
      signals: result.signals,
      clusters: result.clusters,
      densityPoints: result.densityMap,
      statistics: result.statistics,
    ));
  }

  Future<void> _performPolygonSearch() async {
    if (state.polygonPoints == null || state.polygonPoints!.length < 3) return;
    
    final signals = await _geographicService.searchInPolygon(
      polygon: state.polygonPoints!,
      categories: state.selectedCategories.isNotEmpty 
        ? state.selectedCategories 
        : null,
    );
    
    emit(state.copyWith(signals: signals));
  }

  Future<void> _performRouteSearch() async {
    if (!state.isRouteComplete) return;
    
    final signals = await _geographicService.searchAlongRoute(
      startLat: state.routeStartLat!,
      startLon: state.routeStartLon!,
      endLat: state.routeEndLat!,
      endLon: state.routeEndLon!,
      bufferWidth: state.routeBufferWidth,
      categories: state.selectedCategories.isNotEmpty 
        ? state.selectedCategories 
        : null,
    );
    
    emit(state.copyWith(signals: signals));
  }

  Future<void> _performClusterSearch() async {
    if (!state.hasUserLocation) return;

    final result = await _geographicService.advancedSearch(
      latitude: state.userLatitude!,
      longitude: state.userLongitude!,
      radius: state.searchRadius,
      clustering: ClusteringParams(
        enabled: true,
        distance: _getClusterDistance(),
        minPoints: 2,
      ),
    );

    emit(state.copyWith(
      signals: result.signals,
      clusters: result.clusters,
    ));
  }

  Future<void> _loadDensityData() async {
    if (!state.hasUserLocation) return;
    
    try {
      final densityPoints = await _geographicService.getDensityMap(
        latitude: state.userLatitude!,
        longitude: state.userLongitude!,
        radius: state.searchRadius,
      );
      
      emit(state.copyWith(densityPoints: densityPoints));
    } catch (e) {
      emit(state.copyWith(error: '밀도 데이터 로드 실패: $e'));
    }
  }

  double _getClusterDistance() {
    // 줌 레벨에 따른 클러스터링 거리 조정
    switch (state.currentZoomLevel) {
      case < 10:
        return 2000;
      case < 12:
        return 1000;
      case < 14:
        return 500;
      default:
        return 200;
    }
  }

  @override
  Future<void> close() async {
    _searchDebounceTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _webSocketSubscription?.cancel();
    _locationSubscription?.cancel();
    _webSocketService.disconnect();
    _locationService.dispose();
    return super.close();
  }
}

/// 성능 최적화를 위한 확장
extension EnhancedMapCubitPerformance on EnhancedMapCubit {
  /// 메모리 최적화
  void optimizeMemory() {
    if (state.signals.length > state.maxMarkersToShow) {
      final optimizedSignals = state.signals
          .take(state.maxMarkersToShow)
          .toList();
      
      emit(state.copyWith(signals: optimizedSignals));
    }
  }
  
  /// 배터리 최적화 모드
  void enableBatteryOptimization() {
    emit(state.copyWith(
      enableClustering: true,
      maxMarkersToShow: 50,
    ));
  }
  
  /// 성능 모드 설정
  void setPerformanceMode(bool highPerformance) {
    if (highPerformance) {
      emit(state.copyWith(
        enableClustering: true,
        maxMarkersToShow: 200,
      ));
    } else {
      emit(state.copyWith(
        enableClustering: false,
        maxMarkersToShow: 50,
      ));
    }
  }
}