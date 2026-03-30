import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../orders/orders_history_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.brandGreenLight,
              child: Icon(Icons.person, size: 50, color: AppColors.brandGreen),
            ),
            const SizedBox(height: 16),
            Text(
              user?.phone ?? 'Guest User',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _profileItem(Icons.receipt_long_outlined, 'My Orders', () {
              Navigator.push(context, CupertinoPageRoute(builder: (_) => const OrdersHistoryScreen()));
            }),
            _profileItem(Icons.location_on_outlined, 'My Addresses', () {}),
            _profileItem(Icons.payment_outlined, 'Payment Methods', () {}),
            _profileItem(Icons.help_outline, 'Help & Support', () {}),
            _profileItem(Icons.info_outline, 'About Gutzo', () {}),
            const Divider(height: 32),
            _profileItem(
              Icons.logout, 
              'Logout', 
              () {
                ref.read(authServiceProvider).signOut();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.brandGreen),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
