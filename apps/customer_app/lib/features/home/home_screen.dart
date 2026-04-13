import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/utils/responsive.dart';
import 'package:shared_core/services/location_service.dart';
import '../../widgets/cart_strip.dart';
import '../profile/profile_screen.dart' as profile_feature;
import '../auth/auth_screen.dart';
import './widgets/location_pick_screen.dart';
import './widgets/location_sheet.dart';
import './widgets/home_nav_item.dart';
import 'dart:ui' as ui;

// 🎨 Brand Colors
const kGutzoGreen = Color(0xFF00A36C); 
const kGutzoOrange = Color(0xFFFF5200); 
const kDeepText = Color(0xFF1A1A1A);

// 🎯 Providers
final selectedGoalProvider = StateProvider<String?>((ref) => 'Muscle Gain');
final orderPlacedProvider = StateProvider<bool>((ref) => false);
final bottomBarVisibleProvider = StateProvider<bool>((ref) => true);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (ref.read(bottomBarVisibleProvider)) {
        ref.read(bottomBarVisibleProvider.notifier).state = false;
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!ref.read(bottomBarVisibleProvider)) {
        ref.read(bottomBarVisibleProvider.notifier).state = true;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final selectedGoal = ref.watch(selectedGoalProvider);
    final user = ref.watch(currentUserProvider);
    final hasOrder = ref.watch(orderPlacedProvider);
    final isBottomVisible = ref.watch(bottomBarVisibleProvider);

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(context, locationState),
                  _buildStickyGoalChips(context),
                  
                  // URGERNCY BANNER
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: kGutzoOrange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kGutzoOrange.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: kGutzoOrange, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedGoal == 'Muscle Gain' 
                                ? '34 people in Coimbatore fueled their workout with this today.'
                                : selectedGoal == 'Skin Glow'
                                  ? '12 people in your area started their radiance habit today.'
                                  : 'Ordering for office? Get it by 1:15 PM if you order in 10 mins.',
                              style: GoogleFonts.inter(
                                color: kGutzoOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const _MarketplaceFeed(),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
                ],
              ),
              
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                bottom: isBottomVisible ? 0 : -100,
                left: 0,
                right: 0,
                child: _buildBottomNav(context, hasOrder),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, LocationState locationState) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SvgPicture.asset(
                  'assets/images/logo.svg',
                  height: 24,
                  colorFilter: const ColorFilter.mode(kGutzoGreen, BlendMode.srcIn),
                ),
                GestureDetector(
                  onTap: () => _openProfile(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: user != null 
                      ? Text(
                          _getInitials(user.name),
                          style: GoogleFonts.inter(
                            color: kDeepText,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        )
                      : const Icon(Icons.person_outline_rounded, color: kDeepText, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.location_on_rounded, color: kGutzoGreen, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => LocationSheet.show(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (locationState.location?.tag ?? "Home").toUpperCase(),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: kDeepText),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 18),
                          ],
                        ),
                        Text(
                          locationState.location?.displayString ?? 'Select Location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kGutzoGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Clean • Fresh • Result-Driven',
                    style: GoogleFonts.inter(color: kGutzoGreen, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return "";
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  void _openProfile(BuildContext context) {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      Navigator.of(context).push(CupertinoPageRoute(
        builder: (context) => const AuthScreen(),
      ));
    } else {
      Navigator.of(context).push(CupertinoPageRoute(
        builder: (context) => const profile_feature.ProfileScreen(),
      ));
    }
  }

  void _openLocationPicker(BuildContext context) {
    LocationSheet.show(context);
  }

  Widget _buildStickyGoalChips(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyGoalDelegate(),
    );
  }

  Widget _buildBottomNav(BuildContext context, bool hasOrder) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          HomeNavItem(icon: Icons.home_filled, label: 'Home', active: true),
          Stack(
            children: [
              HomeNavItem(icon: Icons.stars_rounded, label: 'My Habits', active: false),
              if (hasOrder)
                Positioned(
                  top: 0,
                  right: 4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: kGutzoOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickyGoalDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 140;
  @override
  double get maxExtent => 140;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Consumer(
      builder: (context, ref, _) {
        final selected = ref.watch(selectedGoalProvider);
        final goals = [
          {
            'id': 'Muscle Gain',
            'label': 'Muscle Gain',
            'sub': 'High Protein',
            'icon': Icons.fitness_center_rounded,
            'color': const Color(0xFF006D44), // Deep Emerald
            'bg': const Color(0xFFE8F6F1),
          },
          {
            'id': 'Skin Glow',
            'label': 'Skin Glow',
            'sub': 'Antioxidant Rich',
            'icon': Icons.auto_awesome_rounded,
            'color': const Color(0xFFD48166), // Soft Peach
            'bg': const Color(0xFFFFF4F1),
          },
          {
            'id': 'Flat Tummy',
            'label': 'Flat Tummy',
            'sub': 'Low Carb',
            'icon': Icons.spa_rounded,
            'color': const Color(0xFF1BA672), // Teal
            'bg': const Color(0xFFE8F6F1),
          },
          {
            'id': 'Sugar Control',
            'label': 'Sugar Control',
            'sub': 'Low GI',
            'icon': Icons.monitor_heart_rounded,
            'color': const Color(0xFF3B4CC0), // Royal Blue
            'bg': const Color(0xFFF0F2FF),
          },
        ];

        return Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(
                      selected == 'Muscle Gain' 
                        ? '3/5 meals this week to hit your protein target'
                        : 'Fuel your transformation with precise nutrition',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    final isSelected = selected == goal['id'];
                    final color = goal['color'] as Color;
                    final bg = goal['bg'] as Color;

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => ref.read(selectedGoalProvider.notifier).state = goal['id'] as String,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          width: 140,
                          transform: isSelected ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? bg : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? color : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                            ] : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(goal['icon'] as IconData, color: isSelected ? color : Colors.grey.shade400, size: 20),
                              const Spacer(),
                              Text(
                                (goal['label'] as String).toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: isSelected ? color : kDeepText,
                                ),
                              ),
                              Text(
                                goal['sub'] as String,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9,
                                  color: isSelected ? color.withOpacity(0.7) : Colors.grey.shade500,
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
            ],
          ),
        );
      },
    );
  }

  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _MarketplaceFeed extends ConsumerWidget {
  const _MarketplaceFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(selectedGoalProvider);

    // Dynamic Marketplace Logic: Reordering items based on Goal Match (AOV/Revenue optimization)
    final meals = [
      {
        'id': 'titan',
        'title': 'The Titan Bowl',
        'vendor': 'Gutzo Kitchen • Saibaba Colony',
        'benefit': '45g PROTEIN',
        'price': 299,
        'image': 'assets/images/bright_titan_bowl_1775986868119.png',
        'rating': '4.8',
        'time': '20 min',
        'social': '34 people in Coimbatore fueled their workout with this today',
        'isVerified': true,
        'match': 'Muscle Gain',
        'color': const Color(0xFF006D44),
      },
      {
        'id': 'glow',
        'title': 'Wellness Glow Salad',
        'vendor': 'Gutzo Kitchen • Peelamedu',
        'benefit': 'HYDRATION BOOST',
        'price': 249,
        'image': 'assets/images/bright_glow_salad_1775986883063.png',
        'rating': '4.9',
        'time': '25 min',
        'social': '12 celebrities in Coimbatore started this habit today',
        'isVerified': true,
        'match': 'Skin Glow',
        'color': const Color(0xFFD48166),
      },
      {
        'id': 'light',
        'title': 'The Light Plate',
        'vendor': 'Gutzo Kitchen • RS Puram',
        'benefit': 'ZERO BLOAT',
        'price': 269,
        'image': 'assets/images/flat_tummy_goal_card_1775986104132.png',
        'rating': '4.7',
        'time': '22 min',
        'social': 'Perfect for a post-office energy reboot',
        'isVerified': false,
        'match': 'Flat Tummy',
        'color': const Color(0xFF1BA672),
      },
    ];

    // SORTING ALGORITHM: Top Goal matches first for revenue conversion
    meals.sort((a, b) {
      if (a['match'] == goal) return -1;
      if (b['match'] == goal) return 1;
      return 0;
    });

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _HighVibrancyProductCard(
          meal: meals[index],
          isActiveGoal: meals[index]['match'] == goal,
        ),
        childCount: meals.length,
      ),
    );
  }
}

