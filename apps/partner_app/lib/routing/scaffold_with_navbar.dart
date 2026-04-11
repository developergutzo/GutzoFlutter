import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../common/widgets/loading_overlay.dart';
import '../common/providers/loading_provider.dart';
import '../features/auth/vendor_provider.dart';
import 'package:shared_core/services/auth_service.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(globalLoadingProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    Widget content;
    if (isDesktop) {
      content = _buildWebDesktopScaffold(context);
    } else {
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      content = isIOS ? _buildCupertinoScaffold() : _buildMaterialScaffold(context);
    }

    return LoadingOverlay(
      isLoading: isLoading,
      child: content,
    );
  }

  Widget _buildWebDesktopScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          _WebSidebar(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
          ),
          Expanded(
            child: ClipRRect(
              child: navigationShell,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoScaffold() {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        activeColor: AppColors.brandGreen,
        inactiveColor: CupertinoColors.systemGrey,
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.8),
        items: [
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), activeIcon: Icon(CupertinoIcons.house_fill), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), activeIcon: Icon(CupertinoIcons.list_bullet), label: 'Orders'),
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.square_grid_2x2), label: 'Menu'),
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), activeIcon: Icon(CupertinoIcons.person_fill), label: 'Profile'),
        ],
      ),
      tabBuilder: (context, index) => navigationShell,
    );
  }

  Widget _buildMaterialScaffold(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        indicatorColor: AppColors.brandGreen.withOpacity(0.15),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Menu'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _WebSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _WebSidebar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandGreen, AppColors.brandGreen.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: AppColors.brandGreen.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GUTZO',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMain,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'PARTNER',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandGreen,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildSectionHeader('GENERAL'),
          _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined, Icons.dashboard),
          const SizedBox(height: 24),
          _buildSectionHeader('MANAGEMENT'),
          _buildNavItem(1, 'Orders', Icons.list_alt_outlined, Icons.list_alt),
          _buildNavItem(2, 'Price List', Icons.restaurant_menu_outlined, Icons.restaurant_menu),
          _buildNavItem(3, 'Settings', Icons.person_outline, Icons.person),
          const Spacer(),
          _buildProfileFooter(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 24, 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textDisabled,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, IconData activeIcon) {
    final isSelected = currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.brandGreen.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppColors.brandGreen : AppColors.textSub,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.brandGreen : AppColors.textSub,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.brandGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileFooter(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final vendor = ref.watch(vendorProvider).value;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.brandGreen.withOpacity(0.1),
                    child: Text(
                      vendor?.name.isNotEmpty == true ? vendor!.name[0].toUpperCase() : 'P',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.brandGreen, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor?.name ?? 'Partner',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textMain),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${vendor?.id.substring(0, 8).toUpperCase() ?? '...'}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 10, color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  ref.read(authServiceProvider).signOut();
                  ref.read(vendorProvider.notifier).logout();
                },
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 16, color: AppColors.errorRed),
                    const SizedBox(width: 8),
                    Text(
                      'Logout Session',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.errorRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
