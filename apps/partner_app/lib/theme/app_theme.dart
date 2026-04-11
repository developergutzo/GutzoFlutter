import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color brandGreen = Color(0xFF1BA672);
  static const Color brandLight = Color(0xFFE8F6F1);
  static const Color brandDark = Color(0xFF14885E);
  
  static const Color background = Color(0xFFFAFAFA);
  static const Color cardBg = Colors.white;
  
  static const Color textMain = Color(0xFF1A1A1A);
  static const Color textSub = Color(0xFF6B6B6B);
  static const Color textDisabled = Color(0xFF9E9E9E);
  
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3498DB);
  
  static const Color border = Color(0xFFEEEEEE);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandGreen,
        primary: AppColors.brandGreen,
        onPrimary: Colors.white,
        secondary: AppColors.brandLight,
        onSecondary: AppColors.brandGreen,
        surface: AppColors.background,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withOpacity(0.8),
        foregroundColor: AppColors.textMain,
        elevation: 0,
        centerTitle: true, // Default to true for HIG/Premium look
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: AppColors.textMain,
          letterSpacing: 1.1,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
