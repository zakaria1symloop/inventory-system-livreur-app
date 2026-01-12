import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF22C55E); // Green for delivery
  static const Color primaryDark = Color(0xFF16A34A);
  static const Color secondaryColor = Color(0xFF64748B);
  static const Color successColor = Color(0xFF22C55E);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: dangerColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.tajawalTextTheme().copyWith(
        headlineLarge: GoogleFonts.tajawal(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.tajawal(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.tajawal(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.tajawal(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.tajawal(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.tajawal(
          fontSize: 14,
          color: textPrimary,
        ),
        bodySmall: GoogleFonts.tajawal(
          fontSize: 12,
          color: textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dangerColor),
        ),
        hintStyle: GoogleFonts.tajawal(color: textSecondary),
        labelStyle: GoogleFonts.tajawal(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: const BorderSide(color: primaryColor),
          textStyle: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.tajawal(),
      ),
    );
  }
}
