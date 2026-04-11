import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/vendor_service.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../auth/auth_screen.dart';
import '../auth/web_auth_panel.dart';
import '../../widgets/vendor_card.dart';
import '../../widgets/cart_strip.dart';
import 'package:shared_core/services/category_service.dart';
import 'package:shared_core/services/mood_category_service.dart';
import 'package:shared_core/services/banner_service.dart';
import 'package:shimmer/shimmer.dart';

import '../profile/profile_screen.dart';
import 'widgets/location_sheet.dart';
import 'widgets/web_location_panel.dart';
import '../profile/widgets/web_profile_panel.dart';
import 'widgets/search_sheet.dart';
import 'package:shared_core/utils/responsive.dart';
import 'package:shared_core/widgets/max_width_container.dart';
import '../../providers/location_sync_provider.dart';
import '../../providers/health_filters_provider.dart';

import 'dart:ui' as ui; // For backdrop filter

final homeFilterProvider = NotifierProvider<HomeFilterNotifier, String>(() {
  return HomeFilterNotifier();
});

// Track if we've already auto-prompted for location in this session
final locationAutoPromptProvider = NotifierProvider<AutoPromptNotifier, bool>(() {
  return AutoPromptNotifier();
});

class AutoPromptNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void setPrompted() {
    state = true;
  }
}

class HomeFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setFilter(String filter) { 
    state = filter;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop || context.isTablet;
    
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: isDesktop ? _buildWebNavbar(context, ref, ref.watch(currentUserProvider)) : null,
      body: const Stack(
        children: [
          Positioned.fill(child: _MarketplaceBody()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CartStrip(isPremium: true),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildWebNavbar(BuildContext context, WidgetRef ref, dynamic currentUser) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: MaxWidthContainer(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                   // Logo
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('G', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'GUTZO',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMain,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  // Location Selector (Desktop Style)
                  Flexible(
                    flex: 2,
                    child: _buildWebLocationButton(context, ref),
                  ),
                  const SizedBox(width: 8),
                  const Spacer(),

                  // Search Bar (Flexible for desktop)
                  Flexible(
                    flex: 3,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: InkWell(
                        onTap: () => SearchSheet.show(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: AppColors.textDisabled, size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Search for kitchens or mood...',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppColors.textDisabled, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Profile/Auth
                  if (currentUser == null)
                    ElevatedButton(
                      onPressed: () {
                        if (context.isDesktop || context.isTablet) {
                          WebAuthPanel.show(context);
                        } else {
                          Navigator.push(context, CupertinoPageRoute(builder: (_) => const AuthScreen()));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        backgroundColor: AppColors.brandGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'Login / Signup', 
                        style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)
                      ),
                    )
                  else
                    InkWell(
                      onTap: () {
                        if (context.isDesktop || context.isTablet) {
                          WebProfilePanel.show(context);
                        } else {
                          Navigator.push(context, CupertinoPageRoute(builder: (_) => const ProfileScreen()));
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(color: AppColors.brandGreenLight, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                currentUser.initials,
                                style: const TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentUser.name ?? 'User', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              const Text('My Profile', style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebLocationButton(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final isOff = locationState.error == 'LOCATION_OFF';
    final areaName = isOff ? 'Location Off' : (locationState.location?.tag ?? locationState.location?.areaName ?? 'Detecting...');
    return InkWell(
      onTap: () {
        if (isOff) {
          LocationService.openLocationSettings();
        } else if (context.isDesktop || context.isTablet) {
          WebLocationPanel.show(context);
        } else {
          LocationSheet.show(context);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isOff ? Icons.location_off_outlined : Icons.location_on_outlined, 
                 color: isOff ? AppColors.errorRed : AppColors.brandGreen, size: 22),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(areaName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(locationState.location?.formattedAddress ?? 'Select your delivery address',
                       style: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
                       maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textDisabled, size: 20),
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
    // 📍 Sync location from database if logged in
    ref.watch(locationSyncProvider);

    final currentUser = ref.watch(currentUserProvider);
    final vendorsAsync = ref.watch(vendorProvider);
    final bannersAsync = ref.watch(bannersProvider);
    final moodCategoriesAsync = ref.watch(moodCategoriesProvider);

    // 📍 Auto-listen for LOCATION_OFF and prompt turn on
    ref.listen(locationProvider, (previous, next) async {
      if (next.error == 'LOCATION_OFF' && !ref.read(locationAutoPromptProvider)) {
        ref.read(locationAutoPromptProvider.notifier).setPrompted();
        // Trigger native "Turn on Location" system dialog
        await LocationService.openLocationSettings();
        // Manually trigger a refresh after the dialog closes to ensure immediate feedback
        ref.read(locationProvider.notifier).refreshLocation();
      }
    });

    return Responsive(
      mobile: _buildMobileBase(context, ref, bannersAsync, moodCategoriesAsync, vendorsAsync, currentUser),
      desktop: _buildWebBase(context, ref, bannersAsync, moodCategoriesAsync, vendorsAsync, currentUser),
    );
  }

  Widget _buildMobileBase(BuildContext context, WidgetRef ref, AsyncValue bannersAsync, AsyncValue moodCategoriesAsync, AsyncValue vendorsAsync, dynamic currentUser) {
    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate vendors to trigger a fresh Shadowfax check
        ref.invalidate(vendorProvider);
        // Wait for the new fetch to complete
        await ref.read(vendorProvider.notifier).refresh();
      },
      color: AppColors.brandGreen,
      backgroundColor: Colors.white,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Ensure we can always pull to refresh
        slivers: [
          _buildMobileHeader(context, ref, currentUser),
        _buildBannersSection(bannersAsync),
        _buildMoodHeader(),
        _buildMoodCategories(moodCategoriesAsync),
        const _FilterChipsRow(),
        _buildVendorsHeader(),
        _buildVendorsList(vendorsAsync, ref),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    ),
  );
}

  Widget _buildWebBase(BuildContext context, WidgetRef ref, AsyncValue bannersAsync, AsyncValue moodCategoriesAsync, AsyncValue vendorsAsync, dynamic currentUser) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          MaxWidthContainer(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Banners (High-Impact Web Section)
                _buildWebBanners(bannersAsync),
                const SizedBox(height: 56),

                // Today's Mood (Animated Bento Carousel)
                Row(
                  children: [
                    _buildMoodHeader(isWeb: true),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.brandGreen, size: 24),
                  ],
                ),
                const SizedBox(height: 24),
                _buildMoodCarousel(moodCategoriesAsync),
                const SizedBox(height: 72),

                // Kitchens Section (The "Bento" Grid)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildVendorsHeader(isWeb: true),
                    const Spacer(),
                    const Flexible(
                      flex: 2,
                      child: _WebFilterRow(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildVendorsGrid(vendorsAsync, ref),
                const SizedBox(height: 160),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context, WidgetRef ref, dynamic currentUser) {
    return SliverAppBar(
          floating: true,
          pinned: true,
          toolbarHeight: 110,
          backgroundColor: AppColors.surface,
          elevation: 1,
          flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Branding Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        // Logo matching web design
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'GUTZO',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMain,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Search Button (Optimized Hit Target for 1-Tap responsiveness)
                        GestureDetector(
                          onTap: () => SearchSheet.show(context),
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Icon(Icons.search, color: AppColors.textMain, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Profile Button
                        if (currentUser == null)
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const AuthScreen()),
                            ).then((_) => ref.invalidate(currentUserProvider)),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.1)),
                              ),
                              child: const Center(
                                child: Icon(Icons.person_outline, color: AppColors.brandGreen, size: 20),
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () {
                              if (context.isDesktop || context.isTablet) {
                                WebProfilePanel.show(context);
                              } else {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const ProfileScreen()),
                                );
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.1)),
                              ),
                              child: Center(
                                child: Text(
                                  currentUser.initials,
                                  style: const TextStyle(
                                    color: AppColors.brandGreen,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Action Row: Location (Now single item row)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Builder(
                        builder: (context) {
                          final locationState = ref.watch(locationProvider);
                          final bool isLocationOff = locationState.error == 'LOCATION_OFF';
                          
                          final areaName = isLocationOff ? 'Location Off' : (locationState.location?.tag ?? locationState.location?.areaName ?? 'Detecting...');
                          final fullAddress = isLocationOff ? 'Tap to turn on' : (locationState.location?.formattedAddress ?? 'Searching for address...');

                          return InkWell(
                            onTap: () async {
                              if (isLocationOff) {
                                await LocationService.openLocationSettings();
                                // Trigger a refresh after the prompt
                                ref.read(locationProvider.notifier).refreshLocation();
                              } else {
                                LocationSheet.show(context);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    isLocationOff ? Icons.location_off_outlined : Icons.location_on_outlined, 
                                    color: isLocationOff ? AppColors.errorRed : AppColors.brandGreen, 
                                    size: 24
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            areaName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: isLocationOff ? AppColors.errorRed : AppColors.textMain,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textDisabled),
                                        ],
                                      ),
                                      Text(
                                        fullAddress,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textDisabled,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildBannersSection(AsyncValue bannersAsync) {
    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: PageView.builder(
              itemCount: banners.length,
              controller: PageController(viewportFraction: 0.92),
              itemBuilder: (context, index) {
                final banner = banners[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: NetworkImage(banner.imageUrl),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.bottomLeft,
                    child: const Text(
                      'Healthy Meals\nDelivered Fresh',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => SliverToBoxAdapter(
        child: Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 168,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildWebBanners(AsyncValue bannersAsync) {
    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 440,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.96),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    )
                  ],
                  image: DecorationImage(
                    image: NetworkImage(banner.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(64),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'FEATURED',
                                style: TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5),
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Pure. Nutritious.\nDeliciously Gutzo.',
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Curated meals from certified home-kitchens,\ndelivered with love to your doorstep.',
                              style: TextStyle(color: Colors.white70, fontSize: 20, height: 1.5, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 48),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Explore Kitchens', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                  SizedBox(width: 12),
                                  Icon(Icons.arrow_forward_rounded, size: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => Container(height: 380, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(24))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMoodHeader({bool isWeb = false}) {
    final text = Text(
      "Today's Mood",
      style: TextStyle(
        fontSize: isWeb ? 28 : 19,
        fontWeight: FontWeight.w900,
        color: AppColors.textMain,
        letterSpacing: -1,
      ),
    );
    if (!isWeb) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
        sliver: SliverToBoxAdapter(child: text),
      );
    }
    return text;
  }

  Widget _buildMoodCategories(AsyncValue moodCategoriesAsync) {
    return moodCategoriesAsync.when(
      data: (moodCategories) => SliverToBoxAdapter(
        child: SizedBox(
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: moodCategories.length,
            itemBuilder: (context, index) {
              return _buildMoodItem(context, moodCategories[index]);
            },
          ),
        ),
      ),
      loading: () => SliverToBoxAdapter(
        child: SizedBox(
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Shimmer.fromColors(
                baseColor: AppColors.shimmerBase,
                highlightColor: AppColors.shimmerHighlight,
                child: Column(
                  children: [
                    Container(height: 75, width: 75, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                    const SizedBox(height: 10),
                    Container(height: 12, width: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildMoodCarousel(AsyncValue moodCategoriesAsync) {
    return moodCategoriesAsync.when(
      data: (moodCategories) => _WebMoodCarousel(moodCategories: moodCategories),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }


  Widget _buildVendorsHeader({bool isWeb = false}) {
    final text = Text(
      'Kitchens Near You',
      style: TextStyle(
        fontSize: isWeb ? 28 : 19,
        fontWeight: FontWeight.w900,
        color: AppColors.textMain,
        letterSpacing: -1,
      ),
    );
    if (!isWeb) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
        sliver: SliverToBoxAdapter(child: text),
      );
    }
    return text;
  }

  Widget _buildVendorsList(AsyncValue vendorsAsync, WidgetRef ref) {
    return vendorsAsync.when(
      data: (vendors) {
        final selectedFilter = ref.watch(homeFilterProvider);
        final filteredVendors = (vendors as List<Vendor>).where((Vendor v) {
          if (selectedFilter == 'All') return true;
          final bool matches = v.tags?.any((tag) => tag.toLowerCase().contains(selectedFilter.toLowerCase())) ?? false;
          return matches;
        }).toList();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final vendor = filteredVendors[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: VendorCard(
                  imageUrl: vendor.image,
                  title: vendor.name,
                  cuisine: vendor.cuisineType,
                  deliveryTime: vendor.deliveryTime,
                  rating: vendor.rating,
                  vendorModel: vendor,
                ),
              );
            },
            childCount: filteredVendors.length,
          ),
        );
      },
      loading: () => SliverToBoxAdapter(child: Container(height: 200, color: AppColors.shimmerBase)),
      error: (err, stack) => SliverToBoxAdapter(child: Text('Error: $err')),
    );
  }

  Widget _buildVendorsGrid(AsyncValue vendorsAsync, WidgetRef ref) {
    return vendorsAsync.when(
      data: (vendors) {
        final selectedFilter = ref.watch(homeFilterProvider);
        final filteredVendors = (vendors as List<Vendor>).where((Vendor v) {
          if (selectedFilter == 'All') return true;
          final bool matches = v.tags?.any((tag) => tag.toLowerCase().contains(selectedFilter.toLowerCase())) ?? false;
          return matches;
        }).toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisSpacing: 32,
            crossAxisSpacing: 32,
            mainAxisExtent: 360,
          ),
          itemCount: filteredVendors.length,
          itemBuilder: (context, index) => VendorCard(
            imageUrl: filteredVendors[index].image,
            title: filteredVendors[index].name,
            cuisine: filteredVendors[index].cuisineType,
            deliveryTime: filteredVendors[index].deliveryTime,
            rating: filteredVendors[index].rating,
            vendorModel: filteredVendors[index],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildWebMoodItem(BuildContext context, dynamic mood) {
    return _AnimatedBentoCard(mood: mood);
  }

  Widget _buildMoodItem(BuildContext context, dynamic mood) {
    final String label = mood.name;
    final String imageUrl = mood.imageUrl;
    return InkWell(
      onTap: () {},
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 75,
              width: 75,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))]),
              child: ClipOval(child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: AppColors.brandGreen, size: 30))),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _WebFilterRow extends ConsumerWidget {
  const _WebFilterRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(homeFilterProvider);
    final filtersAsync = ref.watch(healthFiltersProvider);
    return filtersAsync.when(
      data: (healthFilters) {
        final filters = ['All', ...healthFilters.map((e) => e.name)];
        return SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected = selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: ActionChip(
                  label: Text(filter, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  onPressed: () => ref.read(homeFilterProvider.notifier).setFilter(filter),
                  backgroundColor: isSelected ? AppColors.brandGreen : Colors.white,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textMain),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(homeFilterProvider);
    final filtersAsync = ref.watch(healthFiltersProvider);

    return filtersAsync.when(
      data: (healthFilters) {
        final filters = ['All', ...healthFilters.map((e) => e.name)];

        return SliverPadding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected = selectedFilter == filter;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: InkWell(
                    onTap: () => ref.read(homeFilterProvider.notifier).setFilter(filter),
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.brandGreen : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isSelected ? AppColors.brandGreen : Colors.grey.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.brandGreen.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textMain,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
      },
      loading: () => SliverPadding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        sliver: SliverToBoxAdapter(
          child: SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Shimmer.fromColors(
                    baseColor: AppColors.shimmerBase,
                    highlightColor: AppColors.shimmerHighlight,
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class _AnimatedBentoCard extends StatefulWidget {
  final dynamic mood;
  const _AnimatedBentoCard({required this.mood});

  @override
  State<_AnimatedBentoCard> createState() => _AnimatedBentoCardState();
}

class _AnimatedBentoCardState extends State<_AnimatedBentoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 220,
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHovered ? AppColors.brandGreen.withValues(alpha: 0.3) : AppColors.webGlassBorder,
              width: 1.5,
            ),
            boxShadow: _isHovered 
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 15))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandGreenLight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            widget.mood.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Text(
                          widget.mood.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: _isHovered ? AppColors.brandGreen : AppColors.textMain,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isHovered)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebMoodCarousel extends StatefulWidget {
  final List<dynamic> moodCategories;
  const _WebMoodCarousel({required this.moodCategories});

  @override
  State<_WebMoodCarousel> createState() => _WebMoodCarouselState();
}

class _WebMoodCarouselState extends State<_WebMoodCarousel> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
  }

  void _updateArrows() {
    setState(() {
      _showLeftArrow = _scrollController.position.pixels > 20;
      _showRightArrow = _scrollController.position.pixels < _scrollController.position.maxScrollExtent - 20;
    });
  }

  void _scroll(bool left) {
    final double offset = left ? -600 : 600;
    _scrollController.animateTo(
      _scrollController.offset + offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 280,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.moodCategories.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 24),
              child: _AnimatedBentoCard(mood: widget.moodCategories[index]),
            ),
          ),
        ),
        if (_showLeftArrow)
          Positioned(
            left: -20,
            top: 0,
            bottom: 0,
            child: Center(
              child: _CarouselNavButton(icon: Icons.chevron_left, onPressed: () => _scroll(true)),
            ),
          ),
        if (_showRightArrow)
          Positioned(
            right: -20,
            top: 0,
            bottom: 0,
            child: Center(
              child: _CarouselNavButton(icon: Icons.chevron_right, onPressed: () => _scroll(false)),
            ),
          ),
      ],
    );
  }
}

class _CarouselNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _CarouselNavButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.brandGreen),
        onPressed: onPressed,
      ),
    );
  }
}

