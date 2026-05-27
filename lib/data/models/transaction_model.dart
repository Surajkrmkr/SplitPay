import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum TransactionType { income, expense }

enum RecurrenceType { none, daily, weekly, monthly, yearly }

extension RecurrenceTypeExt on RecurrenceType {
  String get label {
    switch (this) {
      case RecurrenceType.none: return 'One-time';
      case RecurrenceType.daily: return 'Daily';
      case RecurrenceType.weekly: return 'Weekly';
      case RecurrenceType.monthly: return 'Monthly';
      case RecurrenceType.yearly: return 'Yearly';
    }
  }

  IconData get icon {
    switch (this) {
      case RecurrenceType.none: return Icons.bolt_rounded;
      case RecurrenceType.daily: return Icons.today_rounded;
      case RecurrenceType.weekly: return Icons.view_week_rounded;
      case RecurrenceType.monthly: return Icons.calendar_month_rounded;
      case RecurrenceType.yearly: return Icons.event_repeat_rounded;
    }
  }

  bool get isRecurring => this != RecurrenceType.none;

  String get serverValue => name.toUpperCase();
}

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

/// Tracks the local→server sync lifecycle of a transaction.
enum SyncStatus {
  /// Newly created locally, not yet uploaded.
  pendingCreate,

  /// Modified locally after a previous successful sync.
  pendingUpdate,

  /// Marked for deletion locally; server has not been notified yet.
  pendingDelete,

  /// In sync with the server.
  synced,
}

extension SyncStatusExt on SyncStatus {
  bool get isPending => this != SyncStatus.synced;

  /// The action string sent to the sync API.
  String get action {
    switch (this) {
      case SyncStatus.pendingCreate: return 'create';
      case SyncStatus.pendingUpdate: return 'update';
      case SyncStatus.pendingDelete: return 'delete';
      case SyncStatus.synced: return 'update';
    }
  }
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
  final RecurrenceType recurrence;

  // Sync fields — absent in pre-sync Hive rows; deserialized with safe defaults.
  final String? serverId;
  final SyncStatus syncStatus;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final bool isDeleted;

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
    this.recurrence = RecurrenceType.none,
    this.serverId,
    this.syncStatus = SyncStatus.pendingCreate,
    DateTime? updatedAt,
    this.lastSyncedAt,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? createdAt;

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
    'recurrence': recurrence.name,
    'serverId': serverId,
    'syncStatus': syncStatus.name,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'lastSyncedAt': lastSyncedAt?.millisecondsSinceEpoch,
    'isDeleted': isDeleted,
  };

  factory Transaction.fromMap(Map map) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int);
    return Transaction(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.byName(map['type'] as String),
      category: Category.values.byName(map['category'] as String),
      customCategoryId: map['customCategoryId'] as String?,
      appIcon: map['appIcon'] as String?,
      note: map['note'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      createdAt: createdAt,
      recurrence: map['recurrence'] is String
          ? RecurrenceType.values.byName(map['recurrence'] as String)
          : RecurrenceType.none,
      // Safe defaults for rows that predate the sync migration.
      serverId: map['serverId'] as String?,
      syncStatus: map['syncStatus'] is String
          ? SyncStatus.values.byName(map['syncStatus'] as String)
          : SyncStatus.pendingCreate,
      updatedAt: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : createdAt,
      lastSyncedAt: map['lastSyncedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSyncedAt'] as int)
          : null,
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  /// Converts to the payload sent to the server sync API.
  Map<String, dynamic> toSyncPayload() => {
    'localId': id,
    if (serverId != null) 'serverId': serverId,
    'action': syncStatus.action,
    'amount': amount,
    'type': type == TransactionType.income ? 'INCOME' : 'EXPENSE',
    'categoryKey': category.name,
    if (customCategoryId != null) 'customCategoryId': customCategoryId,
    if (appIcon != null) 'appIcon': appIcon,
    if (note != null) 'note': note,
    'date': date.toUtc().toIso8601String(),
    'recurrence': recurrence.serverValue,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

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
    RecurrenceType? recurrence,
    Object? serverId = _unset,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
    Object? lastSyncedAt = _unset,
    bool? isDeleted,
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
        recurrence: recurrence ?? this.recurrence,
        serverId: serverId == _unset ? this.serverId : serverId as String?,
        syncStatus: syncStatus ?? this.syncStatus,
        updatedAt: updatedAt ?? this.updatedAt,
        lastSyncedAt: lastSyncedAt == _unset
            ? this.lastSyncedAt
            : lastSyncedAt as DateTime?,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}

const _unset = Object();
