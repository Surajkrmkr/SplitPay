import 'package:flutter/material.dart';

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

  // Brand colors
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
