import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/theme/app_colors.dart';

class HabitDashboardScreen extends ConsumerWidget {
  const HabitDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'MY GROWTH',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.2,
            color: AppColors.textMain,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStreakCard(),
            const SizedBox(height: 32),
            _buildHabitTimeline(),
            const SizedBox(height: 32),
            _buildTodayStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.brandGreen,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandGreen.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAY 2 OF 5',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Muscle Gain Pack',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'ON TRACK 🔥',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: 0.4,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '40%',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR JOURNEY',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1,
            color: AppColors.textMain.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final isCompleted = index < 1;
            final isCurrent = index == 1;
            return _buildTimelineStep(index + 1, isCompleted, isCurrent);
          }),
        ),
      ],
    );
  }

  Widget _buildTimelineStep(int day, bool isCompleted, bool isCurrent) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.brandGreen
                : isCurrent
                    ? AppColors.brandGreen.withValues(alpha: 0.1)
                    : Colors.grey[100],
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: AppColors.brandGreen, width: 2)
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '$day',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isCurrent ? AppColors.brandGreen : Colors.grey[400],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Day $day',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: isCurrent ? AppColors.brandGreen : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.ctaOrange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'TODAY\'S DELIVERY',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=200&auto=format&fit=BoxFit.cover'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Muscle Gain Plate #2',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'High Protein • Chef\'s Choice',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
                  Text(
                    'Preparing Meal',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.brandGreen,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EST. DELIVERY',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
                  Text(
                    '1:15 PM',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