class _HighVibrancyProductCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final bool isActiveGoal;
  const _HighVibrancyProductCard({required this.meal, this.isActiveGoal = false});

  @override
  Widget build(BuildContext context) {
    final themeColor = meal['color'] as Color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActiveGoal ? themeColor.withOpacity(0.5) : Colors.grey.shade100,
          width: isActiveGoal ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActiveGoal ? themeColor.withOpacity(0.1) : Colors.black.withOpacity(0.02), 
            blurRadius: 20, 
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.5,
                  child: Image.asset(meal['image'], fit: BoxFit.cover),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: kGutzoOrange, size: 14),
                        const SizedBox(width: 4),
                        Text(meal['rating'], style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11)),
                        Text(' • ${meal['time']}', style: GoogleFonts.inter(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                if (meal['isVerified'] == true)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: kGutzoGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: kGutzoGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        meal['benefit'],
                        style: GoogleFonts.inter(color: kGutzoGreen, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal['title'],
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: kDeepText),
                          ),
                          Text(
                            meal['vendor'],
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text('₹${meal['price']}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 8),
                              Text('₹${(meal['price'] * 1.3).toInt()}', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _AddActionCircle(mealTitle: meal['title']),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: Color(0xFFF5F5F5)),
                ),
                
                Row(
                  children: [
                    const Icon(Icons.trending_up_rounded, color: kGutzoGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meal['social'],
                        style: GoogleFonts.inter(fontSize: 11, color: kDeepText.withOpacity(0.7), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddActionCircle extends StatelessWidget {
  final String mealTitle;
  const _AddActionCircle({required this.mealTitle});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return GestureDetector(
          onTap: () {
            final user = ref.read(currentUserProvider);
            if (user == null) {
              Navigator.of(context).push(CupertinoPageRoute(
                builder: (context) => const AuthScreen(),
              ));
              return;
            }
            _showRevenueUpsell(context);
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: kGutzoOrange,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: kGutzoOrange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: Center(
              child: Text(
                '+ ADD',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRevenueUpsell(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlassRevenueUpsell(mealTitle: mealTitle),
    );
  }
}

class _GlassRevenueUpsell extends ConsumerWidget {
  final String mealTitle;
  const _GlassRevenueUpsell({required this.mealTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 32),
          Text(
            'COMMIT TO THE RESULT',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: kGutzoGreen),
          ),
          const SizedBox(height: 8),
          Text(
            'Experience Transformation.',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: kDeepText),
          ),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kGutzoGreen.withOpacity(0.05), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kGutzoGreen.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: kGutzoGreen.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.calendar_today_rounded, color: kGutzoGreen, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '5-Day Habit Pack',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '1 $mealTitle per day',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹1,199', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: kDeepText)),
                        Text('₹1,495', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => _showFrictionlessCheckout(context, ref, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGutzoGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('START 5-DAY HABIT', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _showFrictionlessCheckout(context, ref, false),
            child: Text(
              'JUST ONCE FOR ₹299',
              style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  void _showFrictionlessCheckout(BuildContext context, WidgetRef ref, bool isHabit) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FrictionlessCheckout(isHabit: isHabit),
    ).then((_) {
       ref.read(orderPlacedProvider.notifier).state = true;
    });
  }
}

class _FrictionlessCheckout extends StatelessWidget {
  final bool isHabit;
  const _FrictionlessCheckout({required this.isHabit, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 32),
          Text(
            'Where are we delivering your transformation?',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: kDeepText),
          ),
          const SizedBox(height: 24),
          
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(CupertinoPageRoute(
                builder: (context) => const LocationPickScreen(),
              ));
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Text('Detect My Location', style: GoogleFonts.inter(color: Colors.blue, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          Text('PAYMENT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  Text('GPay', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.purple),
                  ),
                  const SizedBox(height: 8),
                  Text('PhonePe', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Colors.lightBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.lightBlue),
                  ),
                  const SizedBox(height: 8),
                  Text('Paytm', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGutzoOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'PAY ₹${isHabit ? "1,199" : "299"} NOW',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
