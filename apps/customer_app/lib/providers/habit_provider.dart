import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/habit_pack.dart';
import 'package:shared_core/services/node_api_service.dart';

import 'package:shared_core/services/auth_service.dart';

/// Fetches the user's habit packs (active first, then history)
final habitPacksProvider = FutureProvider<List<HabitPack>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.phone.isEmpty) return [];
  
  final api = ref.watch(nodeApiServiceProvider);
  final response = await api.getHabits();
  final List<dynamic> data = response['data'] ?? [];
  return data.map((e) => HabitPack.fromJson(e as Map<String, dynamic>)).toList();
});

/// Gets the single active (most recent) habit pack, or null
final activeHabitProvider = FutureProvider<HabitPack?>((ref) async {
  final habits = await ref.watch(habitPacksProvider.future);
  return habits.where((h) => h.isActive).firstOrNull;
});

/// Action notifier for habit operations (skip, cancel)
class HabitActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> skipToday(String habitPackId) async {
    final api = ref.read(nodeApiServiceProvider);
    await api.skipHabitDay(habitPackId);
    ref.invalidate(habitPacksProvider);
  }

  Future<void> cancelPack(String habitPackId, String reason) async {
    final api = ref.read(nodeApiServiceProvider);
    await api.cancelHabitPack(habitPackId, reason);
    ref.invalidate(habitPacksProvider);
  }
}

final habitActionsProvider = AsyncNotifierProvider<HabitActionsNotifier, void>(
  HabitActionsNotifier.new,
);
