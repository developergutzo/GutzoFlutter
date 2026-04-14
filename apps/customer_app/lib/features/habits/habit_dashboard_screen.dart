import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/models/habit_pack.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../../providers/habit_provider.dart';

class HabitDashboardScreen extends ConsumerWidget {
  const HabitDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitPacksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'MY HABITS',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.4,
            color: AppColors.textMain,
          ),
        ),
      ),
      body: habitsAsync.when(
        loading: () => const _HabitShimmer(),
        error: (e, _) => _buildError(e.toString()),
        data: (habits) {
          if (habits.isEmpty) return const _EmptyState();

          final active = habits.where((h) => h.isActive).firstOrNull;
          final past = habits.where((h) => !h.isActive).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(habitPacksProvider),
            color: AppColors.brandGreen,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (active != null) _ActiveHabitCard(habit: active),
                  if (active == null && past.isNotEmpty) const _EmptyState(),
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'PAST MISSIONS',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...past.map((h) => _PastHabitTile(habit: h)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Could not load habits', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textMain)),
          const SizedBox(height: 8),
          Text(msg, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// STATE 1: EMPTY
// ═══════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded, color: AppColors.brandGreen.withValues(alpha: 0.5), size: 44),
            ),
            const SizedBox(height: 28),
            Text(
              'No Active Mission',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.textMain),
            ),
            const SizedBox(height: 12),
            Text(
              'Commit to a 5-Day Habit Pack.\nComplete it and get Day 5 FREE 🎁',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[500], height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).maybePop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                elevation: 0,
              ),
              child: Text(
                'Browse Habits',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STATE 2 + 3 + 4 + 5: ACTIVE HABIT CARD (handles sub-states)
// ═══════════════════════════════════════════════════════════
class _ActiveHabitCard extends ConsumerWidget {
  final HabitPack habit;
  const _ActiveHabitCard({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (habit.isCompleted) return _CompletedBanner(habit: habit);
    if (habit.isCancelled) return _CancelledBanner(habit: habit);

    final isTodaySkipped = habit.isTodaySkipped();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // ── Streak Header Card ──
        _StreakCard(habit: habit),
        const SizedBox(height: 24),

        // ── Journey Timeline ──
        _TimelineRow(habit: habit),
        const SizedBox(height: 24),

        // ── Today's Delivery ──
        isTodaySkipped
            ? _SkippedTodayCard()
            : _TodayDeliveryCard(habit: habit),

        const SizedBox(height: 20),

        // ── Skip & Cancel buttons ──
        if (!isTodaySkipped)
          _ActionButtons(habit: habit),
      ],
    );
  }
}

// ── Streak Card ──────────────────────────────────────────────
class _StreakCard extends StatelessWidget {
  final HabitPack habit;
  const _StreakCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B9C5E), AppColors.brandGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.brandGreen.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAY ${habit.daysDone + 1} OF ${habit.daysTotal}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 26, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  habit.vendorName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 4),
                Text(
                  habit.productName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    habit.daysDone == 0 ? 'STARTING TODAY 🚀' : 'ON TRACK 🔥',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: habit.progressPercent,
                  strokeWidth: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '${(habit.progressPercent * 100).toInt()}%',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Timeline Row ─────────────────────────────────────────────
class _TimelineRow extends StatelessWidget {
  final HabitPack habit;
  const _TimelineRow({required this.habit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR JOURNEY',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2, color: Colors.grey[400]),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(habit.daysTotal, (i) {
            final day = i + 1;
            final isCompleted = i < habit.daysDone;
            final isCurrent = i == habit.daysDone;
            final today = DateTime.now().toIso8601String().substring(0, 10);
            final dayDate = habit.startDate.add(Duration(days: i)).toIso8601String().substring(0, 10);
            final isSkipped = habit.skipDates.contains(dayDate);

            return _TimelineStep(
              day: day,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isSkipped: isSkipped,
            );
          }),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final int day;
  final bool isCompleted;
  final bool isCurrent;
  final bool isSkipped;
  const _TimelineStep({required this.day, required this.isCompleted, required this.isCurrent, required this.isSkipped});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Widget content;

    if (isSkipped) {
      bgColor = Colors.amber[100]!;
      content = Icon(Icons.skip_next_rounded, color: Colors.amber[700], size: 20);
    } else if (isCompleted) {
      bgColor = AppColors.brandGreen;
      content = const Icon(Icons.check_rounded, color: Colors.white, size: 20);
    } else if (isCurrent) {
      bgColor = Colors.white;
      content = Text('$day', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.brandGreen));
    } else {
      bgColor = Colors.grey[100]!;
      content = Text('$day', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.grey[400]));
    }

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: AppColors.brandGreen, width: 2.5) : null,
            boxShadow: isCurrent ? [BoxShadow(color: AppColors.brandGreen.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))] : null,
          ),
          child: Center(child: content),
        ),
        const SizedBox(height: 8),
        Text(
          'Day $day',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: isCurrent ? AppColors.brandGreen : Colors.grey[400],
          ),
        ),
      ],
    );
  }
}

