import '../../core/utils/currency_formatter.dart';

enum ActivityType {
  expenseAdded,
  expenseUpdated,
  expenseDeleted,
  settlementCompleted,
  memberJoined,
  memberRemoved,
  groupCreated;

  static ActivityType fromString(String s) {
    switch (s) {
      case 'EXPENSE_ADDED':
        return ActivityType.expenseAdded;
      case 'EXPENSE_UPDATED':
        return ActivityType.expenseUpdated;
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
        final amountRaw = metadata?['amount'];
        final amountNum = amountRaw is num
            ? amountRaw.toDouble()
            : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
        final amtStr = amountNum != null
            ? ' (${CurrencyFormatter.formatAmountWithCommas(amountNum, symbol: '₹')})'
            : '';
        return title != null
            ? '$userName added "$title"$amtStr'
            : '$userName added an expense';

      case ActivityType.expenseUpdated:
        final title = metadata?['title'] as String?;
        final amountRaw = metadata?['amount'];
        final amountNum = amountRaw is num
            ? amountRaw.toDouble()
            : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
        final amtStr = amountNum != null
            ? ' (${CurrencyFormatter.formatAmountWithCommas(amountNum, symbol: '₹')})'
            : '';
        return title != null
            ? '$userName edited "$title"$amtStr'
            : '$userName edited an expense';

      case ActivityType.expenseDeleted:
        final title = metadata?['title'] as String?;
        return title != null
            ? '$userName deleted "$title"'
            : '$userName deleted an expense';

      case ActivityType.settlementCompleted:
        final amountRaw = metadata?['amount'];
        final payee = metadata?['payeeName'] as String?;
        final amountNum = amountRaw is num
            ? amountRaw.toDouble()
            : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
        if (amountNum != null && payee != null) {
          return '$userName settled ${CurrencyFormatter.formatAmountWithCommas(amountNum, symbol: '₹')} with $payee';
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
