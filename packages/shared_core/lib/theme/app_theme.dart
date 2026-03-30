import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandGreen,
        secondary: AppColors.ctaOrange,
        surface: AppColors.surface,
        error: AppColors.errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textMain,
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme(
        TextTheme(
          displayLarge: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: AppColors.textMain, fontSize: 16),
          bodyMedium: TextStyle(color: AppColors.textSub, fontSize: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
