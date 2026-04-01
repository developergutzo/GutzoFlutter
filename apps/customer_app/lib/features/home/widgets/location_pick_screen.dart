import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'location_search_screen.dart';
import 'add_address_detail_screen.dart';

class LocationPickScreen extends ConsumerStatefulWidget {
  final bool isAddingAddress;
  const LocationPickScreen({super.key, this.isAddingAddress = false});

  @override
  ConsumerState<LocationPickScreen> createState() => _LocationPickScreenState();
}

class _LocationPickScreenState extends ConsumerState<LocationPickScreen> {
  GoogleMapController? _mapController;
  LatLng? _userPosition; // User's real GPS position
  LatLng? _currentCenter; // Current map center
  DetailedAddress? _currentAddress;
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  // Threshold for "Current Location" (50 meters)
  static const double _nearThreshold = 50.0;

  // Branded "Silver" Map Style
  static const String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#f5f5f5" }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#616161" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#f5f5f5" }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#bdbdbd" }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      { "color": "#eeeeee" }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#757575" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      { "color": "#e8f6f1" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#1ba672" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      { "color": "#ffffff" }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#757575" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      { "color": "#dadada" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#616161" }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#9e9e9e" }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry",
    "stylers": [
      { "color": "#e5e5e5" }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [
      { "color": "#eeeeee" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      { "color": "#c9c9c9" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#9e9e9e" }
    ]
  }
]
''';

  @override
  void initState() {
    super.initState();
    final loc = ref.read(locationProvider).location;
    if (loc != null) {
      _userPosition = LatLng(loc.latitude, loc.longitude);
      _currentCenter = _userPosition;
      _resolveAddress(_currentCenter!);
    } else {
      _fetchInitialPosition();
    }
  }

  Future<void> _fetchInitialPosition() async {
    try {
      final loc = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _userPosition = LatLng(loc.latitude, loc.longitude);
          _currentCenter ??= _userPosition;
        });
        if (_currentCenter != null) _resolveAddress(_currentCenter!);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveAddress(LatLng position) async {
    setState(() => _isLoadingAddress = true);
    try {
      final detailed = await LocationService.reverseGeocodeDetailed(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        setState(() {
          _currentAddress = detailed;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_currentCenter != null) _resolveAddress(_currentCenter!);
    });
  }

  Future<void> _navigateToSearch() async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const LocationSearchScreen()),
    );

    if (result is AutocompletePrediction && mounted) {
      setState(() => _isLoadingAddress = true);
      final details = await LocationService.fetchPlaceDetails(result.placeId);
      if (details != null && mounted) {
        final target = LatLng(details.latitude, details.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        _resolveAddress(target);
      }
    }
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLoadingAddress = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      final target = LatLng(loc.latitude, loc.longitude);
      if (mounted) {
        setState(() => _userPosition = target);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        _resolveAddress(target);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  double _getDistanceInMeters() {
    if (_userPosition == null || _currentCenter == null) return 0;
    return Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      _currentCenter!.latitude,
      _currentCenter!.longitude,
    );
  }

  bool get _isAtCurrentLoc => _getDistanceInMeters() < _nearThreshold;

  String _getDistanceString() {
    final meters = _getDistanceInMeters();
    if (meters < 1000) {
      return '${meters.toInt()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = ref.read(locationProvider).location;
    final center = _currentCenter ?? const LatLng(11.0168, 76.9558);
    final isAtCurrent = _isAtCurrentLoc;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(initialPos?.latitude ?? center.latitude, initialPos?.longitude ?? center.longitude),
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController?.setMapStyle(_mapStyle);
            },
            onCameraMove: _onCameraMove,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          ),

          // Center Pin
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on, 
                    color: AppColors.brandGreen, 
                    size: 44,
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 42),
                ],
              ),
            ),
          ),

          // Top Header & Search
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
                        child: const Icon(Icons.arrow_back, color: AppColors.textMain, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _navigateToSearch,
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: AppColors.textSub, size: 20),
                              const SizedBox(width: 12),
                              Text('Search an area or address', style: GoogleFonts.poppins(color: AppColors.textSub, fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // FABs
          Positioned(
            bottom: isAtCurrent ? 220 : 280, // Dynamic height adjustment
            right: 20,
            child: GestureDetector(
              onTap: _moveToCurrentLocation,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
                child: const Icon(Icons.my_location, color: AppColors.brandGreen, size: 24),
              ),
            ),
          ),

          // Bottom card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isAtCurrent) ...[
                    Text(
                      'Order will be delivered here',
                      style: GoogleFonts.poppins(color: AppColors.textSub, fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: AppColors.brandGreen, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentAddress?.area ?? 'Detecting Location...',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textMain),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentAddress?.formattedAddress ?? 'Locating your exact point...',
                              style: GoogleFonts.poppins(color: AppColors.textSub, fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isAtCurrent) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFE7BA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.ctaOrange, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'This is ${_getDistanceString()} away from your current location',
                            style: GoogleFonts.poppins(color: AppColors.ctaOrangePressed, fontWeight: FontWeight.w500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoadingAddress || _currentAddress == null ? null : () {
                      if (widget.isAddingAddress) {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => AddAddressDetailScreen(
                              position: _currentCenter!,
                              address: _currentAddress!,
                            ),
                          ),
                        );
                      } else {
                        final newLoc = LocationData(
                          city: _currentAddress!.city ?? '',
                          state: _currentAddress!.state ?? '',
                          country: _currentAddress!.country ?? '',
                          formattedAddress: _currentAddress!.formattedAddress,
                          latitude: _currentCenter!.latitude,
                          longitude: _currentCenter!.longitude,
                          timestamp: DateTime.now(),
                        );
                        ref.read(locationProvider.notifier).overrideLocation(newLoc);
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoadingAddress 
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Confirm & proceed', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
