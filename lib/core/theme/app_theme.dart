import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Primary Colors (PicklePlay Fresh Light Green) ──────────────────────────
  static const Color primary = Color(0xFF22C55E);        // Fresh vibrant court green
  static const Color primaryDark = Color(0xFF16A34A);    // Deep athletic grass green
  static const Color primaryLight = Color(0xFFDCFCE7);   // Soft pastel mint/lime green
  static const Color primaryGlow = Color(0x3322C55E);    // Clean green glow
  static const Color accent = Color(0xFF10B981);         // Emerald accent
  static const Color highlight = Color(0xFFF59E0B);      // Sunburst amber

  // ─── Surfaces (Clean & Fresh Crisp White) ───────────────────────────────────
  static const Color background = Color(0xFFF8FAF8);     // Clean fresh white background
  static const Color surface = Color(0xFFFFFFFF);        // Pure snow white
  static const Color card = Color(0xFFFFFFFF);           // White card surface
  static const Color cardBorder = Color(0xFFE2ECE4);     // Soft delicate mint-gray border
  static const Color cardBorderLight = Color(0xFFD4E5D7);// Slightly pronounced border

  // ─── Text (Deep Crisp Slate & Modern Neutrals) ──────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);    // Deep rich slate (high contrast)
  static const Color textSecondary = Color(0xFF475569);  // Clean medium slate
  static const Color textMuted = Color(0xFF94A3B8);      // Soft slate gray

  // ─── Status colours ─────────────────────────────────────────────────────────
  static const Color statusAvailable = Color(0xFF16A34A);// Active / confirmed green
  static const Color statusReserved = Color(0xFFD97706); // Warm amber
  static const Color statusInUse = Color(0xFFEF4444);    // Vibrant coral red
  static const Color statusCompleted = Color(0xFF64748B);// Neutral slate

  // ─── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF4F9F4), Color(0xFFEEF6EF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient neonBorderGradient = LinearGradient(
    colors: [primary, primaryLight, accent, primary],
  );

  // ─── Box Decorations ────────────────────────────────────────────────────────
  static BoxDecoration get glassCard => BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration get primaryCard => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      );

  // ─── Main Theme Data ────────────────────────────────────────────────────────
  static ThemeData get theme {
    final base = ThemeData.light();
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: statusInUse,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(
            color: textPrimary, fontWeight: FontWeight.w700, fontSize: 32),
        displayMedium: GoogleFonts.poppins(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 28),
        headlineLarge: GoogleFonts.poppins(
            color: textPrimary, fontWeight: FontWeight.w700, fontSize: 24),
        headlineMedium: GoogleFonts.poppins(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        headlineSmall: GoogleFonts.poppins(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        titleLarge: GoogleFonts.poppins(
            color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        titleMedium: GoogleFonts.poppins(
            color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: textMuted, fontSize: 12),
        labelLarge: GoogleFonts.poppins(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        selectedLabelStyle:
            GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: statusInUse),
        ),
        labelStyle:
            GoogleFonts.inter(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F1),
        selectedColor: primaryLight,
        labelStyle: GoogleFonts.inter(color: textPrimary, fontSize: 13),
        side: const BorderSide(color: cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
        elevation: 16,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Backward compatibility alias
  static ThemeData get darkTheme => theme;
  static ThemeData get lightTheme => theme;
}
