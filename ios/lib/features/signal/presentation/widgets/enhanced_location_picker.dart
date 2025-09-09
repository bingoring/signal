import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';

class EnhancedLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final String? initialPlaceName;
  final Function(LatLng location, String address, String? placeName) onLocationSelected;
  final bool showSearchBar;
  final bool showCurrentLocationButton;
  final double initialZoom;

  const EnhancedLocationPicker({
    super.key,
    this.initialLocation,
    this.initialAddress,
    this.initialPlaceName,
    required this.onLocationSelected,
    this.showSearchBar = true,
    this.showCurrentLocationButton = true,
    this.initialZoom = 16.0,
  });

  @override
  State<EnhancedLocationPicker> createState() => _EnhancedLocationPickerState();
}

class _EnhancedLocationPickerState extends State<EnhancedLocationPicker>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // 서울 중심부를 기본 위치로 설정
  LatLng _currentLocation = const LatLng(37.5665, 126.9780);
  String _currentAddress = '';
  String? _currentPlaceName;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isGettingAddress = false;
  List<LocationSearchResult> _searchResults = [];

  late AnimationController _markerAnimationController;
  late AnimationController _searchAnimationController;
  late Animation<double> _markerAnimation;
  late Animation<double> _searchSlideAnimation;

  final Set<Marker> _markers = {};

  // 한국 영역 경계 (대략적)
  static const LatLngBounds koreaBounds = LatLngBounds(
    southwest: LatLng(33.0, 124.0), // 제주도 남서쪽
    northeast: LatLng(38.9, 131.9), // 동해 북동쪽
  );

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeLocation();
  }

  void _setupAnimations() {
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _markerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _markerAnimationController,
      curve: Curves.elasticOut,
    ));

    _searchSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOut,
    ));
  }

  void _initializeLocation() {
    if (widget.initialLocation != null) {
      _currentLocation = widget.initialLocation!;
      _currentAddress = widget.initialAddress ?? '';
      _currentPlaceName = widget.initialPlaceName;
      _updateMarker();
      setState(() {
        _isLoading = false;
      });
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _markerAnimationController.dispose();
    _searchAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      
      // 한국 경계 내에 있는지 확인
      if (_isInKoreaBounds(latLng)) {
        await _updateLocationAndAddress(latLng);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, widget.initialZoom),
        );
      } else {
        // 한국 외부인 경우 서울로 설정
        await _updateLocationAndAddress(_currentLocation);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showLocationError();
      await _updateLocationAndAddress(_currentLocation);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isInKoreaBounds(LatLng location) {
    return location.latitude >= koreaBounds.southwest.latitude &&
           location.latitude <= koreaBounds.northeast.latitude &&
           location.longitude >= koreaBounds.southwest.longitude &&
           location.longitude <= koreaBounds.northeast.longitude;
  }

  Future<void> _updateLocationAndAddress(LatLng latLng) async {
    if (!_isInKoreaBounds(latLng)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('한국 내의 위치를 선택해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _currentLocation = latLng;
      _isGettingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
        localeIdentifier: 'ko_KR',
      );

      if (placemarks.isNotEmpty && mounted) {
        final placemark = placemarks.first;
        
        // 한국 주소 형식으로 포매팅
        final address = _formatKoreanAddress(placemark);
        final placeName = _extractPlaceName(placemark);

        setState(() {
          _currentAddress = address;
          _currentPlaceName = placeName;
          _isGettingAddress = false;
        });

        widget.onLocationSelected(_currentLocation, _currentAddress, _currentPlaceName);
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      setState(() {
        _currentAddress = '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
        _currentPlaceName = null;
        _isGettingAddress = false;
      });
      widget.onLocationSelected(_currentLocation, _currentAddress, _currentPlaceName);
    }

    _updateMarker();
  }

  String _formatKoreanAddress(Placemark placemark) {
    final parts = <String>[];
    
    if (placemark.administrativeArea != null) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.locality != null) {
      parts.add(placemark.locality!);
    }
    if (placemark.subLocality != null) {
      parts.add(placemark.subLocality!);
    }
    if (placemark.thoroughfare != null) {
      parts.add(placemark.thoroughfare!);
    }
    if (placemark.subThoroughfare != null) {
      parts.add(placemark.subThoroughfare!);
    }

    return parts.join(' ').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _extractPlaceName(Placemark placemark) {
    return placemark.name != null && placemark.name!.isNotEmpty
        ? placemark.name!
        : placemark.subThoroughfare;
  }

  void _updateMarker() {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _currentLocation,
          infoWindow: InfoWindow(
            title: _currentPlaceName ?? '선택된 위치',
            snippet: _currentAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
    
    _markerAnimationController.reset();
    _markerAnimationController.forward();
    HapticFeedback.lightImpact();
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // 한국 위치 검색을 위해 한국어 쿼리에 "대한민국" 추가
      String searchQuery = query.trim();
      if (!searchQuery.contains('대한민국') && !searchQuery.contains('한국')) {
        searchQuery += ', 대한민국';
      }

      List<Location> locations = await locationFromAddress(searchQuery);

      // 한국 경계 내의 결과만 필터링
      final filteredLocations = locations.where((location) {
        return _isInKoreaBounds(LatLng(location.latitude, location.longitude));
      }).toList();

      final results = <LocationSearchResult>[];
      for (final location in filteredLocations.take(5)) {
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
            localeIdentifier: 'ko_KR',
          );
          
          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            results.add(LocationSearchResult(
              location: LatLng(location.latitude, location.longitude),
              address: _formatKoreanAddress(placemark),
              placeName: _extractPlaceName(placemark),
            ));
          }
        } catch (e) {
          // 개별 위치 정보 실패는 무시
          continue;
        }
      }

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _searchResults = [];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('검색 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(LocationSearchResult result) async {
    await _updateLocationAndAddress(result.location);

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(result.location, widget.initialZoom),
    );

    setState(() {
      _searchResults = [];
    });

    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한이 필요합니다'),
        content: const Text('현재 위치를 사용하려면 위치 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showLocationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('위치 정보를 가져올 수 없습니다.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          if (widget.showSearchBar) _buildSearchSection(),
          Expanded(child: _buildMap()),
          _buildLocationInfo(),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: '장소명이나 주소를 검색하세요',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchController.text.isNotEmpty || _isSearching
                    ? IconButton(
                        onPressed: _isSearching ? null : () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                        icon: _isSearching
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : const Icon(Icons.clear),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onSubmitted: _searchLocation,
              onChanged: (value) {
                if (value.isEmpty) {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
          ),
          
          // Search Results
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      result.placeName ?? '위치',
                      style: theme.textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      result.address,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => _selectSearchResult(result),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '지도를 로딩 중입니다...',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation,
                      zoom: widget.initialZoom,
                    ),
                    markers: _markers,
                    onTap: _updateLocationAndAddress,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: true,
                    buildingsEnabled: true,
                    trafficEnabled: false,
                  ),
            
            // Custom controls
            if (!_isLoading) ...[
              // Current location button
              if (widget.showCurrentLocationButton)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: IconButton(
                        onPressed: _getCurrentLocation,
                        icon: Icon(
                          Icons.my_location,
                          color: theme.colorScheme.primary,
                        ),
                        tooltip: '현재 위치로 이동',
                      ),
                    ),
                  ),
                ),
              
              // Loading overlay for address
              if (_isGettingAddress)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '주소를 확인하는 중...',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.location_on,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '선택된 위치',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                if (_currentPlaceName != null) ...[
                  Text(
                    _currentPlaceName!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_currentAddress.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _currentAddress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ] else ...[
                  Text(
                    _currentAddress.isNotEmpty ? _currentAddress : '위치 정보를 가져오는 중...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LocationSearchResult {
  final LatLng location;
  final String address;
  final String? placeName;

  LocationSearchResult({
    required this.location,
    required this.address,
    this.placeName,
  });
}