import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/vendor_service.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../auth/auth_screen.dart';
import '../../widgets/vendor_card.dart';
import '../../widgets/cart_strip.dart';
import 'package:shared_core/services/category_service.dart';
import 'package:shared_core/services/mood_category_service.dart';
import 'package:shared_core/services/banner_service.dart';
import 'package:shimmer/shimmer.dart';

import '../profile/profile_screen.dart';
import 'widgets/location_sheet.dart';
import 'widgets/search_sheet.dart';
import '../search/search_results_screen.dart';
import '../../providers/location_sync_provider.dart';

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
    return Scaffold(
      body: Stack(
        children: [
          const _MarketplaceBody(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(child: const CartStrip(isPremium: true)),
          ),
        ],
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

    return CustomScrollView(
      slivers: [
        // Sticky Header (like Header.tsx)
        SliverAppBar(
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
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (_) => const ProfileScreen()),
                            ),
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
        ),
        
        // Banners section (Mobile Carousel)
        bannersAsync.when(
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
        ),
        
        // Today's Mood (Categories) header
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              "Today's Mood",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),

        // Categories (Dynamic Row Horizontal Scroll)
        moodCategoriesAsync.when(
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
                        Container(
                          height: 75,
                          width: 75,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
        
        // Health Category Filters
        const _FilterChipsRow(),
        
        // Kitchens Near You Header
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 24, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Kitchens Near You',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        
        vendorsAsync.when(
          data: (vendors) {
            final selectedFilter = ref.watch(homeFilterProvider);
            final filteredVendors = vendors.where((v) {
              if (selectedFilter == 'All') return true;
              return v.tags?.any((tag) => tag.toLowerCase().contains(selectedFilter.toLowerCase())) ?? false;
            }).toList();

            if (filteredVendors.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No kitchens found for this category yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final vendor = filteredVendors[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: VendorCard(
                      imageUrl: vendor.image.isNotEmpty ? vendor.image : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
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
          loading: () => SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Shimmer.fromColors(
                  baseColor: AppColors.shimmerBase,
                  highlightColor: AppColors.shimmerHighlight,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              childCount: 3,
            ),
          ),
          error: (err, stack) => SliverToBoxAdapter(
            child: Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodItem(BuildContext context, dynamic mood) {
    // Handle both model and legacy strings if needed, but here we expect MoodCategory or similar
    final String label = mood.name;
    final String imageUrl = mood.imageUrl;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchResultsScreen(initialQuery: label),
          ),
        );
      },
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 75,
              width: 75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.restaurant, color: AppColors.brandGreen, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(homeFilterProvider);
    final filters = [
      'All',
      'High Protein',
      'Low Calorie',
      'High Fibre',
      'Gut Friendly',
      'Detox',
      'Post Workout'
    ];

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
  }
}
