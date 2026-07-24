import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color background = Color(0xFF070B19);
  static const Color surface = Color(0xFF0F152B);
  static const Color surfaceElevated = Color(0xFF181F3D);
  static const Color border = Color(0xFF26325D);

  static const Color primary = Color(0xFF00E5FF); // Electric Cyan
  static const Color secondary = Color(0xFFBD00FF); // Neon Purple
  static const Color accent = Color(0xFFFF0055); // Pink/Red Neon

  // Status Colors
  static const Color success = Color(0xFF00FF66);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = Color(0xFFFF3366);
  static const Color info = Color(0xFF00BFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFB0B9D6),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF8692B5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceElevated,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  // Neon box shadow decorators
  static List<BoxShadow> glowShadow(Color color) {
    return [
      BoxShadow(
        color: color.withOpacity(0.3),
        blurRadius: 15,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: color.withOpacity(0.1),
        blurRadius: 30,
        spreadRadius: 5,
      ),
    ];
  }
}
