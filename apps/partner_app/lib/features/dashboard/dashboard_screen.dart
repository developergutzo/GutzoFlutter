import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../common/widgets/loading_overlay.dart';
import '../../common/widgets/skeletons.dart';
import '../auth/vendor_provider.dart';
import '../orders/order_provider.dart';
import '../reports/gst_report_screen.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/models/order.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/adaptive_wrapper.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(vendorProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitDialog(context);
        if (shouldPop == true && context.mounted) {
           // In a real app, uses SystemNavigator.pop() or similar
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: AdaptiveWrapper(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(vendorProvider.notifier).fetchVendor();
              await ref.read(orderListProvider.notifier).fetchOrders();
            },
            child: vendorAsync.when(
              loading: () => const DashboardSkeleton(),
              error: (err, st) => CustomScrollView(
                slivers: [
                  if (!isDesktop) _buildSliverAppBar(context, ref, vendorAsync),
                  SliverToBoxAdapter(child: _buildErrorBanner(context, ref, err.toString())),
                ],
              ),
              data: (vendor) {
                final ordersAsync = ref.watch(orderListProvider);
                final statsAsync = ref.watch(dashboardStatsProvider);
                final List<Order> orders = ordersAsync.valueOrNull ?? [];
                final stats = statsAsync.valueOrNull ?? <String, dynamic>{};
                
                final now = DateTime.now();
                final todayOrders = orders.where((o) => 
                  o.createdAt.year == now.year && 
                  o.createdAt.month == now.month && 
                  o.createdAt.day == now.day &&
                  o.status != 'cancelled' && o.status != 'rejected'
                ).toList();
                
                final ordersCount = stats['todayOrders'] ?? todayOrders.length;
                final revenueCount = stats['todayRevenue']?.toDouble() ?? todayOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
                final rating = stats['rating']?.toDouble() ?? (vendor?.rating ?? 4.8);
                final views = stats['views']?.toString() ?? '...';

                if (isDesktop) {
                  return _buildWebDashboard(context, ref, vendor, orders, stats, ordersCount, revenueCount, rating, views);
                }

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildSliverAppBar(context, ref, vendorAsync),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildServiceStatusCard(ref, vendorAsync),
                            const SizedBox(height: 32),
                            _buildSectionHeader('TODAY\'S INSIGHTS'),
                            const SizedBox(height: 12),
                            _buildInsightsHub(ordersCount.toString(), '₹${revenueCount.toStringAsFixed(0)}', rating.toString(), views),
                            const SizedBox(height: 32),
                            _buildSectionHeader('OPERATIONAL TOOLS'),
                            const SizedBox(height: 12),
                            _buildBusinessToolsGrid(context, stats),
                            const SizedBox(height: 32),
                            _buildSectionHeader('RECENT ACTIVITY'),
                            const SizedBox(height: 12),
                            _buildRecentActivityList(context, orders),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebDashboard(
    BuildContext context, 
    WidgetRef ref, 
    dynamic vendor, 
    List<Order> orders, 
    Map<String, dynamic> stats,
    dynamic ordersCount,
    dynamic revenueCount,
    dynamic rating,
    dynamic views,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(64, 64, 64, 100),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWebHeader(context, ref, vendor),
              const SizedBox(height: 64),
              
              // Top Bento Row: 3 Primary Stats
              _buildPrimaryStatRow(ordersCount.toString(), '₹${revenueCount.toStringAsFixed(0)}', rating.toString()),
              
              const SizedBox(height: 32),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Operation Column
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildRecentActivityList(context, orders), // 🎯 Fixed: Pass context here
                        const SizedBox(height: 24),
                        _buildOperationalBento(context, stats),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Control & Context Column
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildStatusBento(ref, vendor),
                        const SizedBox(height: 24),
                        _buildMiniInsightBento(views),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryStatRow(String orders, String revenue, String rating) {
    return Row(
      children: [
        Expanded(child: _buildBentoStatCard('TODAY\'S ORDERS', orders, Icons.shopping_bag_rounded, AppColors.brandGreen, '+12%')),
        const SizedBox(width: 24),
        Expanded(child: _buildBentoStatCard('REVENUE', revenue, Icons.payments_rounded, Colors.orange, '+₹2.4k')),
        const SizedBox(width: 24),
        Expanded(child: _buildBentoStatCard('KITCHEN RATING', rating, Icons.stars_rounded, Colors.amber, 'New 5★')),
      ],
    );
  }

  Widget _buildMiniInsightBento(String views) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL VIEWS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textDisabled, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Text(views, style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -1.5)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.trending_up_rounded, color: Colors.blue, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoStatCard(String label, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.brandGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Text(trend, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.brandGreen, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -2)),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textDisabled, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildOperationalBento(BuildContext context, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OPERATIONAL TOOLS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: 1)),
          const SizedBox(height: 28),
          _buildBentoToolLink('GST Report Center', 'Manage your tax filings and monthly logs', Icons.description_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReportScreen()))),
          const SizedBox(height: 16),
          _buildBentoToolLink('Performance Insights', 'Detailed kitchen and sales analytics', Icons.analytics_rounded, () => _showPerformanceDialog(context, stats)),
        ],
      ),
    );
  }

  Widget _buildBentoToolLink(String title, String sub, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMain, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textMain)),
                  Text(sub, style: GoogleFonts.inter(color: AppColors.textSub, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBento(WidgetRef ref, dynamic vendor) {
    final isOpen = vendor?.isOpen ?? false;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOpen ? [const Color(0xFF10B981), const Color(0xFF059669)] : [const Color(0xFF334155), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: (isOpen ? AppColors.brandGreen : Colors.black).withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(isOpen ? Icons.restaurant_rounded : Icons.nights_stay_rounded, color: Colors.white.withOpacity(0.9), size: 32),
              Switch.adaptive(
                value: isOpen,
                onChanged: (v) => ref.read(vendorProvider.notifier).updateStatus(v),
                activeColor: Colors.white,
                activeTrackColor: Colors.white24,
              ),
            ],
          ),
          const SizedBox(height: 48),
          Text(isOpen ? 'SERVICE IS LIVE' : 'SERVICE PAUSED', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
            isOpen ? 'Your kitchen is visible to customers' : 'Customers cannot place orders right now',
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityBento(BuildContext context, List<Order> orders) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT ORDERS', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: 1.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.brandGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.brandGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('LIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.brandGreen, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildRecentActivityList(context, orders),
        ],
      ),
    );
  }

  Widget _buildWebHeader(BuildContext context, WidgetRef ref, dynamic vendor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, ${vendor?.name ?? 'Partner'}',
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Text(
              'Here is what\'s happening with your store today.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSub, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Row(
          children: [
            _buildHeaderAction(Icons.notifications_none_rounded, () {}),
            const SizedBox(width: 12),
            _buildHeaderAction(Icons.power_settings_new_rounded, () => _showLogoutDialog(context, ref), isDestructive: true),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDestructive ? AppColors.errorRed.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDestructive ? AppColors.errorRed.withOpacity(0.2) : Colors.grey[200]!),
        ),
        child: Icon(icon, color: isDestructive ? AppColors.errorRed : AppColors.textMain, size: 20),
      ),
    );
  }



  Widget _buildErrorBanner(BuildContext context, WidgetRef ref, String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.errorRed),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error,
                  style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ref.read(vendorProvider.notifier).fetchVendor(),
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY CONNECTION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, WidgetRef ref, AsyncValue vendorAsync) {
    return SliverAppBar(
      expandedHeight: 110,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.1),
      flexibleSpace: FlexibleSpaceBar(
        expandedTitleScale: 1.1,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GUTZO',
                  style: GoogleFonts.inter(
                    color: AppColors.brandGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  (vendorAsync.value?.name ?? 'PARTNER DASHBOARD').toUpperCase(),
                  style: GoogleFonts.inter(
                    color: AppColors.textSub,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showLogoutDialog(context, ref),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Theme.of(context).platform == TargetPlatform.iOS 
                    ? CupertinoIcons.power 
                    : Icons.power_settings_new_rounded, 
                  color: AppColors.errorRed, 
                  size: 18
                ),
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard(WidgetRef ref, AsyncValue vendorAsync) {
    final isOpen = vendorAsync.value?.isOpen ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOpen 
            ? [const Color(0xFF10B981), const Color(0xFF059669)] 
            : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isOpen ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOpen ? const Color(0xFF059669) : Colors.black).withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isOpen ? Icons.restaurant_rounded : Icons.nights_stay_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'KITCHEN OPEN' : 'KITCHEN CLOSED',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOpen ? 'Accepting Active Orders' : 'Storefront is Offline',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isOpen,
            onChanged: (val) => ref.read(vendorProvider.notifier).updateStatus(val),
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF34D399),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsHub(String orders, String revenue, String rating, String views) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildInsightCell('Orders', orders, Icons.shopping_bag_outlined, AppColors.brandGreen)),
                Container(height: 30, width: 1, color: Colors.grey[50]),
                Expanded(child: _buildInsightCell('Revenue', revenue, Icons.currency_rupee, Colors.orange)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[50]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildInsightCell('Rating', rating, Icons.star_outline, Colors.amber)),
                Container(height: 30, width: 1, color: Colors.grey[50]),
                Expanded(child: _buildInsightCell('Views', views, Icons.remove_red_eye_outlined, Colors.blue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCell(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.textSub),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSub, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain, letterSpacing: -1)),
      ],
    );
  }

  Widget _buildRecentActivityList(BuildContext context, List<Order> orders) {
    if (orders.isEmpty) {
      return _buildPlaceholderCard('No transactions found yet');
    }

    final recent = orders.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ...recent.asMap().entries.map((entry) {
            final idx = entry.key;
            final order = entry.value;
            final timeStr = DateFormat('hh:mm a').format(order.createdAt);
            return InkWell(
              onTap: () => context.go('/orders?id=${order.id}'),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(_getStatusIcon(order.status), color: _getStatusColor(order.status), size: 22),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #${order.orderNumber}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${order.items.length} Items • $timeStr',
                                style: const TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                             Text(
                              '₹${order.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.brandGreen, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(order.status),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (idx < recent.length - 1)
                    Divider(height: 1, color: Colors.grey[50]!, indent: 80),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBusinessToolsGrid(BuildContext context, Map<String, dynamic> stats) {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildToolCard(
          context,
          'GST Reports',
          'Tax filing logs',
          Icons.document_scanner_outlined,
          AppColors.brandGreen,
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReportScreen())),
        ),
        _buildToolCard(
          context,
          'Performance',
          'Sales insights',
          Icons.query_stats_outlined,
          Colors.orange,
          () => _showPerformanceDialog(context, stats),
        ),
      ],
    );
  }

  Widget _buildToolCard(BuildContext context, String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(color: AppColors.textSub, fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'received': return Colors.blue;
      case 'preparing': return Colors.orange;
      case 'ready': return Colors.indigo;
      case 'dispatched': return AppColors.brandGreen;
      case 'delivered': return AppColors.brandGreen;
      case 'cancelled': return AppColors.errorRed;
      case 'rejected': return AppColors.errorRed;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'received': return Icons.new_releases_outlined;
      case 'preparing': return Icons.restaurant_outlined;
      case 'ready': return Icons.check_circle_outline;
      case 'dispatched': return Icons.delivery_dining_outlined;
      case 'delivered': return Icons.shopping_bag_outlined;
      default: return Icons.receipt_long_outlined;
    }
  }

  Widget _buildPlaceholderCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: Colors.grey[200], size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textDisabled,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Exit Gutzo Partner'),
          content: const Text('Are you sure you want to exit the application?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exit'),
            ),
          ],
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Gutzo Partner'),
        content: const Text('Are you sure you want to exit the application?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.brandGreen,
        letterSpacing: 1.2,
      ),
    );
  }

  void _showPerformanceDialog(BuildContext context, Map<String, dynamic> stats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            const Icon(Icons.insights_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Text('PERFORMANCE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Today\'s Revenue', '₹${(stats['todayRevenue'] ?? 0).toStringAsFixed(0)}'),
            const Divider(),
            _buildStatRow('Today\'s Orders', '${stats['todayOrders'] ?? 0}'),
            const Divider(),
            _buildStatRow('Customer Rating', '${stats['rating'] ?? 4.5} ★'),
            const Divider(),
            _buildStatRow('Profile Views', '${stats['views'] ?? 0}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.brandGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textSub)),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textMain)),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('LOGOUT SESSION', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
          content: Text('Are you sure you want to end your partner session?', style: GoogleFonts.inter()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: CupertinoColors.systemBlue)),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                ref.read(authServiceProvider).signOut();
                ref.read(vendorProvider.notifier).logout();
                Navigator.pop(context);
              },
              child: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('LOGOUT SESSION', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Text('Are you sure you want to end your partner session?', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 12))
            ),
            TextButton(
              onPressed: () {
                ref.read(authServiceProvider).signOut();
                ref.read(vendorProvider.notifier).logout();
                Navigator.pop(context);
              },
              child: Text('LOGOUT', style: GoogleFonts.inter(color: AppColors.errorRed, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      );
    }
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(1.0 - _controller.value),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      },
    );
  }
}
