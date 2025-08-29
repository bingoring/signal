import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/services/location_service.dart';
import '../../data/models/signal_model.dart';
import '../cubit/signal_map_cubit.dart';
import '../cubit/signal_map_state.dart';
import '../widgets/signal_bottom_sheet.dart';
import '../widgets/signal_filter_sheet.dart';
import '../widgets/signal_create_fab.dart';

class SignalMapPage extends StatefulWidget {
  const SignalMapPage({super.key});

  @override
  State<SignalMapPage> createState() => _SignalMapPageState();
}

class _SignalMapPageState extends State<SignalMapPage> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  
  // 애니메이션 컨트롤러들
  late AnimationController _fabAnimationController;
  late AnimationController _filterAnimationController;
  
  // 마커 아이콘들
  BitmapDescriptor? _activeSignalIcon;
  BitmapDescriptor? _myLocationIcon;
  BitmapDescriptor? _selectedSignalIcon;

  // 현재 선택된 시그널
  Signal? _selectedSignal;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadCustomMarkers();
    _initializeLocation();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _filterAnimationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _activeSignalIcon = await _createCustomMarkerIcon(
        'assets/icons/signal_active.png',
        size: 120,
        borderColor: Colors.blue,
      );
      
      _selectedSignalIcon = await _createCustomMarkerIcon(
        'assets/icons/signal_selected.png',
        size: 140,
        borderColor: Colors.orange,
      );
      
      _myLocationIcon = await _createCustomMarkerIcon(
        'assets/icons/my_location.png',
        size: 100,
        borderColor: Colors.green,
      );
    } catch (e) {
      // 기본 마커 사용
      _activeSignalIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _selectedSignalIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      _myLocationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(
    String assetPath, {
    required int size,
    required Color borderColor,
  }) async {
    final Uint8List markerIcon = await _getBytesFromAsset(assetPath, size);
    return BitmapDescriptor.fromBytes(markerIcon);
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<void> _initializeLocation() async {
    final cubit = context.read<SignalMapCubit>();
    
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null && mounted) {
        await cubit.updateUserLocation(position.latitude, position.longitude);
        _moveToLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      if (mounted) {
        _showLocationError();
      }
    }
    
    // 위치 추적 시작
    _locationService.startTracking(distanceFilter: 50);
    _locationService.positionStream.listen((position) {
      if (mounted) {
        cubit.updateUserLocation(position.latitude, position.longitude);
      }
    });
  }

  void _moveToLocation(double lat, double lon, {double zoom = 15.0}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lon),
          zoom: zoom,
        ),
      ),
    );
  }

  void _showLocationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('위치 정보를 가져올 수 없습니다'),
        action: SnackBarAction(
          label: '설정',
          onPressed: LocationService().openLocationSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<SignalMapCubit, SignalMapState>(
        listener: (context, state) {
          if (state.selectedSignal != _selectedSignal) {
            setState(() {
              _selectedSignal = state.selectedSignal;
            });
            
            if (state.selectedSignal != null) {
              _showSignalBottomSheet(state.selectedSignal!);
            }
          }
          
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // 지도
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(37.5665, 126.9780), // 서울 중심
                  zoom: 11.0,
                ),
                markers: _buildMarkers(state),
                onCameraMove: (position) {
                  // 지도 이동 시 새로운 영역의 시그널 로드
                  context.read<SignalMapCubit>().updateMapBounds(
                    position.target.latitude,
                    position.target.longitude,
                  );
                },
                onTap: (position) {
                  context.read<SignalMapCubit>().clearSelection();
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
                tiltGesturesEnabled: false,
                mapType: MapType.normal,
              ),
              
              // 상단 검색바 및 필터
              SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 검색바
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: '위치나 시그널 검색...',
                              prefixIcon: Icon(Icons.search),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (query) {
                              // 검색 기능 구현
                              context.read<SignalMapCubit>().searchSignals(query);
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // 필터 버튼
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: state.hasActiveFilters 
                            ? Theme.of(context).primaryColor
                            : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.tune,
                            color: state.hasActiveFilters ? Colors.white : Colors.black54,
                          ),
                          onPressed: _showFilterSheet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 우하단 컨트롤 버튼들
              Positioned(
                right: 16,
                bottom: 100,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 내 위치로 이동
                    FloatingActionButton(
                      heroTag: 'my_location',
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black54,
                      onPressed: _moveToMyLocation,
                      child: const Icon(Icons.my_location),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 새로고침
                    FloatingActionButton(
                      heroTag: 'refresh',
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black54,
                      onPressed: () {
                        context.read<SignalMapCubit>().refreshNearbySignals();
                      },
                      child: state.isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              
              // 로딩 인디케이터
              if (state.isLoading && state.signals.isEmpty)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('근처 시그널을 찾고 있어요...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      
      // 시그널 생성 버튼
      floatingActionButton: SignalCreateFAB(
        animationController: _fabAnimationController,
        onPressed: _createNewSignal,
      ),
    );
  }

  Set<Marker> _buildMarkers(SignalMapState state) {
    final markers = <Marker>{};
    
    // 내 위치 마커
    if (state.userLatitude != null && state.userLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: LatLng(state.userLatitude!, state.userLongitude!),
          icon: _myLocationIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: '내 위치'),
        ),
      );
    }
    
    // 시그널 마커들
    for (final signal in state.signals) {
      final isSelected = state.selectedSignal?.id == signal.id;
      
      markers.add(
        Marker(
          markerId: MarkerId('signal_${signal.id}'),
          position: LatLng(signal.latitude, signal.longitude),
          icon: isSelected 
            ? (_selectedSignalIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange))
            : (_activeSignalIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
          onTap: () {
            context.read<SignalMapCubit>().selectSignal(signal);
          },
          infoWindow: InfoWindow(
            title: signal.title,
            snippet: '${signal.distance?.round() ?? 0}m · ${signal.currentParticipants}/${signal.maxParticipants}명',
          ),
        ),
      );
    }
    
    return markers;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // 다크 모드 지원
    if (Theme.of(context).brightness == Brightness.dark) {
      _setMapStyle();
    }
  }

  Future<void> _setMapStyle() async {
    try {
      final String style = await rootBundle.loadString('assets/map_styles/dark.json');
      _mapController?.setMapStyle(style);
    } catch (e) {
      print('지도 스타일 로드 실패: $e');
    }
  }

  void _moveToMyLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _moveToLocation(position.latitude, position.longitude, zoom: 17.0);
      }
    } catch (e) {
      _showLocationError();
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SignalFilterSheet(),
    );
  }

  void _showSignalBottomSheet(Signal signal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SignalBottomSheet(signal: signal),
    );
  }

  void _createNewSignal() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null && mounted) {
        Navigator.pushNamed(
          context,
          '/signal/create',
          arguments: {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        );
      }
    } catch (e) {
      _showLocationError();
    }
  }
}