import 'package:flutter/material.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'auth_content.dart';

class WebAuthPanel extends StatelessWidget {
  const WebAuthPanel({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AuthPanel',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const Align(
          alignment: Alignment.centerRight,
          child: WebAuthPanel(),
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
            // Close Button Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textDisabled, size: 28),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: SingleChildScrollView(
                child: AuthContent(isPanel: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
