import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF8B5CF6); // Violet/Purple
  static const Color neutral50 = Color(0xFFF1F2F3);
  static const Color neutral100 = Color(0xFFD6D8DA);
  static const Color neutral200 = Color(0xFFADB1B8);
  static const Color neutral300 = Color(0xFF838996);
  static const Color neutral400 = Color(0xFF5F6777);
  static const Color neutral500 = Color(0xFF474D5B);
  static const Color neutral600 = Color(0xFF3A3F4D);
  static const Color neutral700 = Color(0xFF2D3340);
  static const Color neutral800 = Color(0xFF212633);
  static const Color neutral900 = Color(0xFF151923);
  static const Color neutral950 = Color(0xFF0F121A);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.neutral100,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        surface: AppColors.neutral50,
        onSurface: AppColors.neutral900,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.neutral50,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.neutral900,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.neutral950,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        surface: AppColors.neutral900,
        onSurface: AppColors.neutral50,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.neutral900,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.neutral50,
      ),
    );
  }
}
