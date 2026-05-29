import 'expense_participant_model.dart';

class GroupExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String paidById;
  final String paidByName;
  final String? paidByAvatar;
  final String splitType;
  final List<ExpenseParticipantModel> participants;
  final String? notes;
  final String? appIcon;
  final DateTime date;
  final DateTime createdAt;

  const GroupExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidById,
    required this.paidByName,
    this.paidByAvatar,
    required this.splitType,
    required this.participants,
    this.notes,
    this.appIcon,
    required this.date,
    required this.createdAt,
  });

  factory GroupExpenseModel.fromJson(Map<String, dynamic> json) {
    final paidBy = json['paidBy'] as Map<String, dynamic>?;
    return GroupExpenseModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      title: json['title'] as String,
      amount: double.parse(json['amount'].toString()),
      paidById: json['paidById'] as String,
      paidByName: (paidBy?['name'] ?? json['paidByName']) as String,
      paidByAvatar: (paidBy?['avatar'] ?? json['paidByAvatar']) as String?,
      splitType: json['splitType'] as String? ?? 'EQUAL',
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((p) =>
              ExpenseParticipantModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      appIcon: json['appIcon'] as String?,
      date: DateTime.parse(json['date'] as String).toLocal(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidById': paidById,
      'paidByName': paidByName,
      'paidByAvatar': paidByAvatar,
      'splitType': splitType,
      'participants': participants.map((p) => p.toJson()).toList(),
      'notes': notes,
      'appIcon': appIcon,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  double shareForUser(String userId) {
    final participant = participants.where((p) => p.userId == userId).firstOrNull;
    return participant?.share ?? 0.0;
  }

  GroupExpenseModel copyWithAppIcon(String? appIcon) => GroupExpenseModel(
        id: id,
        groupId: groupId,
        title: title,
        amount: amount,
        paidById: paidById,
        paidByName: paidByName,
        paidByAvatar: paidByAvatar,
        splitType: splitType,
        participants: participants,
        notes: notes,
        appIcon: appIcon,
        date: date,
        createdAt: createdAt,
      );
}
