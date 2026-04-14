import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../auth/vendor_provider.dart';

// ─────────────────────────────────────────────────────────────
// Provider: fetch today's active habit subscribers for this vendor
// ─────────────────────────────────────────────────────────────
final todayHabitSubscribersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final vendor = ref.watch(vendorProvider).value;
  if (vendor == null) return [];
  final api = ref.watch(nodeApiServiceProvider);
  final response = await api.getVendorTodayHabits(vendor.id);
  final List<dynamic> data = response['data'] ?? [];
  return data.cast<Map<String, dynamic>>();
});

// ─────────────────────────────────────────────────────────────
// Widget: Today's Habit Subscribers Banner
// Renders at the top of the ACTIVE orders tab
// ─────────────────────────────────────────────────────────────
class TodayHabitsBanner extends ConsumerWidget {
  const TodayHabitsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscribersAsync = ref.watch(todayHabitSubscribersProvider);

    return subscribersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (subscribers) {
        if (subscribers.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.brandGreen.withValues(alpha: 0.08), AppColors.brandGreen.withValues(alpha: 0.04)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${subscribers.length} TODAY',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'HABIT SUBSCRIBERS',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textMain),
                    ),
                    const Spacer(),
                    Icon(Icons.auto_awesome_rounded, color: AppColors.brandGreen, size: 18),
                  ],
                ),
              ),
              ...subscribers.map((sub) => _HabitSubscriberRow(habit: sub, ref: ref)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _HabitSubscriberRow extends StatefulWidget {
  final Map<String, dynamic> habit;
  final WidgetRef ref;
  const _HabitSubscriberRow({required this.habit, required this.ref});

  @override
  State<_HabitSubscriberRow> createState() => _HabitSubscriberRowState();
}

class _HabitSubscriberRowState extends State<_HabitSubscriberRow> {
  bool _loading = false;
  bool _triggered = false;

  Future<void> _triggerToday() async {
    setState(() => _loading = true);
    try {
      final api = widget.ref.read(nodeApiServiceProvider);
      await api.triggerHabitToday(widget.habit['id'] as String);
      setState(() { _loading = false; _triggered = true; });
      widget.ref.invalidate(todayHabitSubscribersProvider);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red[400]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitName = widget.habit['product_name'] as String? ?? 'Habit Meal';
    final daysDone = widget.habit['days_done'] as int? ?? 0;
    final daysTotal = widget.habit['days_total'] as int? ?? 5;
    final alreadyTriggered = _triggered || (widget.habit['today_order_exists'] as bool? ?? false);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'D${daysDone + 1}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.brandGreen),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habitName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textMain),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Day ${daysDone + 1} of $daysTotal',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          alreadyTriggered
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.brandGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Dispatched ✓', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.brandGreen)),
              )
            : ElevatedButton(
                onPressed: _loading ? null : _triggerToday,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _loading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text("Start Today's 🛵", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11)),
              ),
        ],
      ),
    );
  }
}
