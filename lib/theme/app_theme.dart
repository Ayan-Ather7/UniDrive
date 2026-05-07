import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Ultra-premium dark surfaces (Zinc palette)
  static const Color darkBg = Color(0xFF09090B); // Near absolute black
  static const Color darkCard = Color(0xFF18181B); // Slight elevation
  static const Color darkSurface = Color(0xFF27272A); // Higher elevation inputs
  static const Color darkBorder = Color(0xFF3F3F46); // Subtle dividers

  // Light surfaces (kept for completeness, though app defaults to Dark)
  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color bgGrey = Color(0xFFF4F4F5);

  // Vibrant Premium Brand Accents
  static const Color navy = Color(0xFF1E1B4B); 
  static const Color blue = Color(0xFF0EA5E9); // Vivid Sky Blue
  static const Color cyan = Color(0xFF06B6D4); // Electric Cyan
  static const Color violet = Color(0xFF8B5CF6); // Electric Violet
  static const Color maroon = Color(0xFFBE123C); // Deep Rose
  static const Color maroonLight = Color(0xFFE11D48);
  static const Color orange = Color(0xFFF59E0B); // Amber Driver ratings
  static const Color success = Color(0xFF10B981); // Emerald Match status
  static const Color pink = Color(0xFFEC4899); // Pink Ride

  // Gradient Colors for Logo/Hero
  static const Color gradientStart = violet;
  static const Color gradientEnd = cyan;
  static const List<Color> brandGradient = [gradientStart, gradientEnd];

  // Text Colors
  static const Color textPrimary = Color(0xFF09090B);
  static const Color textPrimaryDark = Color(0xFFFAFAFA);
  static const Color textMuted = Color(0xFFA1A1AA);
}

class AppTheme {
  // Helper for completely borderless softly rounded inputs
  static OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: c, width: w),
      );

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      primaryColor: AppColors.blue,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.cyan,
        surface: AppColors.darkCard,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimaryDark,
      ),
      cardColor: AppColors.darkCard,
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          // A very subtle inner border effect creates a glass-like premium edge
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
        ),
      ),
      dividerColor: AppColors.darkBorder.withValues(alpha: 0.5),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.textPrimaryDark, displayColor: AppColors.textPrimaryDark),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, 
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          side: BorderSide(color: AppColors.darkBorder.withValues(alpha: 0.8)),
          foregroundColor: AppColors.textPrimaryDark,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, 
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface.withValues(alpha: 0.5),
        border: _border(Colors.transparent),
        enabledBorder: _border(Colors.transparent),
        focusedBorder: _border(AppColors.blue.withValues(alpha: 0.5), 1.5),
        errorBorder: _border(AppColors.maroonLight.withValues(alpha: 0.6), 1.5),
        focusedErrorBorder: _border(AppColors.maroonLight, 1.5),
        errorStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.maroonLight,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final border = const Color(0xFFE4E4E7);
    return base.copyWith(
      primaryColor: AppColors.navy,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        secondary: AppColors.cyan,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      cardColor: Colors.white,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05), width: 1),
        ),
      ),
      dividerColor: border,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, 
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          side: BorderSide(color: border),
          foregroundColor: AppColors.textPrimary,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, 
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgGrey,
        border: _border(Colors.transparent),
        enabledBorder: _border(Colors.transparent),
        focusedBorder: _border(AppColors.navy.withValues(alpha: 0.2), 1.5),
        errorBorder: _border(AppColors.maroonLight.withValues(alpha: 0.6), 1.5),
        focusedErrorBorder: _border(AppColors.maroonLight, 1.5),
        errorStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.maroonLight,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
