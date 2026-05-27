import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum TransactionType { income, expense }

enum Category {
  food,
  shopping,
  bills,
  travel,
  salary,
  entertainment,
  health,
  subscription,
  other,
}

extension CategoryExt on Category {
  String get label {
    switch (this) {
      case Category.food: return 'Food';
      case Category.shopping: return 'Shopping';
      case Category.bills: return 'Bills';
      case Category.travel: return 'Travel';
      case Category.salary: return 'Salary';
      case Category.entertainment: return 'Entertainment';
      case Category.health: return 'Health';
      case Category.subscription: return 'Subscription';
      case Category.other: return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case Category.food: return Icons.restaurant_rounded;
      case Category.shopping: return Icons.shopping_bag_rounded;
      case Category.bills: return Icons.receipt_long_rounded;
      case Category.travel: return Icons.flight_rounded;
      case Category.salary: return Icons.account_balance_wallet_rounded;
      case Category.entertainment: return Icons.movie_rounded;
      case Category.health: return Icons.favorite_rounded;
      case Category.subscription: return Icons.subscriptions_rounded;
      case Category.other: return Icons.category_rounded;
    }
  }

  Color get color {
    switch (this) {
      case Category.food: return AppColors.catFood;
      case Category.shopping: return AppColors.catShopping;
      case Category.bills: return AppColors.catBills;
      case Category.travel: return AppColors.catTravel;
      case Category.salary: return AppColors.catSalary;
      case Category.entertainment: return AppColors.catEntertainment;
      case Category.health: return AppColors.catHealth;
      case Category.subscription: return AppColors.catSubscription;
      case Category.other: return AppColors.catOther;
    }
  }

  bool get isIncome => this == Category.salary;
}

class Transaction {
  final String id;
  final double amount;
  final TransactionType type;
  final Category category;
  final String? customCategoryId;
  final String? appIcon;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.customCategoryId,
    this.appIcon,
    this.note,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'type': type.name,
    'category': category.name,
    'customCategoryId': customCategoryId,
    'appIcon': appIcon,
    'note': note,
    'date': date.millisecondsSinceEpoch,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Transaction.fromMap(Map map) => Transaction(
    id: map['id'] as String,
    amount: (map['amount'] as num).toDouble(),
    type: TransactionType.values.byName(map['type'] as String),
    category: Category.values.byName(map['category'] as String),
    customCategoryId: map['customCategoryId'] as String?,
    // appIcon is nullable so old Hive rows without it deserialize cleanly.
    appIcon: map['appIcon'] as String?,
    note: map['note'] as String?,
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
  );

  Transaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    Category? category,
    Object? customCategoryId = _unset,
    Object? appIcon = _unset,
    Object? note = _unset,
    DateTime? date,
    DateTime? createdAt,
  }) =>
      Transaction(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        category: category ?? this.category,
        customCategoryId: customCategoryId == _unset
            ? this.customCategoryId
            : customCategoryId as String?,
        appIcon: appIcon == _unset ? this.appIcon : appIcon as String?,
        note: note == _unset ? this.note : note as String?,
        date: date ?? this.date,
        createdAt: createdAt ?? this.createdAt,
      );
}

const _unset = Object();
