import 'package:flutter/material.dart';

class AppTheme {
  // BodyDebt Colors: "Simulation" vibe (Neon, Dark, High Contrast)
  static const Color primaryColor = Color(0xFF00E5FF); // Cyber Blue
  static const Color warningColor = Color(0xFFFFC400); // Amber
  static const Color criticalColor = Color(0xFFFF1744); // Red
  static const Color surfaceColor = Color(0xFF1E1E1E);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: warningColor,
        error: criticalColor,
        surface: surfaceColor,
      ),
      cardTheme: CardThemeData( // <--- Change CardTheme to CardThemeData
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      // Big readable numbers
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1.0),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
      ),
    );
  }
}