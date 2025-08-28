import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';
import 'dart:async';

// Signal related imports
import '../../signal/data/models/signal_model.dart';
import '../../signal/data/services/websocket_service.dart';
import '../../signal/presentation/widgets/signal_detail_sheet.dart';

// Core services and widgets
import '../../../core/services/location_service.dart';
import '../../../core/widgets/location_permission_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late GoogleMapController _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  int _currentIndex = 0;
  WebSocketService? _webSocketService;
  LocationService? _locationService;
  List<Widget> _pages = [];
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLocationService();
    _initializeWebSocket();
    _initializePages();
  }

  void _initializePages() {
    _pages = [
      MapView(
        currentPosition: _currentPosition,
        onLocationChanged: _onLocationChanged,
      ),
      const SignalListView(),
      const ChatListView(),
      const ProfileView(),
    ];
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService();
    // TODO: 실제 토큰으로 연결
    // _webSocketService!.connect('user_token_here');
  }

  void _initializeLocationService() {
    _locationService = LocationService();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    try {
      final result = await _locationService!.requestPermission();
      
      if (result == LocationPermissionResult.granted) {
        await _startLocationTracking();
      } else {
        await _showLocationPermissionDialog(result);
      }
    } catch (e) {
      debugPrint('위치 권한 오류: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    // 현재 위치 한번 가져오기
    final currentPosition = await _locationService!.getCurrentPosition();
    if (currentPosition != null) {
      setState(() {
        _currentPosition = currentPosition;
      });
      _initializePages();
    }

    // 위치 추적 시작
    final trackingStarted = await _locationService!.startTracking(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    if (trackingStarted) {
      _locationSubscription = _locationService!.positionStream.listen(
        (position) {
          setState(() {
            _currentPosition = position;
          });
          _onLocationChanged(position.latitude, position.longitude);
        },
        onError: (error) {
          debugPrint('위치 추적 오류: $error');
        },
      );
    }
  }

  Future<void> _showLocationPermissionDialog(LocationPermissionResult result) async {
    final granted = await LocationPermissionBottomSheet.show(context, result);
    
    if (granted == true) {
      // 권한이 허용되었거나 설정에서 돌아왔을 때 다시 시도
      await _requestLocationPermission();
    }
  }

  void _onLocationChanged(double lat, double lon) {
    // WebSocket으로 위치 업데이트 전송
    _webSocketService?.updateLocation(lat, lon, 3000);
  }

  @override
  void dispose() {
    _webSocketService?.disconnect();
    _locationSubscription?.cancel();
    _locationService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.signal_cellular_alt),
            label: '시그널',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                // 시그널 생성 페이지로 이동
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class MapView extends StatefulWidget {
  final Position? currentPosition;
  final Function(double, double) onLocationChanged;

  const MapView({
    super.key,
    this.currentPosition,
    required this.onLocationChanged,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<SignalModel> _signals = [];
  Timer? _locationUpdateTimer;
  double _currentRadius = 3000; // 3km 기본 반경
  final StreamController<List<SignalModel>> _signalsController = 
      StreamController<List<SignalModel>>.broadcast();

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _signalsController.close();
    super.dispose();
  }

  void _startLocationUpdates() {
    // 주기적으로 현재 위치 기반 시그널 업데이트
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (widget.currentPosition != null) {
        _loadNearbySignals(
          widget.currentPosition!.latitude,
          widget.currentPosition!.longitude,
        );
      }
    });
  }

  Future<void> _loadNearbySignals(double lat, double lon) async {
    try {
      // TODO: API 호출로 근처 시그널 조회
      // final signals = await signalApiService.getNearbySignals(lat, lon, _currentRadius);
      
      // 임시 데이터
      final signals = _generateMockSignals(lat, lon);
      
      setState(() {
        _signals = signals;
        _updateMarkers();
      });

      _signalsController.add(signals);
      widget.onLocationChanged(lat, lon);
    } catch (e) {
      print('시그널 로드 실패: $e');
    }
  }

  List<SignalModel> _generateMockSignals(double centerLat, double centerLon) {
    // 임시 목업 데이터 - 실제로는 API에서 받아옴
    return [
      SignalModel(
        id: 1,
        title: '한강 러닝',
        description: '한강에서 같이 뛰실 분들',
        category: '운동',
        latitude: centerLat + 0.003,
        longitude: centerLon + 0.002,
        address: '서울시 용산구 한강대로',
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
        expiresAt: DateTime.now().add(const Duration(hours: 4)),
        maxParticipants: 6,
        currentParticipants: 3,
        allowInstantJoin: true,
        requireApproval: false,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        creator: const UserModel(
          id: 1,
          email: 'test@example.com',
          username: '러닝러버',
          isActive: true,
        ),
        distance: 320,
      ),
      SignalModel(
        id: 2,
        title: '카페 스터디',
        description: '조용한 카페에서 스터디',
        category: '스터디',
        latitude: centerLat - 0.002,
        longitude: centerLon + 0.001,
        address: '서울시 강남구',
        scheduledAt: DateTime.now().add(const Duration(minutes: 30)),
        expiresAt: DateTime.now().add(const Duration(hours: 3)),
        maxParticipants: 4,
        currentParticipants: 2,
        allowInstantJoin: false,
        requireApproval: true,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        creator: const UserModel(
          id: 2,
          email: 'study@example.com',
          username: '스터디메이트',
          isActive: true,
        ),
        distance: 150,
      ),
    ];
  }

  void _updateMarkers() {
    _markers = _signals.map((signal) {
      return Marker(
        markerId: MarkerId(signal.id.toString()),
        position: LatLng(signal.latitude, signal.longitude),
        infoWindow: InfoWindow(
          title: signal.title,
          snippet: '${signal.currentParticipants}/${signal.maxParticipants}명 · ${signal.distance?.round()}m',
        ),
        icon: _getMarkerIcon(signal.category),
        onTap: () => _showSignalDetails(signal),
      );
    }).toSet();
  }

  BitmapDescriptor _getMarkerIcon(String category) {
    // 카테고리별 마커 아이콘 (현재는 기본 아이콘 사용)
    return BitmapDescriptor.defaultMarkerWithHue(
      category == '운동' ? BitmapDescriptor.hueRed :
      category == '스터디' ? BitmapDescriptor.hueBlue :
      BitmapDescriptor.hueGreen,
    );
  }

  void _showSignalDetails(SignalModel signal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SignalDetailSheet(signal: signal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 상단 검색바
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          '어떤 활동을 찾고 계세요?',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    _showFilterDialog();
                  },
                  icon: const Icon(Icons.filter_list),
                ),
              ],
            ),
          ),
          
          // 지도
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.currentPosition != null 
                        ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
                        : const LatLng(37.5665, 126.9780), // 서울시청
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (widget.currentPosition != null) {
                      _loadNearbySignals(
                        widget.currentPosition!.latitude,
                        widget.currentPosition!.longitude,
                      );
                    }
                  },
                  onCameraMove: (position) {
                    // 지도 이동 시 해당 위치의 시그널 로드
                    _loadNearbySignals(
                      position.target.latitude,
                      position.target.longitude,
                    );
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('search_radius'),
                      center: widget.currentPosition != null 
                          ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
                          : const LatLng(37.5665, 126.9780),
                      radius: _currentRadius,
                      fillColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      strokeColor: Theme.of(context).primaryColor,
                      strokeWidth: 2,
                    ),
                  },
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('필터 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('검색 반경: ${(_currentRadius / 1000).toStringAsFixed(1)}km'),
            Slider(
              value: _currentRadius,
              min: 500,
              max: 10000,
              divisions: 19,
              onChanged: (value) {
                setState(() {
                  _currentRadius = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.currentPosition != null) {
                _loadNearbySignals(
                  widget.currentPosition!.latitude,
                  widget.currentPosition!.longitude,
                );
              }
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }
}

class SignalListView extends StatelessWidget {
  const SignalListView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('시그널 목록'),
    );
  }
}

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('채팅 목록'),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('프로필'),
    );
  }
}