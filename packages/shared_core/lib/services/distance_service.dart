import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DistanceService {
  static const String _googleMapsApiKey = 'AIzaSyA5P5eNfyXHcd-Qoy5NDlDQPmTg5olfHZY';

  static Future<String?> getTravelTime({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      debugPrint('DistanceService: Calculating travel time from ($originLat, $originLng) to ($destLat, $destLng)');
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=$originLat,$originLng'
        '&destinations=$destLat,$destLng'
        '&mode=driving' // Driving is more universally supported than bicycling/motorcycle in Distance Matrix
        '&key=$_googleMapsApiKey',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('DistanceService: API Response: ${json.encode(data)}');
        if (data['status'] == 'OK' && 
            data['rows'] != null && 
            (data['rows'] as List).isNotEmpty &&
            data['rows'][0]['elements'] != null &&
            (data['rows'][0]['elements'] as List).isNotEmpty &&
            data['rows'][0]['elements'][0]['status'] == 'OK') {
          
          final text = data['rows'][0]['elements'][0]['duration']['text'] as String?;
          debugPrint('DistanceService: Found travel time: $text');
          return text;
        }
      } else {
        debugPrint('DistanceService: API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('DistanceService: Exception: $e');
    }
    return null;
  }

  static int parseDurationToMinutes(String duration) {
    if (duration.isEmpty) return 0;
    // Extract numbers from "15 mins" or "1 hour 5 mins"
    final RegExp regExp = RegExp(r'(\d+)');
    final matches = regExp.allMatches(duration);
    
    if (matches.isEmpty) return 0;

    if (duration.contains('hour')) {
      int hours = int.tryParse(matches.first.group(0) ?? '0') ?? 0;
      int mins = matches.length > 1 ? (int.tryParse(matches.elementAt(1).group(0) ?? '0') ?? 0) : 0;
      return (hours * 60) + mins;
    }

    return int.tryParse(matches.first.group(0) ?? '0') ?? 0;
  }
}
