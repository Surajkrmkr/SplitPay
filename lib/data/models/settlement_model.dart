class SettlementModel {
  final String id;
  final String groupId;
  final String payerId;
  final String payerName;
  final String? payerAvatar;
  final String payeeId;
  final String payeeName;
  final String? payeeAvatar;
  final double amount;
  final String? notes;
  final DateTime settledAt;

  const SettlementModel({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.payerName,
    this.payerAvatar,
    required this.payeeId,
    required this.payeeName,
    this.payeeAvatar,
    required this.amount,
    this.notes,
    required this.settledAt,
  });

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    return SettlementModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      payerId: json['payerId'] as String,
      payerName: json['payerName'] as String,
      payerAvatar: json['payerAvatar'] as String?,
      payeeId: json['payeeId'] as String,
      payeeName: json['payeeName'] as String,
      payeeAvatar: json['payeeAvatar'] as String?,
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      settledAt: DateTime.parse(json['settledAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'payerId': payerId,
      'payerName': payerName,
      'payerAvatar': payerAvatar,
      'payeeId': payeeId,
      'payeeName': payeeName,
      'payeeAvatar': payeeAvatar,
      'amount': amount,
      'notes': notes,
      'settledAt': settledAt.toIso8601String(),
    };
  }
}
