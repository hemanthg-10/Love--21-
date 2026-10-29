import 'package:flutter/material.dart';

abstract final class LoveColors {
  static const canvas = Color(0xFFFDFBF7);
  static const card = Color(0xFFF8F4EE);
  static const elevated = Color(0xFFF3ECE2);
  static const white = Color(0xFFFFFFFF);
  static const wine = Color(0xFF6B1D2F);
  static const rose = Color(0xFF8B263E);
  static const coral = Color(0xFFE07A5F);
  static const gold = Color(0xFFD48C70);
  static const blush = Color(0xFFFCEEE9);
  static const onyx = Color(0xFF22181C);
  static const charcoal = Color(0xFF4A3E3D);
  static const taupe = Color(0xFF8A7D7C);
  static const border = Color(0xFFEADFD5);
  static const green = Color(0xFF2D6A4F);
  static const amber = Color(0xFFD97706);
  static const red = Color(0xFFBE123C);
}

ThemeData buildLoveTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: LoveColors.wine,
    brightness: Brightness.light,
    surface: LoveColors.canvas,
    primary: LoveColors.wine,
    secondary: LoveColors.coral,
    error: LoveColors.red,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LoveColors.canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: LoveColors.canvas,
      foregroundColor: LoveColors.onyx,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'serif',
        fontSize: 34,
        fontWeight: FontWeight.w600,
        color: LoveColors.wine,
        height: 1.15,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'serif',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: LoveColors.wine,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'serif',
        fontSize: 23,
        fontWeight: FontWeight.w600,
        color: LoveColors.wine,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: LoveColors.onyx,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: LoveColors.onyx,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        color: LoveColors.charcoal,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: LoveColors.charcoal,
      ),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: LoveColors.taupe),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LoveColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: LoveColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: LoveColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: LoveColors.wine, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: LoveColors.wine,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LoveColors.wine,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: LoveColors.wine),
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: LoveColors.card,
      selectedColor: LoveColors.blush,
      side: const BorderSide(color: LoveColors.border),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(color: LoveColors.charcoal, fontSize: 13),
      secondaryLabelStyle: const TextStyle(
        color: LoveColors.wine,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerColor: LoveColors.border,
  );
}
