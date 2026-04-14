import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class DietaryBadge extends StatelessWidget {
  final String dietaryType;
  final double size;
  final bool showLabel;

  const DietaryBadge({
    super.key,
    required this.dietaryType,
    this.size = 12,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (dietaryType.toLowerCase()) {
      case 'vegan':
        color = Colors.teal;
        icon = CupertinoIcons.leaf_arrow_circlepath;
        label = 'VEGAN';
        break;
      case 'egg':
        color = Colors.amber[700]!;
        icon = Icons.circle;
        label = 'EGG';
        break;
      case 'non-veg':
        color = Colors.red;
        icon = Icons.circle;
        label = 'NON-VEG';
        break;
      case 'veg':
      default:
        color = AppColors.brandGreen;
        icon = Icons.circle;
        label = 'VEG';
        break;
    }

    final badge = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: size - 4),
    );

    if (!showLabel) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