// ── Today's Delivery Card ────────────────────────────────────
class _TodayDeliveryCard extends StatelessWidget {
  final HabitPack habit;
  const _TodayDeliveryCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final todayOrder = habit.todayOrder;
    final status = todayOrder?['status'] as String?;
    final delivery = todayOrder?['delivery'] as Map<String, dynamic>?;

    String statusLabel;
    Color statusColor;
    String etaLabel;

    switch (status) {
      case 'confirmed':
        statusLabel = 'Kitchen Preparing'; statusColor = Colors.orange; etaLabel = 'Estimating...';
        break;
      case 'searching_rider':
        statusLabel = 'Finding Rider'; statusColor = Colors.blue; etaLabel = 'Rider Incoming';
        break;
      case 'on_way':
        statusLabel = 'On the Way 🛵'; statusColor = AppColors.brandGreen; etaLabel = delivery?['rider_name'] ?? 'Rider Assigned';
        break;
      case 'completed':
        statusLabel = 'Delivered ✅'; statusColor = AppColors.brandGreen; etaLabel = 'Today';
        break;
      default:
        statusLabel = 'Awaiting Kitchen'; statusColor = Colors.grey; etaLabel = 'No order yet';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text("TODAY'S DELIVERY — DAY ${habit.daysDone + 1}",
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1, color: AppColors.textMain)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: habit.productImage != null
                  ? Image.network(habit.productImage!, width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _mealPlaceholder())
                  : _mealPlaceholder(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.productName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textMain)),
                    const SizedBox(height: 4),
                    Text(habit.vendorName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[500])),
                    if (habit.healthGoal != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(habit.healthGoal!, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.brandGreen)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STATUS', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey[400])),
                  const SizedBox(height: 2),
                  Text(statusLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: statusColor)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('RIDER / ETA', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey[400])),
                  const SizedBox(height: 2),
                  Text(etaLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textMain)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mealPlaceholder() => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(color: AppColors.brandGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
    child: Icon(Icons.restaurant_rounded, color: AppColors.brandGreen.withValues(alpha: 0.5), size: 28),
  );
}

