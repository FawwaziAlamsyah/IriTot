import 'package:flutter/material.dart';

class AppTheme {
  // Sleek Neo-Fintech Color Palette
  static const Color bgDark = Color(0xFF0B0F17);
  static const Color surfaceDark = Color(0xFF131B2A);
  static const Color surfaceLighter = Color(0xFF182235);
  static const Color borderDark = Color(0xFF1F2B40);

  // Functional Accents
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color coralRose = Color(0xFFF43F5E);
  static const Color cyanAccent = Color(0xFF38BDF8);
  static const Color violetAI = Color(0xFF8B5CF6);
  static const Color amberWarning = Color(0xFFF59E0B);

  // Typography Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: emeraldGreen,
      colorScheme: const ColorScheme.dark(
        primary: emeraldGreen,
        secondary: cyanAccent,
        surface: surfaceDark,
        error: coralRose,
        onPrimary: Color(0xFF07090E),
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xEB0E121B),
        selectedItemColor: emeraldGreen,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      fontFamily: null,
    );
  }
}
