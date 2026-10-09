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
  // Keep the visual hierarchy compact and predictable across every screen.
  // Individual screens may still opt into a larger style for a true hero title.
  static TextTheme _standardTextTheme(TextTheme base) => base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w700,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 16),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 14),
    bodySmall: base.bodySmall?.copyWith(fontSize: 12),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );

  static ButtonStyle _filledButtonStyle(TextTheme text) =>
      FilledButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: text.labelLarge,
        disabledBackgroundColor: AppColors.line,
        disabledForegroundColor: AppColors.muted2,
      );

  static ButtonStyle _outlinedButtonStyle(
    TextTheme text, {
    Color foreground = AppColors.foreground,
    Color side = AppColors.line,
  }) => OutlinedButton.styleFrom(
    minimumSize: const Size(64, 44),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    foregroundColor: foreground,
    side: BorderSide(color: side),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: text.labelLarge,
    disabledForegroundColor: AppColors.muted2,
  );

  static ThemeData get light {
    final text = _standardTextTheme(
      GoogleFonts.outfitTextTheme().apply(
        bodyColor: AppColors.foreground,
        displayColor: AppColors.foreground,
      ),
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
      filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle(text)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(text),
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

  static ThemeData get dark {
    final text = _standardTextTheme(
      GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: const Color(0xFFF6EFE8),
        displayColor: const Color(0xFFF6EFE8),
      ),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppColors.primary,
        primary: const Color(0xFFFFB39A),
        surface: const Color(0xFF201A16),
      ),
      scaffoldBackgroundColor: const Color(0xFF17120F),
      textTheme: text,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: const Color(0xFF201A16),
        foregroundColor: const Color(0xFFF6EFE8),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF201A16),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: const Color(0xFFB8AAA0)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle(text)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(
          text,
          foreground: const Color(0xFFF6EFE8),
          side: const Color(0xFF3B312B),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: text.labelLarge,
          foregroundColor: const Color(0xFFFFB39A),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF201A16),
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF3B312B)),
        ),
      ),
    );
  }
}