// ── Skipped Today Card ───────────────────────────────────────
class _SkippedTodayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.skip_next_rounded, color: Colors.amber[700], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today Skipped ⏭️', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.amber[800])),
                const SizedBox(height: 4),
                Text('Your pack end date has been extended by 1 day.', style: GoogleFonts.inter(fontSize: 12, color: Colors.amber[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skip & Cancel Buttons ────────────────────────────────────
class _ActionButtons extends ConsumerWidget {
  final HabitPack habit;
  const _ActionButtons({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showSkipSheet(context, ref),
            icon: const Icon(Icons.skip_next_rounded, size: 16),
            label: Text('Skip Today', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber[700],
              side: BorderSide(color: Colors.amber[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showCancelSheet(context, ref),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: Text('Cancel Pack', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[400],
              side: BorderSide(color: Colors.red[200]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showSkipSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkipBottomSheet(
        onConfirm: () async {
          try {
            await ref.read(habitActionsProvider.notifier).skipToday(habit.id);
            if (context.mounted) Navigator.pop(context);
          } catch (_) {}
        },
      ),
    );
  }

  void _showCancelSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CancelBottomSheet(
        habit: habit,
        onConfirm: (reason) async {
          try {
            await ref.read(habitActionsProvider.notifier).cancelPack(habit.id, reason);
            if (context.mounted) Navigator.pop(context);
          } catch (_) {}
        },
      ),
    );
  }
}

// ── Skip Confirmation Sheet ──────────────────────────────────
class _SkipBottomSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  const _SkipBottomSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⏭️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('Skip Today?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.textMain)),
          const SizedBox(height: 10),
          Text(
            "No worries! We'll extend your pack by 1 day so you still get all 5 deliveries.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Yes, Skip Today', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }
}

// ── Cancel Pack Sheet ────────────────────────────────────────
class _CancelBottomSheet extends StatefulWidget {
  final HabitPack habit;
  final void Function(String reason) onConfirm;
  const _CancelBottomSheet({required this.habit, required this.onConfirm});

  @override
  State<_CancelBottomSheet> createState() => _CancelBottomSheetState();
}

class _CancelBottomSheetState extends State<_CancelBottomSheet> {
  String _reason = 'Too busy this week';

  final _reasons = [
    'Too busy this week',
    'Changed my health goal',
    'Food didn\'t match my preference',
    'Found a better option',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cancel Pack?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.textMain)),
          const SizedBox(height: 8),
          Text(
            '${widget.habit.daysDone} of ${widget.habit.daysTotal} days completed. '
            'Remaining ${widget.habit.daysRemaining} days will be cancelled.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 24),
          Text('Why are you cancelling?', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textMain)),
          const SizedBox(height: 12),
          ..._reasons.map((r) => RadioListTile<String>(
            value: r,
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v!),
            title: Text(r, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            activeColor: Colors.red[400],
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onConfirm(_reason),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Confirm Cancellation', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Keep My Pack", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.brandGreen)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STATE 4: COMPLETED
// ═══════════════════════════════════════════════════════════
class _CompletedBanner extends StatelessWidget {
  final HabitPack habit;
  const _CompletedBanner({required this.habit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🏆', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('MISSION COMPLETE!', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text('You crushed your 5-Day ${habit.healthGoal ?? "Habit"} Mission!', style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
              const SizedBox(height: 20),
              Row(
                children: [
                  _StatChip('${habit.daysTotal} Days', 'Streak'),
                  const SizedBox(width: 12),
                  _StatChip('₹${habit.totalPaid.toInt()}', 'Invested'),
                  const SizedBox(width: 12),
                  _StatChip('Day 5', 'FREE 🎁'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Start Another Mission 🔥', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(100)),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STATE 5: CANCELLED
// ═══════════════════════════════════════════════════════════
class _CancelledBanner extends StatelessWidget {
  final HabitPack habit;
  const _CancelledBanner({required this.habit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.red[300], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Pack Cancelled', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textMain)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${habit.daysDone} of ${habit.daysTotal} days completed',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
              ),
              if (habit.cancellationReason != null) ...[
                const SizedBox(height: 6),
                Text('Reason: ${habit.cancellationReason}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400])),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Start a New Mission', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PAST HABITS TILE
// ═══════════════════════════════════════════════════════════
class _PastHabitTile extends StatelessWidget {
  final HabitPack habit;
  const _PastHabitTile({required this.habit});

  @override
  Widget build(BuildContext context) {
    final isCompleted = habit.isCompleted;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isCompleted ? AppColors.brandGreen.withValues(alpha: 0.2) : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isCompleted ? AppColors.brandGreen : Colors.grey[300]!).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.emoji_events_rounded : Icons.cancel_outlined,
              color: isCompleted ? AppColors.brandGreen : Colors.grey[400],
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.productName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textMain)),
                const SizedBox(height: 2),
                Text('${habit.daysDone}/${habit.daysTotal} days • ${habit.vendorName}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.brandGreen.withValues(alpha: 0.1) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isCompleted ? '✅ Done' : '❌ Cancelled',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                color: isCompleted ? AppColors.brandGreen : Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHIMMER LOADING
// ═══════════════════════════════════════════════════════════
class _HabitShimmer extends StatefulWidget {
  const _HabitShimmer();

  @override
  State<_HabitShimmer> createState() => _HabitShimmerState();
}

class _HabitShimmerState extends State<_HabitShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _shimmerBox(height: 180, radius: 28),
            const SizedBox(height: 24),
            _shimmerBox(height: 80, radius: 16),
            const SizedBox(height: 20),
            _shimmerBox(height: 140, radius: 20),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox({required double height, required double radius}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value + 1, 0),
          colors: const [Color(0xFFE8E8E8), Color(0xFFF2F2F2), Color(0xFFE8E8E8)],
        ),
      ),
    );
  }
}
