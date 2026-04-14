import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/models/banner.dart' as model;
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/services/vendor_service.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/banner_service.dart';
import 'package:shared_core/utils/responsive.dart';
import 'package:shared_core/widgets/max_width_container.dart';
import '../../widgets/vendor_card.dart';
import '../../widgets/cart_strip.dart';
import '../../providers/location_sync_provider.dart';
import '../auth/auth_screen.dart';
import '../habits/habit_dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/widgets/web_profile_panel.dart';
import 'widgets/location_sheet.dart';
import 'widgets/search_sheet.dart';

final homeFilterProvider = StateProvider<String>((ref) => 'All');
final locationAutoPromptProvider = StateNotifierProvider<LocationPromptNotifier, bool>((ref) => LocationPromptNotifier());
final _navVisibleProvider = StateProvider<bool>((ref) => true);

class LocationPromptNotifier extends StateNotifier<bool> {
  LocationPromptNotifier() : super(false);
  void setPrompted() => state = true;
}

final homeTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isNavVisible = ref.watch(_navVisibleProvider);
    final selectedTab = ref.watch(homeTabProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 🗺️ Main marketplace body with scroll detection
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final delta = notification.scrollDelta ?? 0;
                if (delta > 6) {
                  ref.read(_navVisibleProvider.notifier).state = false;
                } else if (delta < -6) {
                  ref.read(_navVisibleProvider.notifier).state = true;
                }
              }
              return false;
            },
            child: selectedTab == 0
                ? const _MarketplaceBody()
                : const HabitDashboardScreen(),
          ),

          // 🛒 CartStrips above the nav bar (only on Home tab)
          if (selectedTab == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80, // above nav bar
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CartStrip(filterHabit: true, isPremium: true),
                  CartStrip(filterHabit: false, isPremium: true),
                ],
              ),
            ),

          // 🏠 Floating Nav Bar
          AnimatedSlide(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            offset: isNavVisible ? Offset.zero : const Offset(0, 2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              opacity: isNavVisible ? 1.0 : 0.0,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _FloatingNavBar(
                    selectedIndex: selectedTab,
                    onTap: (idx) => ref.read(homeTabProvider.notifier).state = idx,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Floating Pill Navigation Bar ────────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.brandGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavTab(
            icon: Icons.storefront_rounded,
            label: 'Home',
            isActive: selectedIndex == 0,
            onTap: () => onTap(0),
          ),
          const SizedBox(width: 4),
          _NavTab(
            icon: Icons.auto_awesome_rounded,
            label: 'My Habits',
            isActive: selectedIndex == 1,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : Colors.grey[400],
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceBody extends ConsumerWidget {
  const _MarketplaceBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(locationSyncProvider);

    final currentUser = ref.watch(currentUserProvider);
    final vendorsAsync = ref.watch(vendorProvider);
    final selectedFilter = ref.watch(homeFilterProvider);
    
    final filteredDishesAsync = vendorsAsync.whenData((vendors) {
      final List<Map<String, dynamic>> items = [];
      
      for (final v in vendors) {
        if (v.products == null) continue;
        for (final p in v.products!) {
          final mappedValue = GoalConstants.goalMapping[selectedFilter] ?? selectedFilter;
          if (selectedFilter == 'All' || p.healthGoals.contains(mappedValue)) {
            items.add({'product': p, 'vendor': v});
          }
        }
      }
      return items;
    });

    final bannersAsync = ref.watch(bannersProvider);

    return Responsive(
      mobile: _buildMobileBase(context, ref, bannersAsync, filteredDishesAsync, currentUser, selectedFilter),
      desktop: _buildWebBase(context, ref, bannersAsync, filteredDishesAsync, currentUser, selectedFilter),
    );
  }

  Widget _buildMobileBase(BuildContext context, WidgetRef ref, AsyncValue bannersAsync, AsyncValue<List<Map<String, dynamic>>> filteredDishesAsync, dynamic currentUser, String selectedFilter) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildMobileHeader(context, ref, currentUser),
              const _FilterChipsRow(),
              _buildBannersSection(bannersAsync),
              _buildDishGridMobile(filteredDishesAsync, ref, selectedFilter),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDishGridMobile(AsyncValue<List<Map<String, dynamic>>> dishesAsync, WidgetRef ref, String selectedFilter) {
    return dishesAsync.when(
      data: (items) {
        final allUnavailable = items.isNotEmpty && items.every((item) => item['vendor'].isServiceable == false);
        
        if (items.isEmpty || allUnavailable) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start, // 🎯 Nudge up for better balance
                  children: [
                    const SizedBox(height: 100), // 🎯 Controlled top offset
                    Icon(
                      items.isEmpty ? Icons.search_off_rounded : Icons.nights_stay_rounded, 
                      size: 64, 
                      color: AppColors.brandGreen.withValues(alpha: 0.2)
                    ),
                    const SizedBox(height: 24),
                    Text(
                      items.isEmpty 
                        ? "No dishes match your goal yet." 
                        : "Our chefs are resting for tomorrow's mission.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textMain),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      items.isEmpty
                        ? "Try exploring another health goal or check back soon!"
                        : "We'll be back at dawn with fresh, healthy dishes to fuel your journey.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSub),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 200),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 280,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final Map<String, dynamic> item = items[index];
                return VendorCard(
                  imageUrl: item['product'].displayImage,
                  title: item['vendor'].name,
                  cuisine: item['vendor'].cuisineType,
                  deliveryTime: item['vendor'].deliveryTime,
                  rating: item['vendor'].rating,
                  vendorModel: item['vendor'],
                  displayProduct: item['product'],
                  selectedGoal: selectedFilter,
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
      loading: () => SliverToBoxAdapter(child: Container(height: 200, margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(16)))),
      error: (err, stack) => SliverToBoxAdapter(child: Text('Error: $err')),
    );
  }

  Widget _buildMobileHeader(BuildContext context, WidgetRef ref, dynamic currentUser) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      floating: true,
      elevation: 0,
      toolbarHeight: 120,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: AppColors.brandGreen, borderRadius: BorderRadius.circular(8)),
                    child: const Center(child: Text('G', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 8),
                  const Text('GUTZO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textMain, letterSpacing: -0.5)),
                  const Spacer(),
                  IconButton(onPressed: () => SearchSheet.show(context), icon: const Icon(Icons.search, color: AppColors.textMain, size: 24)),
                  _buildProfileButton(context, ref, currentUser),
                ],
              ),
              const SizedBox(height: 4),
              _buildLocationRow(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context, WidgetRef ref, dynamic currentUser) {
    return GestureDetector(
      onTap: () {
        if (currentUser == null) {
          Navigator.push(context, CupertinoPageRoute(builder: (_) => const AuthScreen())).then((_) => ref.invalidate(currentUserProvider));
        } else {
          if (context.isDesktop || context.isTablet) WebProfilePanel.show(context);
          else Navigator.push(context, CupertinoPageRoute(builder: (_) => const ProfileScreen()));
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: AppColors.brandGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Center(
          child: currentUser == null 
            ? const Icon(Icons.person_outline, color: AppColors.brandGreen, size: 20)
            : Text(currentUser.initials, style: const TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final bool isOff = locationState.error == 'LOCATION_OFF';
    final areaName = isOff ? 'Location Off' : (locationState.location?.tag ?? locationState.location?.areaName ?? 'Detecting...');
    final fullAddress = isOff ? '' : locationState.location?.displayString;
    
    return InkWell(
      onTap: () => isOff ? LocationService.openLocationSettings() : LocationSheet.show(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(isOff ? Icons.location_off_outlined : Icons.location_on_outlined, color: isOff ? AppColors.errorRed : AppColors.brandGreen, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(areaName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textMain)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, color: AppColors.textDisabled, size: 18),
                  ],
                ),
                if (!isOff && fullAddress != null && fullAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    fullAddress, 
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: AppColors.textSub.withValues(alpha: 0.8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannersSection(AsyncValue bannersAsync) {
    return bannersAsync.when(
      data: (banners) {
        final List<model.HomeBanner> list = (banners as List).cast<model.HomeBanner>();
        if (list.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        
        return SliverToBoxAdapter(
          child: Container(
            height: 180,
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: PageView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(list[index].imageUrl), 
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => SliverToBoxAdapter(child: Container(height: 180, margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(16)))),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildWebBase(BuildContext context, WidgetRef ref, AsyncValue bannersAsync, AsyncValue filteredDishesAsync, dynamic currentUser, String selectedFilter) {
    return SingleChildScrollView(
      child: MaxWidthContainer(
        child: Column(
          children: [
            const _FilterChipsRow(),
            _buildBannersSection(bannersAsync),
            Padding(
              padding: const EdgeInsets.all(32),
              child: _buildDishGridWeb(filteredDishesAsync, ref, selectedFilter),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishGridWeb(AsyncValue dishesAsync, WidgetRef ref, String selectedFilter) {
    return dishesAsync.when(
      data: (items) {
        final List<Map<String, dynamic>> list = items as List<Map<String, dynamic>>;
        final allUnavailable = list.isNotEmpty && list.every((item) => item['vendor'].isServiceable == false);

        if (list.isEmpty || allUnavailable) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start, // 🎯 Nudge up for better balance
                children: [
                  const SizedBox(height: 80), // 🎯 Controlled top offset
                  Icon(
                    list.isEmpty ? Icons.search_off_rounded : Icons.nights_stay_rounded, 
                    size: 80, 
                    color: AppColors.brandGreen.withValues(alpha: 0.2)
                  ),
                  const SizedBox(height: 32),
                  Text(
                    list.isEmpty 
                      ? "No dishes match your goal yet." 
                      : "Our chefs are resting for tomorrow's mission.",
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    list.isEmpty
                      ? "Try exploring another health goal or check back soon!"
                      : "We'll be back at dawn with fresh, healthy dishes to fuel your journey.",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textSub),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 420, mainAxisSpacing: 32, crossAxisSpacing: 32, mainAxisExtent: 360),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return VendorCard(
              imageUrl: item['product'].displayImage,
              title: item['vendor'].name,
              cuisine: item['vendor'].cuisineType,
              deliveryTime: item['vendor'].deliveryTime,
              rating: item['vendor'].rating,
              vendorModel: item['vendor'],
              displayProduct: item['product'],
              selectedGoal: selectedFilter,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class GoalConstants {
  static const Map<String, String> goalMapping = {
    'All': 'All',
    'Flat Tummy': 'Flat Tummy',
    'Muscle Gain': 'Muscle Gain',
    'Skin Glow': 'Skin Glow',
    'Sugar Free': 'Clinical/Sugar',
  };
  static const Map<String, IconData> goalIcons = {
    'All': Icons.restaurant_rounded,
    'Flat Tummy': Icons.spa_rounded,
    'Muscle Gain': Icons.fitness_center_rounded,
    'Skin Glow': Icons.face_retouching_natural_rounded,
    'Sugar Free': Icons.eco_rounded,
  };
}

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGoal = ref.watch(homeFilterProvider);
    final goals = GoalConstants.goalMapping.keys.toList();
    return SliverPadding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 72, // Taller to fit Icon + Text vertically
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: goals.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final goal = goals[index];
              final isSelected = selectedGoal == goal;
              final icon = GoalConstants.goalIcons[goal] ?? Icons.fastfood_rounded;

              return Padding(
                padding: const EdgeInsets.only(right: 24), // More spacing between items
                child: GestureDetector(
                  onTap: () => ref.read(homeFilterProvider.notifier).state = goal,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSelected ? 1.0 : 0.5, // Unselected items are faded out
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        goal == 'Flat Tummy'
                          ? FlatTummyIcon(
                              size: 28,
                              color: isSelected ? AppColors.brandGreen : AppColors.textMain,
                            )
                          : Icon(
                              icon,
                              size: 28,
                              color: isSelected ? AppColors.brandGreen : AppColors.textMain,
                            ),
                        const SizedBox(height: 6),
                        Text(
                          goal,
                          style: TextStyle(
                            color: isSelected ? AppColors.brandGreen : AppColors.textMain,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Active Indicator underline
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          width: isSelected ? 24 : 0,
                          decoration: BoxDecoration(
                            color: AppColors.brandGreen,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class FlatTummyIcon extends StatelessWidget {
  final Color color;
  final double size;
  const FlatTummyIcon({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FlatTummyPainter(color),
      ),
    );
  }
}

class _FlatTummyPainter extends CustomPainter {
  final Color color;
  _FlatTummyPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Ultra-minimal left body contour (open curve)
    final leftBody = Path()
      ..moveTo(w * 0.3, h * 0.15)
      ..quadraticBezierTo(w * 0.45, h * 0.5, w * 0.3, h * 0.85);

    // Ultra-minimal right body contour (open curve)
    final rightBody = Path()
      ..moveTo(w * 0.7, h * 0.15)
      ..quadraticBezierTo(w * 0.55, h * 0.5, w * 0.7, h * 0.85);

    // Draw the minimal lines (No fill, no top/bottom closures)
    canvas.drawPath(leftBody, strokePaint);
    canvas.drawPath(rightBody, strokePaint);

    // Minimal subtle Navel to anchor it as a torso
    canvas.drawCircle(Offset(w * 0.5, h * 0.6), w * 0.03, strokePaint);

    // Minimal Left Arrow
    // Minimal Left Arrow
    final leftArrow = Path()
      ..moveTo(w * 0.05, h * 0.5)
      ..lineTo(w * 0.3, h * 0.5)
      ..moveTo(w * 0.2, h * 0.4)
      ..lineTo(w * 0.3, h * 0.5)
      ..lineTo(w * 0.2, h * 0.6);

    // Minimal Right Arrow (compressing inwards at waist)
    final rightArrow = Path()
      ..moveTo(w * 0.95, h * 0.5)
      ..lineTo(w * 0.7, h * 0.5)
      ..moveTo(w * 0.8, h * 0.4)
      ..lineTo(w * 0.7, h * 0.5)
      ..lineTo(w * 0.8, h * 0.6);

    canvas.drawPath(leftArrow, strokePaint);
    canvas.drawPath(rightArrow, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
