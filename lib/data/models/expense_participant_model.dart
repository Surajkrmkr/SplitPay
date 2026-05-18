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
    return ExpenseParticipantModel(
      userId: json['userId'] as String,
      userName: (user?['name'] ?? json['userName']) as String,
      userAvatar: (user?['avatar'] ?? json['userAvatar']) as String?,
      share: double.parse(json['share'].toString()),
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
