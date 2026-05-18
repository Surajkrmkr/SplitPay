import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum NotificationType {
  groupExpenseAdded,
  settlementReceived,
  addedToGroup,
  paymentReminder,
  groupActivity,
}

extension NotificationTypeX on NotificationType {
  String get key {
    switch (this) {
      case NotificationType.groupExpenseAdded:
        return 'GROUP_EXPENSE_ADDED';
      case NotificationType.settlementReceived:
        return 'SETTLEMENT_RECEIVED';
      case NotificationType.addedToGroup:
        return 'ADDED_TO_GROUP';
      case NotificationType.paymentReminder:
        return 'PAYMENT_REMINDER';
      case NotificationType.groupActivity:
        return 'GROUP_ACTIVITY';
    }
  }

  static NotificationType fromKey(String key) {
    switch (key) {
      case 'GROUP_EXPENSE_ADDED':
        return NotificationType.groupExpenseAdded;
      case 'SETTLEMENT_RECEIVED':
        return NotificationType.settlementReceived;
      case 'ADDED_TO_GROUP':
        return NotificationType.addedToGroup;
      case 'PAYMENT_REMINDER':
        return NotificationType.paymentReminder;
      case 'GROUP_ACTIVITY':
      default:
        return NotificationType.groupActivity;
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.groupExpenseAdded:
        return Icons.receipt_long_rounded;
      case NotificationType.settlementReceived:
        return Icons.check_circle_rounded;
      case NotificationType.addedToGroup:
        return Icons.group_add_rounded;
      case NotificationType.paymentReminder:
        return Icons.alarm_rounded;
      case NotificationType.groupActivity:
        return Icons.bolt_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.groupExpenseAdded:
        return AppColors.secondary;
      case NotificationType.settlementReceived:
        return AppColors.income;
      case NotificationType.addedToGroup:
        return AppColors.primary;
      case NotificationType.paymentReminder:
        return AppColors.warning;
      case NotificationType.groupActivity:
        return const Color(0xFFFF6B9D);
    }
  }

  String routeFor(String? groupId) {
    if (groupId != null && groupId.isNotEmpty) return '/groups/$groupId';
    return '/home';
  }
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? groupId;
  final String? actorName;
  final String? actorAvatar;
  final Map<String, dynamic>? data;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.groupId,
    this.actorName,
    this.actorAvatar,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: NotificationTypeX.fromKey(json['type'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      groupId: json['groupId'] as String?,
      actorName: json['actorName'] as String?,
      actorAvatar: json['actorAvatar'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.key,
        'title': title,
        'body': body,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
        'groupId': groupId,
        'actorName': actorName,
        'actorAvatar': actorAvatar,
        'data': data,
      };

  factory NotificationModel.fromHive(Map map) {
    return NotificationModel(
      id: map['id'] as String,
      type: NotificationTypeX.fromKey(map['type'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isRead: map['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      groupId: map['groupId'] as String?,
      actorName: map['actorName'] as String?,
      actorAvatar: map['actorAvatar'] as String?,
    );
  }

  Map<String, dynamic> toHive() => {
        'id': id,
        'type': type.key,
        'title': title,
        'body': body,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
        'groupId': groupId,
        'actorName': actorName,
        'actorAvatar': actorAvatar,
      };

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        groupId: groupId,
        actorName: actorName,
        actorAvatar: actorAvatar,
        data: data,
      );

  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return createdAt.year == yesterday.year &&
        createdAt.month == yesterday.month &&
        createdAt.day == yesterday.day;
  }

  // Convenience factory for FCM RemoteMessage data
  factory NotificationModel.fromFcmData(Map<String, dynamic> data) {
    return NotificationModel(
      id: data['notificationId'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationTypeX.fromKey(data['type'] as String? ?? ''),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      isRead: false,
      createdAt: DateTime.now(),
      groupId: data['groupId'] as String?,
      actorName: data['actorName'] as String?,
      actorAvatar: data['actorAvatar'] as String?,
      data: data,
    );
  }
}
