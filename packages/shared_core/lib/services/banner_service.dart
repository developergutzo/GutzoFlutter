import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/banner.dart';
import 'node_api_service.dart';

final bannersProvider = FutureProvider<List<HomeBanner>>((ref) async {
  final apiService = ref.watch(nodeApiServiceProvider);
  final response = await apiService.getHomeBanners();
  
  // Handle both {success: true, data: [...]} and direct [...]
  final List<dynamic> data;
  if (response is Map<String, dynamic> && response.containsKey('data')) {
    data = response['data'] as List<dynamic>;
  } else if (response is List) {
    data = response;
  } else {
    return [];
  }
  
  return data
      .map((json) => HomeBanner.fromJson(json as Map<String, dynamic>))
      .where((banner) => banner.isActive)
      .toList();
});
