import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/vendor_service.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../auth/auth_sheet.dart';
import '../../widgets/vendor_card.dart';
import '../../widgets/cart_strip.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/services/category_service.dart';
import 'package:shared_core/services/banner_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../orders/orders_history_screen.dart';
import '../profile/profile_screen.dart';

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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Row(
                    children: [
                      const SizedBox(width: 16),
                      // Logo matching web design
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.brandGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'GUTZO',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'Feels Lighter',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      // Profile Button
                      if (currentUser == null)
                        IconButton(
                          icon: const Icon(Icons.person_outline, color: AppColors.textMain),
                          onPressed: () {
                             AuthSheet.show(context);
                          },
                        )
                      else
                        PopupMenuButton<String>(
                          icon: CircleAvatar(
                            backgroundColor: AppColors.brandGreen,
                            radius: 14,
                            child: Text(
                              currentUser.name.isNotEmpty ? currentUser.name[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
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
                                  const Icon(Icons.person_outline, size: 20, color: Color(0xFF374151)),
                                  const SizedBox(width: 12),
                                  Text('My Profile', style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'orders',
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long_outlined, size: 20, color: Color(0xFF374151)),
                                  const SizedBox(width: 12),
                                  Text('My Orders', style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'address',
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF374151)),
                                  const SizedBox(width: 12),
                                  Text('My Address', style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  const Icon(Icons.logout, size: 20, color: Color(0xFF374151)),
                                  const SizedBox(width: 12),
                                  Text('Log Out', style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search & Location Simplified Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: () {
                        ref.read(locationProvider.notifier).refreshLocation();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          ),
                          child: Builder(
                          builder: (context) {
                            final locationState = ref.watch(locationProvider);
                            final areaName = locationState.location?.areaName ?? 'Detecting...';
                            final stateName = locationState.location?.stateName ?? '';
                            return Row(
                              children: [
                                const Icon(Icons.location_on, color: AppColors.brandGreen, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (locationState.isLoading)
                                            const SizedBox(
                                              width: 12, height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.brandGreen),
                                            )
                                          else
                                            Text(areaName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 2),
                                          Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[600]),
                                        ],
                                      ),
                                      if (stateName.isNotEmpty)
                                        Text(stateName, style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
                                    ],
                                  ),
                                ),
                                const VerticalDivider(width: 1, indent: 4, endIndent: 4, color: AppColors.border),
                                const SizedBox(width: 8),
                                const Icon(Icons.search, color: AppColors.textDisabled, size: 20),
                                const SizedBox(width: 8),
                                const Text('Search food...', style: TextStyle(color: AppColors.textDisabled, fontSize: 13)),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Banners section
        bannersAsync.when(
          data: (banners) {
            if (banners.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            final banner = banners.first; // Show first as hero for now
            return SliverToBoxAdapter(
              child: Container(
                height: 200,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(banner.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.bottomLeft,
                  child: const Text(
                    'Healthy Meals\nDelivered Fresh',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => SliverToBoxAdapter(
            child: Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
            ),
          ),
          error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
        
        // Today's Mood (Categories) header
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              "Today's Mood",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111),
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
        categoriesAsync.when(
          data: (categories) => SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFFAFAFA),
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              height: 280,
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return SizedBox(
                    width: 90,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: category.imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(category.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.grey[200],
                          ),
                          child: category.imageUrl == null
                              ? const Icon(Icons.restaurant_menu, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          category.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6B7280),
                            fontFamily: 'Poppins',
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
            child: Container(
              color: const Color(0xFFFAFAFA),
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              height: 280,
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),
                itemCount: 10,
                itemBuilder: (context, index) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
        
        // Vendor List header
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 32, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Kitchens Near You',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111111),
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
        
        // Vendor List placeholder
        vendorsAsync.when(
          data: (vendors) => SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final vendor = vendors[index];
                return VendorCard(
                  imageUrl: vendor.image.isNotEmpty ? vendor.image : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
                  title: vendor.name,
                  cuisine: vendor.cuisineType,
                  deliveryTime: vendor.deliveryTime,
                  rating: vendor.rating,
                  vendorModel: vendor,
                );
              },
              childCount: vendors.length,
            ),
          ),
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
          ),
          error: (err, stack) => SliverFillRemaining(
            child: Center(child: Text('Failed to load vendors: $err')),
          ),
        ),
      ],
    );
  }
}
