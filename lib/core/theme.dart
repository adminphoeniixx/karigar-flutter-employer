import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFFF4470F);
  static const brandDark = Color(0xFFC93A06);
  static const brand50 = Color(0xFFFFF3EE);
  static const brand100 = Color(0xFFFFE3D8);
  static const brand200 = Color(0xFFFFC5B0);
  static const background = Color(0xFFF6F7F9);
  static const card = Colors.white;
  static const line = Color(0xFFE9EBEF);
  static const line2 = Color(0xFFF0F1F4);
  static const foreground = Color(0xFF16181D);
  static const muted = Color(0xFF6B7280);
  static const muted2 = Color(0xFF9AA1AD);
  static const green = Color(0xFF047857);
  static const greenBg = Color(0xFFECFDF5);
  static const amber = Color(0xFFB45309);
  static const amberBg = Color(0xFFFFF7ED);
  static const indigo = Color(0xFF4F46E5);
  static const indigoBg = Color(0xFFEEF2FF);
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
          borderSide: const BorderSide(color: AppColors.primary),
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
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }
}
