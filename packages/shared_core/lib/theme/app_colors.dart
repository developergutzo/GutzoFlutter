import 'package:flutter/material.dart';

class AppColors {
  // Brand Constants
  static const Color brandGreen = Color(0xFF1BA672);
  static const Color brandGreenHover = Color(0xFF14885E);
  static const Color brandGreenPressed = Color(0xFF0E6B49);
  static const Color brandGreenLight = Color(0xFFE8F6F1);
  static const Color accentGreen = Color(0xFF2FCC5A);

  // CTA Constants
  static const Color ctaOrange = Color(0xFFE85A1C);
  static const Color ctaOrangeHover = Color(0xFFCC4E17);
  static const Color ctaOrangePressed = Color(0xFFB44414);

  // Error Constants
  static const Color errorRed = Color(0xFFE74C3C);
  static const Color errorBg = Color(0xFFFDECEA);
  static const Color errorBorder = Color(0xFFF5C6CB);

  // Neutrals & UI
  static const Color textMain = Color(0xFF1A1A1A);
  static const Color textSub = Color(0xFF6B6B6B);
  static const Color textDisabled = Color(0xFF9E9E9E);
  static const Color border = Color(0xFFE0E0E0);
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);

  // Shimmer Constants
  static const Color shimmerBase = Color(0xFFF3F4F6);
  static const Color shimmerHighlight = Color(0xFFFFFFFF);

  // Health Filter Colors
  static const Color brandBlue = Color(0xFF0052CC);

  // Web Specific Tokens
  static const Color webGlassBg = Color.fromRGBO(255, 255, 255, 0.85);
  static const Color webGlassBorder = Color.fromRGBO(255, 255, 255, 0.4);
  static const Color webCardShadow = Color.fromRGBO(0, 0, 0, 0.04);
  static const Color webHoverBg = Color(0xFFF8F9FA);
  static const Color webDivider = Color(0xFFF1F5F9);
  
  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
}
