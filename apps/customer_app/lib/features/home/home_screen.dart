import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/vendor_service.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import '../auth/auth_screen.dart';
import '../../widgets/vendor_card.dart';
import '../../widgets/cart_strip.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/services/category_service.dart';
import 'package:shared_core/services/banner_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

import '../orders/orders_history_screen.dart';
import '../profile/profile_screen.dart';
import 'widgets/location_sheet.dart';
import 'widgets/search_sheet.dart';

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
            child: SafeArea(child: const CartStrip()),
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
    final currentUser = ref.watch(currentUserProvider);
    final vendorsAsync = ref.watch(vendorProvider);
    final bannersAsync = ref.watch(bannersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return CustomScrollView(
      slivers: [
        // Sticky Header (like Header.tsx)
        SliverAppBar(
          floating: true,
          pinned: true,
          toolbarHeight: 120,
          backgroundColor: AppColors.surface,
          elevation: 1,
          flexibleSpace: FlexibleSpaceBar(
            background: Column(
              children: [
                const SizedBox(height: 12),
                // Branding Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        PopupMenuButton<String>(
                          offset: const Offset(0, 45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          icon: Container(
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
                          onSelected: (val) {
                            if (val == 'logout') {
                              ref.read(authServiceProvider).signOut();
                            } else if (val == 'profile') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                            } else if (val == 'orders') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersHistoryScreen()));
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'profile',
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 20, color: AppColors.textMain),
                                  const SizedBox(width: 12),
                                  const Text('My Profile'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'orders',
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.textMain),
                                  const SizedBox(width: 12),
                                  const Text('My Orders'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  const Icon(Icons.logout, size: 20, color: AppColors.errorRed),
                                  const SizedBox(width: 12),
                                  const Text('Log Out', style: TextStyle(color: AppColors.errorRed)),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                // Action Row: Location (Now single item row)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: InkWell(
                    onTap: () => LocationSheet.show(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Builder(
                      builder: (context) {
                        final locationState = ref.watch(locationProvider);
                        final areaName = locationState.location?.areaName ?? 'Detecting...';
                        final fullAddress = locationState.location?.formattedAddress ?? 'Searching for address...';
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: const Icon(Icons.location_on_outlined, color: AppColors.brandGreen, size: 24),
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
                                        areaName == 'Detecting...' ? areaName : 'Home', // Mocking "Home" as per image
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textMain,
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
                        );
                      },
                    ),
                  ),
                ),
              ],
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

        // Categories (2-Row Horizontal Scroll)
        categoriesAsync.when(
          data: (categories) => SliverToBoxAdapter(
            child: SizedBox(
              height: 220, // Adjusted for 2 rows
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return InkWell(
                    onTap: () {
                      // Handle category tap
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 70,
                          width: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: category.imageUrl != null
                                ? Image.network(
                                    category.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: AppColors.brandGreen),
                                  )
                                : const Icon(Icons.restaurant, color: AppColors.brandGreen),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          loading: () => SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: Shimmer.fromColors(
                baseColor: AppColors.shimmerBase,
                highlightColor: AppColors.shimmerHighlight,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: 8,
                  itemBuilder: (context, index) => Column(
                    children: [
                      Container(height: 70, width: 70, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(height: 8),
                      Container(height: 10, width: 45, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
        
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
          data: (vendors) => SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final vendor = vendors[index];
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
              childCount: vendors.length,
            ),
          ),
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
}
