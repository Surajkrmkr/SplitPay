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
    final payer = json['payer'] as Map<String, dynamic>?;
    final payee = json['payee'] as Map<String, dynamic>?;
    return SettlementModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      payerId: json['payerId'] as String,
      payerName: payer?['name'] as String? ?? json['payerName'] as String? ?? '',
      payerAvatar: payer?['avatar'] as String? ?? json['payerAvatar'] as String?,
      payeeId: json['payeeId'] as String,
      payeeName: payee?['name'] as String? ?? json['payeeName'] as String? ?? '',
      payeeAvatar: payee?['avatar'] as String? ?? json['payeeAvatar'] as String?,
      amount: double.parse(json['amount'].toString()),
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
