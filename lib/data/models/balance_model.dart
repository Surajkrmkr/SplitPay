class BalanceModel {
  final String fromUserId;
  final String fromUserName;
  final String? fromUserAvatar;
  final String toUserId;
  final String toUserName;
  final String? toUserAvatar;
  final double amount;

  const BalanceModel({
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserAvatar,
    required this.toUserId,
    required this.toUserName,
    this.toUserAvatar,
    required this.amount,
  });

  factory BalanceModel.fromJson(Map<String, dynamic> json) {
    return BalanceModel(
      fromUserId: json['fromUserId'] as String,
      fromUserName: json['fromUserName'] as String,
      fromUserAvatar: json['fromUserAvatar'] as String?,
      toUserId: json['toUserId'] as String,
      toUserName: json['toUserName'] as String,
      toUserAvatar: json['toUserAvatar'] as String?,
      amount: double.parse(json['amount'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserAvatar': fromUserAvatar,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'toUserAvatar': toUserAvatar,
      'amount': amount,
    };
  }
}

class GroupBalanceSummary {
  final List<BalanceModel> balances;
  final double totalOwed;
  final double totalLent;

  const GroupBalanceSummary({
    required this.balances,
    required this.totalOwed,
    required this.totalLent,
  });

  double get net => totalLent - totalOwed;

  factory GroupBalanceSummary.fromJson(
    Map<String, dynamic> json,
    String currentUserId,
  ) {
    final rawBalances = (json['balances'] as List<dynamic>? ?? [])
        .map((b) => BalanceModel.fromJson(b as Map<String, dynamic>))
        .toList();

    double owed = 0;
    double lent = 0;
    for (final b in rawBalances) {
      if (b.fromUserId == currentUserId) {
        owed += b.amount;
      } else if (b.toUserId == currentUserId) {
        lent += b.amount;
      }
    }

    return GroupBalanceSummary(
      balances: rawBalances,
      totalOwed: json['totalOwed'] != null
          ? double.parse(json['totalOwed'].toString())
          : owed,
      totalLent: json['totalLent'] != null
          ? double.parse(json['totalLent'].toString())
          : lent,
    );
  }
}
