import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamController<Position>? _positionController;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastKnownPosition;
  bool _isTracking = false;

  /// 위치 업데이트 스트림
  Stream<Position> get positionStream => 
      _positionController?.stream ?? const Stream.empty();

  /// 마지막 알려진 위치
  Position? get lastKnownPosition => _lastKnownPosition;

  /// 위치 추적 상태
  bool get isTracking => _isTracking;

  /// 위치 권한 요청
  Future<LocationPermissionResult> requestPermission() async {
    try {
      // 시스템 권한 확인
      LocationPermission systemPermission = await Geolocator.checkPermission();
      
      if (systemPermission == LocationPermission.denied) {
        systemPermission = await Geolocator.requestPermission();
      }

      if (systemPermission == LocationPermission.deniedForever) {
        return LocationPermissionResult.permanentlyDenied;
      }

      if (systemPermission == LocationPermission.denied) {
        return LocationPermissionResult.denied;
      }

      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionResult.serviceDisabled;
      }

      return LocationPermissionResult.granted;
    } catch (e) {
      print('위치 권한 요청 중 오류: $e');
      return LocationPermissionResult.error;
    }
  }

  /// 현재 위치 가져오기 (일회성)
  Future<Position?> getCurrentPosition() async {
    try {
      final permissionResult = await requestPermission();
      if (permissionResult != LocationPermissionResult.granted) {
        throw LocationPermissionException(permissionResult);
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      _lastKnownPosition = position;
      return position;
    } catch (e) {
      print('현재 위치 가져오기 실패: $e');
      
      // 캐시된 위치 사용
      if (_lastKnownPosition != null) {
        return _lastKnownPosition;
      }
      
      rethrow;
    }
  }

  /// 위치 추적 시작
  Future<bool> startTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // 최소 이동 거리 (미터)
    Duration timeInterval = const Duration(seconds: 5),
  }) async {
    if (_isTracking) {
      return true;
    }

    try {
      final permissionResult = await requestPermission();
      if (permissionResult != LocationPermissionResult.granted) {
        throw LocationPermissionException(permissionResult);
      }

      _positionController = StreamController<Position>.broadcast();
      _isTracking = true;

      // 위치 스트림 구독
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          timeLimit: const Duration(seconds: 30),
        ),
      ).listen(
        (position) {
          _lastKnownPosition = position;
          _positionController?.add(position);
        },
        onError: (error) {
          print('위치 추적 오류: $error');
          stopTracking();
        },
        cancelOnError: false,
      );

      // 초기 위치 가져오기
      try {
        final initialPosition = await getCurrentPosition();
        if (initialPosition != null) {
          _positionController?.add(initialPosition);
        }
      } catch (e) {
        print('초기 위치 가져오기 실패: $e');
      }

      return true;
    } catch (e) {
      print('위치 추적 시작 실패: $e');
      _isTracking = false;
      return false;
    }
  }

  /// 위치 추적 중지
  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _positionController?.close();
    _positionController = null;
  }

  /// 두 지점 간 거리 계산 (미터)
  double calculateDistance(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    return Geolocator.distanceBetween(startLat, startLon, endLat, endLon);
  }

  /// 설정 앱으로 이동
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// 앱 설정으로 이동
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// 위치 정확도 레벨별 설명 가져오기
  String getAccuracyDescription(LocationAccuracy accuracy) {
    switch (accuracy) {
      case LocationAccuracy.lowest:
        return '가장 낮음 (~3000m)';
      case LocationAccuracy.low:
        return '낮음 (~1000m)';
      case LocationAccuracy.medium:
        return '보통 (~100m)';
      case LocationAccuracy.high:
        return '높음 (~10m)';
      case LocationAccuracy.best:
        return '최고 (~3m)';
      case LocationAccuracy.bestForNavigation:
        return '내비게이션용';
      default:
        return '알 수 없음';
    }
  }

  /// 리소스 정리
  void dispose() {
    stopTracking();
  }
}

/// 위치 권한 결과
enum LocationPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  error,
}

/// 위치 권한 예외
class LocationPermissionException implements Exception {
  final LocationPermissionResult result;
  const LocationPermissionException(this.result);

  @override
  String toString() {
    switch (result) {
      case LocationPermissionResult.denied:
        return '위치 권한이 거부되었습니다.';
      case LocationPermissionResult.permanentlyDenied:
        return '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해 주세요.';
      case LocationPermissionResult.serviceDisabled:
        return '위치 서비스가 비활성화되어 있습니다. 설정에서 위치 서비스를 활성화해 주세요.';
      case LocationPermissionResult.error:
        return '위치 권한 확인 중 오류가 발생했습니다.';
      default:
        return '알 수 없는 위치 권한 오류가 발생했습니다.';
    }
  }

  String get userFriendlyMessage {
    switch (result) {
      case LocationPermissionResult.denied:
        return '정확한 시그널 정보를 위해 위치 권한이 필요합니다.';
      case LocationPermissionResult.permanentlyDenied:
        return '설정에서 위치 권한을 허용한 후 다시 시도해 주세요.';
      case LocationPermissionResult.serviceDisabled:
        return '기기의 위치 서비스를 활성화해 주세요.';
      case LocationPermissionResult.error:
        return '위치 권한을 확인할 수 없습니다. 다시 시도해 주세요.';
      default:
        return '위치 서비스를 사용할 수 없습니다.';
    }
  }
}