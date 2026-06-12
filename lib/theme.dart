import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Couleurs de DouraKa ──────────────────────────────────────────────────────
const kOrange      = Color(0xFFEA580C);
const kOrangeLight = Color(0xFFFFF7ED);
const kOrangeDark  = Color(0xFFC2410C);
const kBackground  = Color(0xFFF3F4F6);
const kCard        = Colors.white;
const kTextPrimary = Color(0xFF111827);
const kTextGray    = Color(0xFF6B7280);
const kBorder      = Color(0xFFE5E7EB);
const kGreen       = Color(0xFF16A34A);
const kGreenLight  = Color(0xFFDCFCE7);
const kRed         = Color(0xFFDC2626);
const kRedLight    = Color(0xFFFEE2E2);
const kYellow      = Color(0xFFF59E0B);

// ── Thème global de l'application ───────────────────────────────────────────
ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kOrange,
      primary: kOrange,
    ),
    scaffoldBackgroundColor: kBackground,
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: GoogleFonts.poppins(
        color: kTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        minimumSize: const Size(double.infinity, 52),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kOrange, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
