import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mood_category.dart';
import 'node_api_service.dart';

final moodCategoriesProvider = FutureProvider<List<MoodCategory>>((ref) async {
  final apiService = ref.watch(nodeApiServiceProvider);
  final response = await apiService.getMoodCategories();
  
  final List<dynamic> data;
  if (response is Map<String, dynamic> && response.containsKey('data')) {
    data = response['data'] as List<dynamic>;
  } else if (response is List) {
    data = response;
  } else {
    return [];
  }
  
  return data.map((json) => MoodCategory.fromJson(json as Map<String, dynamic>)).toList();
});
