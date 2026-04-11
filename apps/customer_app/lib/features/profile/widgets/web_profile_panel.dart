import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../profile_screen.dart';
import '../../orders/orders_history_screen.dart';
// ProfilePanelView enum is now imported from profile_screen.dart

class WebProfilePanel extends ConsumerStatefulWidget {
  const WebProfilePanel({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ProfilePanel',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const Align(
          alignment: Alignment.centerRight,
          child: WebProfilePanel(),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutQuart)),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<WebProfilePanel> createState() => _WebProfilePanelState();
}

class _WebProfilePanelState extends ConsumerState<WebProfilePanel> {
  ProfilePanelView _currentView = ProfilePanelView.main;

  void _switchTo(ProfilePanelView view) {
    setState(() => _currentView = view);
  }

  void _switchBack() {
    setState(() => _currentView = ProfilePanelView.main);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 600,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 40,
              offset: Offset(-10, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                children: [
                  if (_currentView != ProfilePanelView.main)
                    IconButton(
                      onPressed: _switchBack,
                      icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
                    ),
                  Text(
                    _getTitle(),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textDisabled, size: 28),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildCurrentView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_currentView) {
      case ProfilePanelView.main:
        return 'My Profile';
      case ProfilePanelView.edit:
        return 'Edit Profile';
      case ProfilePanelView.settings:
        return 'Settings';
      case ProfilePanelView.orders:
        return 'Order History';
      case ProfilePanelView.help:
        return 'Help & Support';
      case ProfilePanelView.about:
        return 'About Gutzo';
    }
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case ProfilePanelView.main:
        return ProfileScreen(
          isEmbedded: true,
          onNavigate: (view) => _switchTo(view),
        );
      case ProfilePanelView.edit:
        return ProfileEditView(
          isEmbedded: true,
          onBack: _switchBack,
        );
      case ProfilePanelView.settings:
        return ProfileSettingsView(
          isEmbedded: true,
          onBack: _switchBack,
        );
      case ProfilePanelView.orders:
        return const OrdersHistoryScreen(isEmbedded: true);
      case ProfilePanelView.help:
        return ProfileHelpView(isEmbedded: true);
      case ProfilePanelView.about:
        return ProfileAboutView(isEmbedded: true);
    }
  }
}
