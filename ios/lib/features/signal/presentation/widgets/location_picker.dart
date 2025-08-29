import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPicker extends StatefulWidget {
  final LatLng? selectedLocation;
  final String? selectedAddress;
  final Function(LatLng, String) onLocationSelected;

  const LocationPicker({
    Key? key,
    this.selectedLocation,
    this.selectedAddress,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  
  LatLng _currentLocation = const LatLng(37.5665, 126.9780); // 서울 기본 위치
  String _currentAddress = '';
  bool _isLoading = true;
  bool _isSearching = false;
  List<Location> _searchResults = [];
  
  late AnimationController _markerAnimationController;
  late Animation<double> _markerAnimation;
  
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _markerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _markerAnimationController,
      curve: Curves.elasticOut,
    ));

    if (widget.selectedLocation != null) {
      _currentLocation = widget.selectedLocation!;
      _currentAddress = widget.selectedAddress ?? '';
      _updateMarker();
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _markerAnimationController.dispose();
    _searchController.dispose();
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
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(position.latitude, position.longitude);
      await _updateLocationAndAddress(latLng);
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16.0),
      );
    } catch (e) {
      print('Error getting location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateLocationAndAddress(LatLng latLng) async {
    setState(() {
      _currentLocation = latLng;
    });
    
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = '${placemark.administrativeArea ?? ''} '
            '${placemark.locality ?? ''} '
            '${placemark.thoroughfare ?? ''} '
            '${placemark.subThoroughfare ?? ''}'
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');
        
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    _updateMarker();
    widget.onLocationSelected(_currentLocation, _currentAddress);
  }

  void _updateMarker() {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _currentLocation,
          infoWindow: InfoWindow(
            title: '선택된 위치',
            snippet: _currentAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
    _markerAnimationController.reset();
    _markerAnimationController.forward();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      List<Location> locations = await locationFromAddress(
        '$query, 대한민국',
      );

      setState(() {
        _searchResults = locations.take(5).toList();
      });
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(Location location) async {
    final latLng = LatLng(location.latitude, location.longitude);
    await _updateLocationAndAddress(latLng);
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(latLng, 16.0),
    );
    
    setState(() {
      _searchResults = [];
    });
    
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        if (_searchResults.isNotEmpty) _buildSearchResults(),
        Expanded(child: _buildMap()),
        _buildLocationInfo(),
      ],
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '만날 장소를 선택해주세요',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '지도에서 위치를 선택하거나 검색해보세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '장소명, 주소 검색',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
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
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _searchResults.map((location) {
          return ListTile(
            leading: const Icon(Icons.location_on),
            title: Text('${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}'),
            onTap: () => _selectSearchResult(location),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                initialCameraPosition: CameraPosition(
                  target: _currentLocation,
                  zoom: 16.0,
                ),
                markers: _markers,
                onTap: _updateLocationAndAddress,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '선택된 위치',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentAddress.isNotEmpty ? _currentAddress : '위치 정보를 가져오는 중...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}