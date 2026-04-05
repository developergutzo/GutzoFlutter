import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/node_api_service.dart';

class HealthFilterModel {
  final String id;
  final String name;
  final int sortOrder;

  HealthFilterModel({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  factory HealthFilterModel.fromJson(Map<String, dynamic> json) {
    return HealthFilterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

final healthFiltersProvider = FutureProvider<List<HealthFilterModel>>((ref) async {
  final apiService = ref.watch(nodeApiServiceProvider);
  final response = await apiService.getHealthFilters();
  
  if (response['success'] == true && response['data'] != null) {
    final List<dynamic> data = response['data'];
    return data.map((json) => HealthFilterModel.fromJson(json)).toList();
  }
  return [];
});
