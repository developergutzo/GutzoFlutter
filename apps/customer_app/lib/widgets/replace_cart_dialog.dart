import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/theme/app_colors.dart';

import 'modern_dialog.dart';

class ReplaceCartDialog extends StatelessWidget {
  final String oldVendorName;
  final String newVendorName;
  final VoidCallback onReplace;

  const ReplaceCartDialog({
    super.key,
    required this.oldVendorName,
    required this.newVendorName,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return ModernDialog(
      title: 'Replace cart item?',
      primaryLabel: 'Replace',
      secondaryLabel: 'Cancel',
      isDestructive: true,
      onPrimary: () {
        Navigator.pop(context);
        onReplace();
      },
      content: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: AppColors.textSub,
            height: 1.6,
          ),
          children: [
            const TextSpan(text: 'Your cart contains items from '),
            TextSpan(
              text: oldVendorName,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMain),
            ),
            const TextSpan(text: '. Clear cart to add from '),
            TextSpan(
              text: newVendorName,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMain),
            ),
            const TextSpan(text: '?'),
          ],
        ),
      ),
    );
  }
}
