import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    // IBM Plex Sans Arabic base text theme applied globally
    final ibmTextTheme = GoogleFonts.ibmPlexSansArabicTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
      textTheme: ibmTextTheme.copyWith(
        displayLarge: GoogleFonts.ibmPlexSansArabic(
            fontSize: 57, fontWeight: FontWeight.w700, color: AppColors.onSurface),
        displayMedium: GoogleFonts.ibmPlexSansArabic(
            fontSize: 45, fontWeight: FontWeight.w700, color: AppColors.onSurface),
        displaySmall: GoogleFonts.ibmPlexSansArabic(
            fontSize: 36, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        headlineLarge: GoogleFonts.ibmPlexSansArabic(
            fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.onSurface),
        headlineMedium: GoogleFonts.ibmPlexSansArabic(
            fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        headlineSmall: GoogleFonts.ibmPlexSansArabic(
            fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        titleLarge: GoogleFonts.ibmPlexSansArabic(
            fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface),
        titleMedium: GoogleFonts.ibmPlexSansArabic(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        titleSmall: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        bodyLarge: GoogleFonts.ibmPlexSansArabic(
            fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.onSurface),
        bodyMedium: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant),
        bodySmall: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant),
        labelLarge: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onPrimary),
        labelMedium: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        labelSmall: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
      ),
    );
  }
}
