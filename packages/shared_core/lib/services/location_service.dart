import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import '../models/address.dart';

/// Location data matching the web app's LocationData interface
class LocationData {
  final String city;
  final String state;
  final String country;
  final String? formattedAddress;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  final String? houseNumber;
  final String? flatNumber;
  final String? buildingName;
  final String? block;
  final String? area;
  final String? tag;
  final String? selectedAddressId;

  LocationData({
    required this.city,
    required this.state,
    required this.country,
    this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.houseNumber,
    this.flatNumber,
    this.buildingName,
    this.block,
    this.area,
    this.tag,
    this.selectedAddressId,
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
  LocationData copyWith({
    String? city,
    String? state,
    String? country,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    String? houseNumber,
    String? flatNumber,
    String? buildingName,
    String? block,
    String? tag,
  }) {
    return LocationData(
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      houseNumber: houseNumber ?? this.houseNumber,
      flatNumber: flatNumber ?? this.flatNumber,
      buildingName: buildingName ?? this.buildingName,
      block: block ?? this.block,
      tag: tag ?? this.tag,
    );
  }

  static LocationData fromUserAddress(UserAddress address) {
    return LocationData(
      city: address.city,
      state: address.state,
      country: address.country,
      formattedAddress: address.fullAddress,
      latitude: address.latitude ?? 0.0,
      longitude: address.longitude ?? 0.0,
      timestamp: DateTime.now(),
      houseNumber: address.street,
      tag: address.label ?? address.type,
      area: address.area,
    );
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
/// Model for Autocomplete predictions
class AutocompletePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  AutocompletePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory AutocompletePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] ?? {};
    return AutocompletePrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: structured['main_text'] as String? ?? json['description'] as String,
      secondaryText: structured['secondary_text'] as String? ?? '',
    );
  }
}

/// Detailed address components for form auto-population
class DetailedAddress {
  final String formattedAddress;
  final String? streetNumber;
  final String? route;
  final String? sublocality;
  final String? locality;
  final String? area;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double latitude;
  final double longitude;

  final String? houseNumber;
  final String? flatNumber;
  final String? buildingName;
  final String? block;

  DetailedAddress({
    required this.formattedAddress,
    this.streetNumber,
    this.route,
    this.sublocality,
    this.locality,
    this.area,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.houseNumber,
    this.flatNumber,
    this.buildingName,
    this.block,
    required this.latitude,
    required this.longitude,
  });

  factory DetailedAddress.fromGoogleJson(Map<String, dynamic> json) {
    final components = json['address_components'] as List;
    final geometry = json['geometry']['location'];
    
    String? streetNumber;
    String? route;
    String? sublocality;
    String? locality;
    String? area;
    String? city;
    String? state;
    String? country;
    String? postalCode;
    String? houseNumber;
    String? flatNumber;
    String? buildingName;
    String? block;

    for (var component in components) {
      final types = component['types'] as List;
      final name = component['long_name'] as String;

      if (types.contains('street_number')) {
        streetNumber = name;
        houseNumber = name;
      }
      if (types.contains('subpremise')) {
        flatNumber = name;
      }
      if (types.contains('premise')) {
        buildingName = name;
      }
      if (types.contains('sublocality_level_2')) {
        block = name;
      }
      if (types.contains('route')) route = name;
      if (types.contains('sublocality_level_1') || types.contains('sublocality')) {
        sublocality = name;
        area ??= name;
      }
      if (types.contains('locality')) {
        locality = name;
        city ??= name;
      }
      if (types.contains('administrative_area_level_2')) {
        city ??= name;
      }
      if (types.contains('administrative_area_level_1')) state = name;
      if (types.contains('country')) country = name;
      if (types.contains('postal_code')) postalCode = name;
    }

    // Fallback for area
    if (area == null) {
      for (var component in components) {
        final types = component['types'] as List;
        if (types.contains('political') && !types.contains('country') && !types.contains('administrative_area_level_1')) {
          area = component['long_name'] as String;
          break;
        }
      }
    }

    return DetailedAddress(
      formattedAddress: json['formatted_address'] as String,
      streetNumber: streetNumber,
      route: route,
      sublocality: sublocality,
      locality: locality,
      area: area,
      city: city,
      state: state,
      country: country,
      postalCode: postalCode,
      houseNumber: houseNumber,
      flatNumber: flatNumber,
      buildingName: buildingName,
      block: block,
      latitude: geometry['lat'] as double,
      longitude: geometry['lng'] as double,
    );
  }
}

class LocationService {
  // Use the API key extracted from the web app's .env file
  static const String _googleMapsApiKey = 'AIzaSyA5P5eNfyXHcd-Qoy5NDlDQPmTg5olfHZY';

