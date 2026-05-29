enum ActivityType {
  expenseAdded,
  expenseDeleted,
  settlementCompleted,
  memberJoined,
  memberRemoved,
  groupCreated;

  static ActivityType fromString(String s) {
    switch (s) {
      case 'EXPENSE_ADDED':
        return ActivityType.expenseAdded;
      case 'EXPENSE_DELETED':
        return ActivityType.expenseDeleted;
      case 'SETTLEMENT_COMPLETED':
        return ActivityType.settlementCompleted;
      case 'MEMBER_JOINED':
        return ActivityType.memberJoined;
      case 'MEMBER_REMOVED':
        return ActivityType.memberRemoved;
      case 'GROUP_CREATED':
        return ActivityType.groupCreated;
      default:
        return ActivityType.expenseAdded;
    }
  }
}

class ActivityModel {
  final String id;
  final String groupId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final ActivityType type;
  final String? expenseId;
  final String? settlementId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const ActivityModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.type,
    this.expenseId,
    this.settlementId,
    this.metadata,
    required this.createdAt,
  });

  String get description {
    switch (type) {
      case ActivityType.expenseAdded:
        final title = metadata?['title'] as String?;
        return title != null
            ? '$userName added "$title"'
            : '$userName added an expense';
      case ActivityType.expenseDeleted:
        final title = metadata?['title'] as String?;
        return title != null
            ? '$userName deleted "$title"'
            : '$userName deleted an expense';
      case ActivityType.settlementCompleted:
        final amount = metadata?['amount'];
        final payee = metadata?['payeeName'] as String?;
        if (amount != null && payee != null) {
          return '$userName settled ₹$amount with $payee';
        }
        return '$userName completed a settlement';
      case ActivityType.memberJoined:
        return '$userName joined the group';
      case ActivityType.memberRemoved:
        return '$userName was removed from the group';
      case ActivityType.groupCreated:
        return '$userName created the group';
    }
  }

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return ActivityModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      userId: json['userId'] as String,
      userName: (user?['name'] ?? json['userName']) as String,
      userAvatar: (user?['avatar'] ?? json['userAvatar']) as String?,
      type: ActivityType.fromString(json['type'] as String? ?? ''),
      expenseId: json['expenseId'] as String?,
      settlementId: json['settlementId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}
