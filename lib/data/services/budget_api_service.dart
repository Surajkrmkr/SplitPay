import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_constants.dart';
import '../models/budget_model.dart';

/// DTO returned by the server for a single budget.
class ServerBudget {
  final String id;
  final String title;
  final double amount;
  final List<String> categoryIds;
  final String period;
  final DateTime startDate;
  final int colorValue;
  final int iconCodePoint;
  final bool isArchived;
  final double alertThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServerBudget({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryIds,
    required this.period,
    required this.startDate,
    required this.colorValue,
    required this.iconCodePoint,
    required this.isArchived,
    required this.alertThreshold,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServerBudget.fromJson(Map<String, dynamic> json) {
    return ServerBudget(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: double.parse(json['amount'].toString()),
      categoryIds:
          (json['categoryIds'] as List<dynamic>?)?.cast<String>() ?? [],
      period: json['period'] as String,
      startDate: DateTime.parse(json['startDate'] as String).toLocal(),
      colorValue: (json['colorValue'] as int).toUnsigned(32),
      iconCodePoint: json['iconCodePoint'] as int,
      isArchived: json['isArchived'] as bool? ?? false,
      alertThreshold: double.parse(json['alertThreshold'].toString()),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  Budget toBudget() {
    return Budget(
      id: id,
      title: title,
      amount: amount,
      categoryIds: categoryIds,
      period: BudgetPeriod.values.byName(period.toLowerCase()),
      startDate: startDate,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      isArchived: isArchived,
      alertThreshold: alertThreshold,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class BudgetApiService {
  final Dio _dio;

  BudgetApiService(this._dio);

  Future<List<ServerBudget>> getBudgets() async {
    final res = await _dio.get(ApiConstants.budgets);
    final list = res.data['data'] as List<dynamic>;
    return list
        .map((e) => ServerBudget.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createBudget(Budget budget) async {
    await _dio.post(ApiConstants.budgets, data: _toPayload(budget));
  }

  Future<void> updateBudget(String id, Budget budget) async {
    await _dio.patch(ApiConstants.budgetById(id), data: _toPayload(budget));
  }

  Future<void> deleteBudget(String id) async {
    await _dio.delete(ApiConstants.budgetById(id));
  }

  static Map<String, dynamic> _toPayload(Budget budget) => {
        'title': budget.title,
        'amount': budget.amount,
        'categoryIds': budget.categoryIds,
        'period': budget.period.name.toUpperCase(),
        'startDate': budget.startDate.toUtc().toIso8601String(),
        // colorValue is a full ARGB int (e.g. Color.toARGB32()); the server's
        // `colorValue` column is a signed 32-bit INT4, so it must be sent as
        // a signed value and converted back to unsigned when read.
        'colorValue': budget.colorValue.toSigned(32),
        'iconCodePoint': budget.iconCodePoint,
        'isArchived': budget.isArchived,
        'alertThreshold': budget.alertThreshold,
      };
}

final budgetApiServiceProvider = Provider<BudgetApiService>((ref) {
  return BudgetApiService(ref.watch(dioProvider));
});
