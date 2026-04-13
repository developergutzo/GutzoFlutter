import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../profile/profile_screen.dart';
import '../profile/widgets/web_profile_panel.dart';
import 'widgets/location_sheet.dart';
import 'widgets/search_sheet.dart';

final homeFilterProvider = StateProvider<String>((ref) => 'All');
final locationAutoPromptProvider = StateNotifierProvider<LocationPromptNotifier, bool>((ref) => LocationPromptNotifier());

class LocationPromptNotifier extends StateNotifier<bool> {
  LocationPromptNotifier() : super(false);
  void setPrompted() => state = true;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _MarketplaceBody(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CartStrip(filterHabit: true, isPremium: true),
                CartStrip(filterHabit: false, isPremium: true),
              ],
            ),
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
    ref.watch(locationSyncProvider);

    final currentUser = ref.watch(currentUserProvider);
    final vendorsAsync = ref.watch(vendorProvider);
    final selectedFilter = ref.watch(homeFilterProvider);
    
    final goalsMapping = {
      'All': 'All',
      'Flat Tummy': 'Low Calorie',
      'Muscle Gain': 'High Protein',
      'Skin Glow': 'High Fiber',
      'Clinical/Sugar': 'Sugar Free',
    };
    final backendFilter = goalsMapping[selectedFilter] ?? 'All';

    final filteredDishesAsync = vendorsAsync.whenData((vendors) {
      final List<Map<String, dynamic>> items = [];
      final filter = backendFilter.toLowerCase();
      
      for (final v in vendors) {
        // 🛡️ Discovery Logic: Show all kitchens (unserviceable ones will have a card overlay)
        
        if (v.products == null) continue;
        for (final p in v.products!) {
          final nameMatch = p.name.toLowerCase().contains(filter);
          final descMatch = p.description.toLowerCase().contains(filter);
          final tagMatch = p.tags?.any((t) => t.toLowerCase().contains(filter)) ?? false;
          final cuisineMatch = v.cuisineType.toLowerCase().contains(filter);
          
          if (filter == 'all' || nameMatch || descMatch || tagMatch || cuisineMatch) {
            items.add({'product': p, 'vendor': v});
          }
        }
      }
      return items;
    });

    final bannersAsync = ref.watch(bannersProvider);

    return Responsive(
      mobile: _buildMobileBase(context, ref, bannersAsync, filteredDishesAsync, currentUser),
      desktop: _buildWebBase(context, ref, bannersAsync, filteredDishesAsync, currentUser),
    );
  }

  Widget _buildMobileBase(BuildContext context, WidgetRef ref, AsyncValue bannersAsync, AsyncValue<List<Map<String, dynamic>>> filteredDishesAsync, dynamic currentUser) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildMobileHeader(context, ref, currentUser),
              const _FilterChipsRow(),
              _buildBannersSection(bannersAsync),
              _buildDishGridMobile(filteredDishesAsync, ref),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDishGridMobile(AsyncValue<List<Map<String, dynamic>>> dishesAsync, WidgetRef ref) {
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
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

  Widget _buildWebBase(BuildContext context, WidgetRef ref, AsyncValue bannersAsync, AsyncValue filteredDishesAsync, dynamic currentUser) {
    return SingleChildScrollView(
      child: MaxWidthContainer(
        child: Column(
          children: [
            const _FilterChipsRow(),
            _buildBannersSection(bannersAsync),
            Padding(
              padding: const EdgeInsets.all(32),
              child: _buildDishGridWeb(filteredDishesAsync, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishGridWeb(AsyncValue dishesAsync, WidgetRef ref) {
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
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow();
  static const Map<String, String> goalMapping = {
    'All': 'All',
    'Flat Tummy': 'Low Calorie',
    'Muscle Gain': 'High Protein',
    'Skin Glow': 'High Fiber',
    'Clinical/Sugar': 'Sugar Free',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGoal = ref.watch(homeFilterProvider);
    final goals = goalMapping.keys.toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final isSelected = selectedGoal == goal;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: InkWell(
                    onTap: () => ref.read(homeFilterProvider.notifier).state = goal,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.brandGreen : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? AppColors.brandGreen : AppColors.border, width: 1.5),
                      ),
                      child: Text(goal, style: TextStyle(color: isSelected ? Colors.white : AppColors.textMain, fontSize: 13, fontWeight: FontWeight.w800)),
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
