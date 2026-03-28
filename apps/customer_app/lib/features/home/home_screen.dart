import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/vendor_service.dart';
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
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const _MarketplaceBody(),
    const Center(child: Text('Search screen coming soon')),
    const OrdersHistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SafeArea(child: CartStrip()),
          BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            selectedItemColor: AppColors.brandGreen,
            unselectedItemColor: AppColors.textDisabled,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
              BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), label: 'Orders'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
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
                      // Logo
                      SvgPicture.network(
                          "https://gutzo.in/logo.svg",// bring original icon here.
                          height: 32,
                          fit: BoxFit.contain,
                          placeholderBuilder: (context) => const Row(
                            children: [
                              Icon(Icons.shopping_bag_outlined, color: AppColors.brandGreen, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'Gutzo',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandGreen,
                                ),
                              ),
                            ],
                          ),
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
                             }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'profile', child: Text('Profile (${currentUser.name})')),
                            const PopupMenuItem(value: 'logout', child: Text('Logout')),
                          ],
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search & Location Simplified Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        child: const Row(
                          children: [
                            Icon(Icons.location_on, color: AppColors.brandGreen, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('HOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  Text('Coimbatore, Tamil Nadu', style: TextStyle(fontSize: 12, color: AppColors.textSub, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            VerticalDivider(width: 1, indent: 4, endIndent: 4, color: AppColors.border),
                            SizedBox(width: 8),
                            Icon(Icons.search, color: AppColors.textDisabled, size: 20),
                            SizedBox(width: 8),
                            Text('Search food...', style: TextStyle(color: AppColors.textDisabled, fontSize: 13)),
                          ],
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
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              height: 170, // Increased to 170 to be extra safe
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 80,
                          width: 80,
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
                        const SizedBox(height: 8),
                        Text(
                          category.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
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
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              height: 170,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, index) => Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
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
          ),
          error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
        
        // Vendor List header
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 32, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Top rated kitchens near you',
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
