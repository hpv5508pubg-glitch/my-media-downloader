import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static const Color amoledBlack = Color(AppConstants.colorAmoledBackground);
  static const Color pureBlack = Color(0xFF000000);
  static const Color surfaceDark = Color(AppConstants.colorAmoledSurface);
  static const Color surfaceLight = Color(AppConstants.colorAmoledSurfaceLight);
  static const Color neonGreen = Color(AppConstants.colorSpotifyNeonGreen);
  static const Color neonGreenAccent = Color(AppConstants.colorSpotifyNeonGreenAccent);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF6B6B6B);
  static const Color errorRed = Color(0xFFE91E63);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: pureBlack,
      primaryColor: neonGreen,
      colorScheme: const ColorScheme.dark(
        primary: neonGreen,
        secondary: neonGreenAccent,
        surface: surfaceDark,
        background: pureBlack,
        error: errorRed,
        onPrimary: pureBlack,
        onSecondary: pureBlack,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: neonGreen,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: neonGreen,
        linearTrackColor: surfaceLight,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: neonGreen,
        inactiveTrackColor: surfaceLight,
        thumbColor: neonGreen,
        overlayColor: neonGreen.withOpacity(0.2),
        trackHeight: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: pureBlack,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonGreen, width: 1.5),
        ),
      ),
      useMaterial3: true,
    );
  }
}
