import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFFBF3A16);
  static const gradientEnd = Color(0xFFC93A06);
  static const brandDark = Color(0xFF9E2F12);
  static const brand50 = Color(0xFFFDF3EE);
  static const brand100 = Color(0xFFFAE2D6);
  static const brand200 = Color(0xFFF4C3AD);
  static const brand400 = Color(0xFFE06C48);
  static const background = Color(0xFFF4EFE7);
  static const card = Color(0xFFFBF8F3);
  static const line = Color(0xFFE3DBD0);
  static const line2 = Color(0xFFECE5DA);
  static const foreground = Color(0xFF1E1712);
  static const muted = Color(0xFF6B5F55);
  static const muted2 = Color(0xFF9C8D80);
  static const green = Color(0xFF3F5C3A);
  static const greenBg = Color(0xFFEEF4EC);
  static const amber = Color(0xFF9A6413);
  static const amberBg = Color(0xFFFDF3E3);
  static const indigo = Color(0xFF7A6326);
  static const indigoBg = Color(0xFFF2EFE6);
  static const rose = Color(0xFFB3261E);
  static const roseBg = Color(0xFFFDECEB);
}

abstract final class AppTheme {
  static ThemeData get light {
    final text = GoogleFonts.outfitTextTheme().apply(
      bodyColor: AppColors.foreground,
      displayColor: AppColors.foreground,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.card,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.foreground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.muted2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand400),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Keep the global button width finite so buttons remain valid inside
          // Rows, dialog action bars, and list-card trailing areas. Parents
          // that provide tight width constraints still render full-width.
          minimumSize: const Size(64, 50),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.muted2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          disabledForegroundColor: AppColors.muted2,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 2,
        shadowColor: const Color(0x1F1E1712),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }
}
