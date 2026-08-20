import 'package:flutter/material.dart';

enum AppThemePreset {
  emerald,
  ocean,
  purple,
  sunset,
  gold,
  rose,
}

extension AppThemePresetExt on AppThemePreset {
  String get displayName {
    switch (this) {
      case AppThemePreset.emerald:
        return 'Emerald';
      case AppThemePreset.ocean:
        return 'Ocean Blue';
      case AppThemePreset.purple:
        return 'Purple Velvet';
      case AppThemePreset.sunset:
        return 'Sunset Ember';
      case AppThemePreset.gold:
        return 'Midnight Gold';
      case AppThemePreset.rose:
        return 'Rose Blossom';
    }
  }

  Color get primaryColor {
    switch (this) {
      case AppThemePreset.emerald:
        return const Color(0xFF00D09C);
      case AppThemePreset.ocean:
        return const Color(0xFF2563EB);
      case AppThemePreset.purple:
        return const Color(0xFF8B5CF6);
      case AppThemePreset.sunset:
        return const Color(0xFFF97316);
      case AppThemePreset.gold:
        return const Color(0xFFF59E0B);
      case AppThemePreset.rose:
        return const Color(0xFFEC4899);
    }
  }

  Color get primaryDarkColor {
    switch (this) {
      case AppThemePreset.emerald:
        return const Color(0xFF00A87D);
      case AppThemePreset.ocean:
        return const Color(0xFF1D4ED8);
      case AppThemePreset.purple:
        return const Color(0xFF7C3AED);
      case AppThemePreset.sunset:
        return const Color(0xFFEA580C);
      case AppThemePreset.gold:
        return const Color(0xFFD97706);
      case AppThemePreset.rose:
        return const Color(0xFFDB2777);
    }
  }

  Color get primaryLightColor {
    switch (this) {
      case AppThemePreset.emerald:
        return const Color(0xFF33DAAD);
      case AppThemePreset.ocean:
        return const Color(0xFF60A5FA);
      case AppThemePreset.purple:
        return const Color(0xFFA78BFA);
      case AppThemePreset.sunset:
        return const Color(0xFFFB923C);
      case AppThemePreset.gold:
        return const Color(0xFFFBBF24);
      case AppThemePreset.rose:
        return const Color(0xFFF472B6);
    }
  }

  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, primaryDarkColor],
      );
}

enum AppBackgroundStyle {
  standard,
  pureBlack,
  deepNavy,
  darkEmerald,
  darkPlum,
}

extension AppBackgroundStyleExt on AppBackgroundStyle {
  String get displayName {
    switch (this) {
      case AppBackgroundStyle.standard:
        return 'Standard';
      case AppBackgroundStyle.pureBlack:
        return 'OLED Black';
      case AppBackgroundStyle.deepNavy:
        return 'Deep Navy';
      case AppBackgroundStyle.darkEmerald:
        return 'Forest Emerald';
      case AppBackgroundStyle.darkPlum:
        return 'Night Plum';
    }
  }

  Color darkBg(Color defaultBg) {
    switch (this) {
      case AppBackgroundStyle.standard:
        return defaultBg;
      case AppBackgroundStyle.pureBlack:
        return const Color(0xFF000000);
      case AppBackgroundStyle.deepNavy:
        return const Color(0xFF0B132B);
      case AppBackgroundStyle.darkEmerald:
        return const Color(0xFF071B14);
      case AppBackgroundStyle.darkPlum:
        return const Color(0xFF140A21);
    }
  }

  Color darkCard(Color defaultCard) {
    switch (this) {
      case AppBackgroundStyle.standard:
        return defaultCard;
      case AppBackgroundStyle.pureBlack:
        return const Color(0xFF121212);
      case AppBackgroundStyle.deepNavy:
        return const Color(0xFF1C2541);
      case AppBackgroundStyle.darkEmerald:
        return const Color(0xFF123126);
      case AppBackgroundStyle.darkPlum:
        return const Color(0xFF221334);
    }
  }

