class ExpenseParticipantModel {
  final String userId;
  final String userName;
  final String? userAvatar;
  final double share;
  final double? percentage;

  const ExpenseParticipantModel({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.share,
    this.percentage,
  });

  factory ExpenseParticipantModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final shareRaw = json['share'];
    final shareVal = shareRaw != null ? double.parse(shareRaw.toString()) : 0.0;
    return ExpenseParticipantModel(
      userId: (user?['id'] ?? json['userId'] ?? '') as String,
      userName: (user?['name'] ?? json['userName'] ?? 'Member') as String,
      userAvatar: (user?['avatar'] ?? json['userAvatar']) as String?,
      share: shareVal,
      percentage: json['percentage'] != null
          ? double.parse(json['percentage'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'share': share,
      'percentage': percentage,
    };
  }
}
