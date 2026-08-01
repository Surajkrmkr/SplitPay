import 'transaction_model.dart';

/// Represents a transaction candidate extracted from a bank or UPI SMS message.
class ParsedSmsTransaction {
  final String id;
  final String sender;
  final String body;
  final double amount;
  final String title;
  final TransactionType type;
  final DateTime date;
  final Category category;
  final bool isSelected;
  final bool isImported;

  const ParsedSmsTransaction({
    required this.id,
    required this.sender,
    required this.body,
    required this.amount,
    required this.title,
    required this.type,
    required this.date,
    required this.category,
    this.isSelected = true,
    this.isImported = false,
  });

  ParsedSmsTransaction copyWith({
    String? id,
    String? sender,
    String? body,
    double? amount,
    String? title,
    TransactionType? type,
    DateTime? date,
    Category? category,
    bool? isSelected,
    bool? isImported,
  }) {
    return ParsedSmsTransaction(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      type: type ?? this.type,
      date: date ?? this.date,
      category: category ?? this.category,
      isSelected: isSelected ?? this.isSelected,
      isImported: isImported ?? this.isImported,
    );
  }
}
