import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Location data matching the web app's LocationData interface
class LocationData {
  final String city;
  final String state;
  final String country;
  final String? formattedAddress;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationData({
    required this.city,
    required this.state,
    required this.country,
    this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  String get displayString {
    if (formattedAddress != null && formattedAddress!.isNotEmpty) {
      return formattedAddress!;
    }
    if (city.isNotEmpty && state.isNotEmpty) return '$city, $state';
    if (city.isNotEmpty) return city;
    if (state.isNotEmpty) return state;
    return country.isNotEmpty ? country : 'Unknown Location';
  }

  /// Extract just the area/locality name (e.g. "Sulur")
  String get areaName {
    if (city.isNotEmpty) return city;
    return 'Location';
  }

  /// Extract just the state name (e.g. "Tamil Nadu")
  String get stateName {
    if (state.isNotEmpty) return state;
    return '';
  }
}

/// Location state for the provider
class LocationState {
  final LocationData? location;
  final bool isLoading;
  final String? error;

  const LocationState({
    this.location,
    this.isLoading = true,
    this.error,
  });

  LocationState copyWith({
    LocationData? location,
    bool? isLoading,
    String? error,
  }) {
    return LocationState(
      location: location ?? this.location,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Location service — mirrors the web app's LocationService
class LocationService {
  /// Reverse geocode coordinates using BigDataCloud API (same as web app)
  static Future<LocationData> reverseGeocode(double latitude, double longitude) async {
    try {
      final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$latitude&longitude=$longitude&localityLanguage=en',
      );
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Geocoding API error: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      return LocationData(
        city: data['city'] ?? data['locality'] ?? '',
        state: data['principalSubdivision'] ?? data['countryName'] ?? '',
        country: data['countryName'] ?? '',
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      return LocationData(
        city: '',
        state: '',
        country: 'Unknown',
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get current device location via GPS + reverse geocode
  static Future<LocationData> getCurrentLocation() async {
    debugPrint('Checking if location services are enabled...');
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      throw Exception('Location services are disabled');
    }

    debugPrint('Checking location permissions...');
    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('Current permission status: $permission');
    if (permission == LocationPermission.denied) {
      debugPrint('Requesting location permission...');
      permission = await Geolocator.requestPermission();
      debugPrint('Permission status after request: $permission');
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      throw Exception('Location permissions are permanently denied');
    }

    // Get position
    debugPrint('Invoking Geolocator.getCurrentPosition...');
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    debugPrint('Received position: ${position.latitude}, ${position.longitude}');

    // Reverse geocode to get city/state
    debugPrint('Calling reverseGeocode...');
    return reverseGeocode(position.latitude, position.longitude);
  }
}

/// Riverpod provider for location state
class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() {
    // Schedule fetch after build completes to avoid "uninitialized provider" error
    Future.microtask(() => _loadLocation());
    return const LocationState();
  }

  Future<void> _loadLocation() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final locationData = await LocationService.getCurrentLocation();
      state = LocationState(
        location: locationData,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Location error: $e');
      state = LocationState(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh location (clears cache, gets fresh GPS position)
  Future<void> refreshLocation() async {
    await _loadLocation();
  }

  /// Override location manually (e.g. from saved address)
  void overrideLocation(LocationData locationData) {
    state = LocationState(
      location: locationData,
      isLoading: false,
    );
  }
}

final locationProvider = NotifierProvider<LocationNotifier, LocationState>(() {
  return LocationNotifier();
});