  /// Get places autocomplete suggestions
  static Future<List<AutocompletePrediction>> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_googleMapsApiKey'
        '&components=country:in', // assuming India based on context
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions
              .map((p) => AutocompletePrediction.fromJson(p as Map<String, dynamic>))
              .toList();
        } else {
          debugPrint('Google Maps Autocomplete Error: ${data['status']}');
        }
      } else {
        debugPrint('Google Maps Autocomplete HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    }
    return [];
  }

  /// Get detailed place information (coordinates + address components) from placeId
  static Future<DetailedAddress?> fetchPlaceDetails(String placeId) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=name,geometry,formatted_address,address_components'
        '&key=$_googleMapsApiKey'
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          return DetailedAddress.fromGoogleJson(data['result']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching place details: $e');
    }
    return null;
  }

  /// Reverse geocode coordinates using Google Maps for detailed components
  static Future<DetailedAddress?> reverseGeocodeDetailed(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&key=$_googleMapsApiKey'
        '&language=en'
        '&region=IN'
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
          return DetailedAddress.fromGoogleJson(data['results'][0]);
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding detailed: $e');
    }
    return null;
  }

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
      throw Exception('LOCATION_SERVICES_DISABLED');
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

    // Get position with maximum precision
    debugPrint('Invoking Geolocator.getCurrentPosition (Best Accuracy)...');
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
      timeLimit: const Duration(seconds: 15),
    );
    debugPrint('Received position: ${position.latitude}, ${position.longitude}');

    // Reverse geocode to get city/state
    debugPrint('Calling reverseGeocode...');
    return reverseGeocode(position.latitude, position.longitude);
  }

  /// Open device location settings or request service on Android
  static Future<void> openLocationSettings() async {
    debugPrint('LocationService: openLocationSettings called');
    try {
      // Try to trigger the native Android "Turn on Location" dialog first
      final location = loc.Location();
      debugPrint('LocationService: checking serviceEnabled...');
      bool serviceEnabled = await location.serviceEnabled();
      debugPrint('LocationService: serviceEnabled = $serviceEnabled');
      
      if (!serviceEnabled) {
        debugPrint('LocationService: requesting native service prompt...');
        serviceEnabled = await location.requestService();
        debugPrint('LocationService: native service request result = $serviceEnabled');
        if (serviceEnabled) {
          debugPrint('LocationService: user enabled service natively!');
          return;
        }
      }
    } catch (e) {
      debugPrint('LocationService ERROR: Native prompt failed: $e');
    }
    
    // Fallback to settings page if native prompt fails or user says NO
    debugPrint('LocationService: falling back to system settings page');
    await Geolocator.openLocationSettings();
  }
}

/// Riverpod provider for location state
class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() {
    // Listen for GPS being toggled ON/OFF (Mobile only)
    if (!kIsWeb) {
      final subscription = Geolocator.getServiceStatusStream().listen((status) {
        if (status == ServiceStatus.enabled) {
          debugPrint('📍 LocationNotifier: GPS enabled, re-triggering authoritative load...');
          refreshLocation();
        } else {
          debugPrint('📍 LocationNotifier: GPS disabled, updating state...');
          state = state.copyWith(error: 'LOCATION_OFF');
        }
      });

      // Listen for app lifecycle changes (resume)
      final observer = _AppLifecycleObserver(() {
        debugPrint('📍 LocationNotifier: App resumed, refreshing location...');
        refreshLocation();
      });
      WidgetsBinding.instance.addObserver(observer);

      ref.onDispose(() {
        subscription.cancel();
        WidgetsBinding.instance.removeObserver(observer);
      });
    }

    // Trigger initial authoritative load (force: true)
    Future.microtask(() => refreshLocation());

    return const LocationState(isLoading: true); 
  }

  Future<void> loadLocation({bool force = false}) async {
    // Already has location (from database or manual set) and not forcing refresh
    if (state.location != null && !force) return;
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get fresh GPS position and basic geocoding in one call
      final locationData = await LocationService.getCurrentLocation();

      // Attempt to get a more detailed address via Google Maps
      final detailed = await LocationService.reverseGeocodeDetailed(
        locationData.latitude,
        locationData.longitude,
      );

      if (detailed != null) {
        final finalLocation = locationData.copyWith(
          city: detailed.city,
          state: detailed.state,
          country: detailed.country,
          formattedAddress: detailed.formattedAddress,
          houseNumber: detailed.houseNumber,
          flatNumber: detailed.flatNumber,
          buildingName: detailed.buildingName,
          block: detailed.block,
        );
        
        // Atomic update to prevent "jumping"
        state = LocationState(
          location: finalLocation,
          isLoading: false,
        );
      } else {
        state = LocationState(
          location: locationData,
          isLoading: false,
        );
      }
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('LOCATION_SERVICES_DISABLED')) {
        state = LocationState(
          isLoading: false,
          error: 'LOCATION_OFF',
        );
      } else if (errorMessage.contains('permission denied')) {
        state = LocationState(
          isLoading: false,
          error: 'PERMISSION_DENIED',
        );
      } else {
        debugPrint('Location error: $e');
        state = LocationState(
          isLoading: false,
          error: e.toString(),
        );
      }
    }
  }

  /// Refresh location (clears cache, gets fresh GPS position)
  Future<void> refreshLocation() async {
    await loadLocation(force: true);
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

/// Internal observer to refresh location on app resume
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;
  _AppLifecycleObserver(this.onResume);

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      onResume();
    }
  }
}
