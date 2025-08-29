import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

import '../../data/models/signal_model.dart';
import '../../data/services/signal_api_service.dart';
import '../../data/services/websocket_service.dart';
import 'signal_map_state.dart';

class SignalMapCubit extends Cubit<SignalMapState> {
  final SignalApiService _signalService;
  final SignalWebSocketService _webSocketService;
  
  Timer? _locationUpdateTimer;
  StreamSubscription? _webSocketSubscription;
  
  SignalMapCubit(this._signalService, this._webSocketService) 
      : super(const SignalMapState()) {
    _connectWebSocket();
  }

  /// WebSocket 연결
  void _connectWebSocket() {
    try {
      _webSocketService.connect();
      _webSocketSubscription = _webSocketService.messageStream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          print('WebSocket 오류: $error');
          emit(state.copyWith(error: 'WebSocket 연결 오류가 발생했습니다'));
        },
      );
    } catch (e) {
      print('WebSocket 연결 실패: $e');
      emit(state.copyWith(error: 'WebSocket 연결에 실패했습니다'));
    }
  }

  /// WebSocket 메시지 처리
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      final messageType = data['type'] as String?;
      
      if (messageType == null) return;
      
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
        case 'signal_joined':
        case 'signal_left':
          _handleSignalParticipantChanged(data);
          break;
      }
    } catch (e) {
      print('WebSocket 메시지 파싱 오류: $e');
    }
  }

  void _handleSignalCreated(Map<String, dynamic> data) {
    try {
      final signalData = data['signal'] as Map<String, dynamic>?;
      if (signalData != null) {
        final signal = SignalWithDistance.fromJson(signalData);
        
        // 현재 지도 범위 내에 있는지 확인
        if (_isSignalInBounds(signal.signal)) {
          final updatedSignals = List<SignalWithDistance>.from(state.signals)
            ..add(signal);
          
          emit(state.copyWith(
            signals: updatedSignals,
            lastUpdateTime: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      print('새 시그널 처리 오류: $e');
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
      print('시그널 업데이트 처리 오류: $e');
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
      print('시그널 삭제 처리 오류: $e');
    }
  }

  void _handleSignalParticipantChanged(Map<String, dynamic> data) {
    try {
      final signalId = data['signal_id'] as int?;
      final currentParticipants = data['current_participants'] as int?;
      
      if (signalId != null && currentParticipants != null) {
        final signalIndex = state.signals.indexWhere(
          (s) => s.signal.id == signalId,
        );
        
        if (signalIndex >= 0) {
          final updatedSignals = List<SignalWithDistance>.from(state.signals);
          final signal = updatedSignals[signalIndex];
          
          // 참여자 수 업데이트
          updatedSignals[signalIndex] = SignalWithDistance(
            signal: signal.signal.copyWith(currentParticipants: currentParticipants),
            distance: signal.distance,
          );
          
          emit(state.copyWith(
            signals: updatedSignals,
            selectedSignal: state.selectedSignal?.id == signalId
              ? updatedSignals[signalIndex].signal
              : state.selectedSignal,
            lastUpdateTime: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      print('참여자 변경 처리 오류: $e');
    }
  }

  bool _isSignalInBounds(Signal signal) {
    if (state.mapBounds == null) return true;
    
    final bounds = state.mapBounds!;
    return signal.latitude >= bounds.minLat &&
           signal.latitude <= bounds.maxLat &&
           signal.longitude >= bounds.minLon &&
           signal.longitude <= bounds.maxLon;
  }

  /// 사용자 위치 업데이트
  Future<void> updateUserLocation(double latitude, double longitude) async {
    emit(state.copyWith(
      userLatitude: latitude,
      userLongitude: longitude,
    ));
    
    // WebSocket으로 위치 업데이트 전송
    _sendLocationUpdate(latitude, longitude);
    
    // 처음 위치를 얻었거나 일정 시간이 지났으면 근처 시그널 로드
    if (state.signals.isEmpty || _shouldRefreshSignals()) {
      await loadNearbySignals(latitude, longitude);
    }
  }

  void _sendLocationUpdate(double latitude, double longitude) {
    try {
      final message = {
        'type': 'location_update',
        'latitude': latitude,
        'longitude': longitude,
        'radius': state.searchRadius,
      };
      
      _webSocketService.sendMessage(jsonEncode(message));
    } catch (e) {
      print('위치 업데이트 전송 실패: $e');
    }
  }

  bool _shouldRefreshSignals() {
    if (state.lastUpdateTime == null) return true;
    
    final timeDiff = DateTime.now().difference(state.lastUpdateTime!);
    return timeDiff.inMinutes >= 2; // 2분마다 새로고침
  }

  /// 근처 시그널 로드
  Future<void> loadNearbySignals(double latitude, double longitude, {double? radius}) async {
    try {
      emit(state.copyWith(isLoading: true, error: null));
      
      final searchRadius = radius ?? state.searchRadius;
      final categories = state.selectedCategories.isNotEmpty 
        ? state.selectedCategories 
        : null;
      
      final signals = await _signalService.getNearbySignals(
        latitude: latitude,
        longitude: longitude,
        radius: searchRadius,
        categories: categories,
      );
      
      emit(state.copyWith(
        isLoading: false,
        signals: signals,
        lastUpdateTime: DateTime.now(),
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '근처 시그널을 불러오는데 실패했습니다: $e',
      ));
    }
  }

  /// 지도 범위 업데이트
  void updateMapBounds(double centerLat, double centerLon) {
    final radiusInDegrees = state.searchRadius / 111320.0; // 대략적인 변환
    
    final bounds = MapBounds(
      minLat: centerLat - radiusInDegrees,
      maxLat: centerLat + radiusInDegrees,
      minLon: centerLon - radiusInDegrees,
      maxLon: centerLon + radiusInDegrees,
    );
    
    emit(state.copyWith(mapBounds: bounds));
    
    // 범위가 크게 변경되었으면 새로운 시그널 로드
    _scheduleLocationUpdate(centerLat, centerLon);
  }

  void _scheduleLocationUpdate(double lat, double lon) {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer(const Duration(milliseconds: 500), () {
      loadNearbySignals(lat, lon);
    });
  }

  /// 시그널 선택
  void selectSignal(Signal signal) {
    emit(state.copyWith(selectedSignal: signal));
  }

  /// 선택 해제
  void clearSelection() {
    emit(state.copyWith(selectedSignal: null));
  }

  /// 검색 반경 변경
  void updateSearchRadius(double radius) {
    emit(state.copyWith(searchRadius: radius));
    
    if (state.userLatitude != null && state.userLongitude != null) {
      loadNearbySignals(state.userLatitude!, state.userLongitude!, radius: radius);
    }
  }

  /// 카테고리 필터 업데이트
  void updateCategoryFilter(List<String> categories) {
    emit(state.copyWith(selectedCategories: categories));
    
    if (state.userLatitude != null && state.userLongitude != null) {
      loadNearbySignals(state.userLatitude!, state.userLongitude!);
    }
  }

  /// 시그널 검색
  Future<void> searchSignals(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      emit(state.copyWith(isLoading: true, error: null));
      
      // 검색 API 호출 구현
      final results = await _signalService.searchSignals(
        query: query,
        latitude: state.userLatitude,
        longitude: state.userLongitude,
        radius: state.searchRadius,
      );
      
      emit(state.copyWith(
        isLoading: false,
        signals: results,
        searchQuery: query,
        lastUpdateTime: DateTime.now(),
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '검색에 실패했습니다: $e',
      ));
    }
  }

  /// 수동 새로고침
  Future<void> refreshNearbySignals() async {
    if (state.userLatitude != null && state.userLongitude != null) {
      await loadNearbySignals(state.userLatitude!, state.userLongitude!);
    }
  }

  /// 시그널 참여
  Future<bool> joinSignal(int signalId, {String? message}) async {
    try {
      await _signalService.joinSignal(signalId, message: message);
      
      // 로컬 상태 업데이트는 WebSocket으로 처리됨
      emit(state.copyWith(error: null));
      return true;
    } catch (e) {
      emit(state.copyWith(error: '시그널 참여에 실패했습니다: $e'));
      return false;
    }
  }

  /// 시그널 나가기
  Future<bool> leaveSignal(int signalId) async {
    try {
      await _signalService.leaveSignal(signalId);
      
      // 로컬 상태 업데이트는 WebSocket으로 처리됨
      emit(state.copyWith(error: null));
      return true;
    } catch (e) {
      emit(state.copyWith(error: '시그널 나가기에 실패했습니다: $e'));
      return false;
    }
  }

  @override
  Future<void> close() async {
    _locationUpdateTimer?.cancel();
    _webSocketSubscription?.cancel();
    _webSocketService.disconnect();
    return super.close();
  }
}

/// 지도 범위
class MapBounds {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  const MapBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapBounds &&
          runtimeType == other.runtimeType &&
          minLat == other.minLat &&
          maxLat == other.maxLat &&
          minLon == other.minLon &&
          maxLon == other.maxLon;

  @override
  int get hashCode =>
      minLat.hashCode ^ maxLat.hashCode ^ minLon.hashCode ^ maxLon.hashCode;
}