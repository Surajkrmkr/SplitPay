import 'package:flutter/material.dart';

enum BudgetPeriod { daily, weekly, monthly, yearly }

extension BudgetPeriodExt on BudgetPeriod {
  String get label {
    switch (this) {
      case BudgetPeriod.daily:
        return 'Daily';
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
      case BudgetPeriod.yearly:
        return 'Yearly';
    }
  }

  String get shortLabel {
    switch (this) {
      case BudgetPeriod.daily:
        return '/day';
      case BudgetPeriod.weekly:
        return '/wk';
      case BudgetPeriod.monthly:
        return '/mo';
      case BudgetPeriod.yearly:
        return '/yr';
    }
  }

  IconData get periodIcon {
    switch (this) {
      case BudgetPeriod.daily:
        return Icons.today_rounded;
      case BudgetPeriod.weekly:
        return Icons.date_range_rounded;
      case BudgetPeriod.monthly:
        return Icons.calendar_month_rounded;
      case BudgetPeriod.yearly:
        return Icons.event_rounded;
    }
  }

  DateTimeRange get currentRange {
    final now = DateTime.now();
    switch (this) {
      case BudgetPeriod.daily:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case BudgetPeriod.weekly:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final start =
            DateTime(weekStart.year, weekStart.month, weekStart.day);
        return DateTimeRange(
          start: start,
          end: DateTime(
              start.year, start.month, start.day + 6, 23, 59, 59),
        );
      case BudgetPeriod.monthly:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case BudgetPeriod.yearly:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
    }
  }

  int get daysLeft =>
      currentRange.end.difference(DateTime.now()).inDays.clamp(0, 999);

  String get nextResetLabel {
    final d = daysLeft;
    if (this == BudgetPeriod.daily) return 'Resets tomorrow';
    if (d == 0) return 'Resets today';
    return 'Resets in $d day${d == 1 ? '' : 's'}';
  }
}

enum BudgetStatus { safe, warning, exceeded }

class Budget {
  final String id;
  final String title;
  final double amount;

  /// Category identifiers: `Category.name` for built-in, UUID for custom.
  /// Empty list = global budget (all expenses in period).
  final List<String> categoryIds;

  final BudgetPeriod period;
  final DateTime startDate;
  final int colorValue;
  final int iconCodePoint;
  final bool isArchived;

  /// Alert threshold as a fraction (e.g. 0.8 → warn at 80%).
  final double alertThreshold;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryIds,
    required this.period,
    required this.startDate,
    required this.colorValue,
    required this.iconCodePoint,
    required this.isArchived,
    required this.alertThreshold,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get color => Color(colorValue);
  IconData get icon => kBudgetIcons.firstWhere(
        (i) => i.codePoint == iconCodePoint,
        orElse: () => kBudgetIcons[0],
      );
  bool get isGlobal => categoryIds.isEmpty;
  bool get isActive => !isArchived;
  bool get isFuture => startDate.isAfter(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'categoryIds': categoryIds,
        'period': period.name,
        'startDate': startDate.millisecondsSinceEpoch,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
        'isArchived': isArchived,
        'alertThreshold': alertThreshold,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Budget.fromMap(Map map) => Budget(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        categoryIds: (map['categoryIds'] as List?)?.cast<String>() ?? [],
        period: BudgetPeriod.values.byName(map['period'] as String),
        startDate:
            DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
        colorValue: map['colorValue'] as int,
        iconCodePoint: map['iconCodePoint'] as int,
        isArchived: map['isArchived'] as bool? ?? false,
        alertThreshold:
            (map['alertThreshold'] as num?)?.toDouble() ?? 0.8,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  Budget copyWith({
    String? id,
    String? title,
    double? amount,
    List<String>? categoryIds,
    BudgetPeriod? period,
    DateTime? startDate,
    int? colorValue,
    int? iconCodePoint,
    bool? isArchived,
    double? alertThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Budget(
        id: id ?? this.id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        categoryIds: categoryIds ?? this.categoryIds,
        period: period ?? this.period,
        startDate: startDate ?? this.startDate,
        colorValue: colorValue ?? this.colorValue,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
        isArchived: isArchived ?? this.isArchived,
        alertThreshold: alertThreshold ?? this.alertThreshold,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Preset color palette for budget creation.
const List<Color> kBudgetColors = [
  Color(0xFF00D09C),
  Color(0xFF5B6EF5),
  Color(0xFFFF6B6B),
  Color(0xFFFFBB33),
  Color(0xFFFF8C42),
  Color(0xFF4ECDC4),
  Color(0xFFFF6B9D),
  Color(0xFF9B59B6),
  Color(0xFF2ECC71),
  Color(0xFF3498DB),
  Color(0xFFE74C3C),
  Color(0xFF1ABC9C),
];

/// Preset icon palette for budget creation.
const List<IconData> kBudgetIcons = [
  Icons.account_balance_wallet_rounded,
  Icons.restaurant_rounded,
  Icons.shopping_bag_rounded,
  Icons.flight_rounded,
  Icons.home_rounded,
  Icons.directions_car_rounded,
  Icons.fitness_center_rounded,
  Icons.movie_rounded,
  Icons.school_rounded,
  Icons.medical_services_rounded,
  Icons.sports_rounded,
  Icons.local_grocery_store_rounded,
];
