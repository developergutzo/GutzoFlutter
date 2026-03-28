import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import 'node_api_service.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final apiService = ref.watch(nodeApiServiceProvider);
  final response = await apiService.getCategories();
  
  // Handle both {success: true, data: [...]} and direct [...]
  final List<dynamic> data;
  if (response is Map<String, dynamic> && response.containsKey('data')) {
    data = response['data'] as List<dynamic>;
  } else if (response is List) {
    data = response;
  } else {
    return [];
  }
  
  return data.map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
});
