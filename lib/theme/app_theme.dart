import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const surfaceLight = Color(0xFF2A2A2A);
  static const primary = Color(0xFF006D5B);
  static const primaryLight = Color(0xFF00917A);
  static const accent = Color(0xFFD4AF37);
  static const accentLight = Color(0xFFE8C84A);
  static const textPrimary = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFF9E9E9E);
  static const textArabic = Color(0xFFF5F5F5);
  static const divider = Color(0xFF333333);
  static const error = Color(0xFFCF6679);
  static const meccan = Color(0xFF006D5B);
  static const medinan = Color(0xFF1565C0);

  // Light Theme Colors
  static const backgroundLight = Color(0xFFF8F9FA);
  static const surfaceLightT = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF212121);
  static const textSecondaryLight = Color(0xFF757575);
  static const dividerLight = Color(0xFFEEEEEE);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.accent),
      ),
      textTheme: _textTheme(AppColors.textPrimary, AppColors.textSecondary),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surfaceLightT,
        error: AppColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      textTheme: _textTheme(AppColors.textPrimaryLight, AppColors.textSecondaryLight),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
    headlineLarge: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: primary),
    titleLarge: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
    bodyLarge: GoogleFonts.poppins(fontSize: 16, color: primary),
    bodyMedium: GoogleFonts.poppins(fontSize: 14, color: secondary),
  );

  static TextStyle arabicTextStyle(double multiplier) => TextStyle(
    fontFamily: 'Scheherazade',
    fontSize: 28 * multiplier,
    height: 2.0,
    color: AppColors.textArabic,
  );

  static TextStyle translationTextStyle(double multiplier, Brightness brightness) => GoogleFonts.poppins(
    fontSize: 14 * multiplier,
    color: brightness == Brightness.dark ? AppColors.textSecondary : AppColors.textSecondaryLight,
    height: 1.5,
  );

  static TextStyle phoneticTextStyle(double multiplier) => GoogleFonts.poppins(
    fontSize: 13 * multiplier,
    color: AppColors.accent,
    fontStyle: FontStyle.italic,
  );
}