  Color darkSurface(Color defaultSurface) {
    switch (this) {
      case AppBackgroundStyle.standard:
        return defaultSurface;
      case AppBackgroundStyle.pureBlack:
        return const Color(0xFF0A0A0A);
      case AppBackgroundStyle.deepNavy:
        return const Color(0xFF131B33);
      case AppBackgroundStyle.darkEmerald:
        return const Color(0xFF0C241B);
      case AppBackgroundStyle.darkPlum:
        return const Color(0xFF1B0E2A);
    }
  }

  Color lightBg(Color defaultBg) {
    switch (this) {
      case AppBackgroundStyle.standard:
        return defaultBg;
      case AppBackgroundStyle.pureBlack:
        return const Color(0xFFFFFFFF);
      case AppBackgroundStyle.deepNavy:
        return const Color(0xFFFAF8F5);
      case AppBackgroundStyle.darkEmerald:
        return const Color(0xFFF2F9F6);
      case AppBackgroundStyle.darkPlum:
        return const Color(0xFFF7F5FA);
    }
  }

  Color lightCard(Color defaultCard) {
    switch (this) {
      case AppBackgroundStyle.standard:
        return defaultCard;
      case AppBackgroundStyle.pureBlack:
        return const Color(0xFFF3F4F6);
      case AppBackgroundStyle.deepNavy:
        return const Color(0xFFF2ECE4);
      case AppBackgroundStyle.darkEmerald:
        return const Color(0xFFE4F3EC);
      case AppBackgroundStyle.darkPlum:
        return const Color(0xFFECE6F5);
    }
  }

  Color lightSurface(Color defaultSurface) {
    switch (this) {
      case AppBackgroundStyle.standard:
        return defaultSurface;
      case AppBackgroundStyle.pureBlack:
        return const Color(0xFFFAFAFA);
      case AppBackgroundStyle.deepNavy:
        return const Color(0xFFFFFFFF);
      case AppBackgroundStyle.darkEmerald:
        return const Color(0xFFFFFFFF);
      case AppBackgroundStyle.darkPlum:
        return const Color(0xFFFFFFFF);
    }
  }
}

class AppColors {
  // Dark theme backgrounds
  static const darkBg = Color(0xFF0F1115);
  static const darkSurface = Color(0xFF1A1D23);
  static const darkCard = Color(0xFF1E2228);
  static const darkElevated = Color(0xFF252830);
  static const darkBorder = Color(0xFF2A2D35);

  // Light theme backgrounds
  static const lightBg = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF0F2F5);
  static const lightBorder = Color(0xFFE5E7EB);

  // Brand colors (Defaults to Emerald)
  static const primary = Color(0xFF00D09C);
  static const primaryDark = Color(0xFF00A87D);
  static const primaryLight = Color(0xFF33DAAD);
  static const secondary = Color(0xFF5B6EF5);

  // Semantic colors
  static const income = Color(0xFF00D09C);
  static const expense = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFFBB33);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8B93A7);
  static const textTertiary = Color(0xFF4A5168);
  static const textLight = Color(0xFF1A1D23);
  static const textLightSecondary = Color(0xFF6B7280);

  // Category colors
  static const catFood = Color(0xFFFF8C42);
  static const catShopping = Color(0xFF5B6EF5);
  static const catBills = Color(0xFFFFD166);
  static const catTravel = Color(0xFF4ECDC4);
  static const catSalary = Color(0xFF00D09C);
  static const catEntertainment = Color(0xFFFF6B9D);
  static const catHealth = Color(0xFFFF6B6B);
  static const catSubscription = Color(0xFF9B59B6);
  static const catOther = Color(0xFF8B93A7);

  static const List<Color> categoryColors = [
    catFood,
    catShopping,
    catBills,
    catTravel,
    catSalary,
    catEntertainment,
    catHealth,
    catSubscription,
    catOther,
  ];

  // Gradient
  static const balanceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A3A2A), Color(0xFF0F1D16)],
  );

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D09C), Color(0xFF00A87D)],
  );
}
