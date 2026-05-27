import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_constants.dart';
import '../models/transaction_model.dart';

/// DTO returned by the server for a single transaction.
class ServerTransaction {
  final String id;
  final String localId;
  final double amount;
  final String type;
  final String categoryKey;
  final String? customCategoryId;
  final String? appIcon;
  final String? note;
  final DateTime date;
  final String recurrence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const ServerTransaction({
    required this.id,
    required this.localId,
    required this.amount,
    required this.type,
    required this.categoryKey,
    this.customCategoryId,
    this.appIcon,
    this.note,
    required this.date,
    required this.recurrence,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory ServerTransaction.fromJson(Map<String, dynamic> json) {
    return ServerTransaction(
      id: json['id'] as String,
      localId: json['localId'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['transactionType'] as String? ?? json['type'] as String,
      categoryKey: json['categoryKey'] as String,
      customCategoryId: json['customCategoryId'] as String?,
      appIcon: json['appIcon'] as String?,
      note: json['note'] as String?,
      date: DateTime.parse(json['date'] as String),
      recurrence: json['recurrence'] as String? ?? 'NONE',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }

  /// Converts to a local [Transaction], using the local ID as the key.
  Transaction toLocalTransaction() {
    final txType = type == 'INCOME' ? TransactionType.income : TransactionType.expense;
    final cat = _categoryFromKey(categoryKey);
    final rec = _recurrenceFromServer(recurrence);
    return Transaction(
      id: localId,
      serverId: id,
      amount: amount,
      type: txType,
      category: cat,
      customCategoryId: customCategoryId,
      appIcon: appIcon,
      note: note,
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt,
      recurrence: rec,
      syncStatus: deletedAt != null ? SyncStatus.pendingDelete : SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
      isDeleted: deletedAt != null,
    );
  }

  static Category _categoryFromKey(String key) {
    try {
      return Category.values.byName(key);
    } catch (_) {
      return Category.other;
    }
  }

  static RecurrenceType _recurrenceFromServer(String value) {
    switch (value.toUpperCase()) {
      case 'DAILY': return RecurrenceType.daily;
      case 'WEEKLY': return RecurrenceType.weekly;
      case 'MONTHLY': return RecurrenceType.monthly;
      case 'YEARLY': return RecurrenceType.yearly;
      default: return RecurrenceType.none;
    }
  }
}

class SyncPushResult {
  final List<SyncItemResult> transactions;
  final List<SyncItemResult> categories;
  final DateTime syncedAt;

  const SyncPushResult({
    required this.transactions,
    required this.categories,
    required this.syncedAt,
  });

  factory SyncPushResult.fromJson(Map<String, dynamic> json) {
    return SyncPushResult(
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => SyncItemResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => SyncItemResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      syncedAt: DateTime.parse(json['syncedAt'] as String),
    );
  }
}

class SyncItemResult {
  final String localId;
  final String serverId;
  final String action;
  final bool success;
  final String? error;

  const SyncItemResult({
    required this.localId,
    required this.serverId,
    required this.action,
    required this.success,
    this.error,
  });

  factory SyncItemResult.fromJson(Map<String, dynamic> json) {
    return SyncItemResult(
      localId: json['localId'] as String,
      serverId: json['serverId'] as String? ?? '',
      action: json['action'] as String,
      success: json['success'] as bool,
      error: json['error'] as String?,
    );
  }
}

class TransactionApiService {
  final Dio _dio;

  TransactionApiService(this._dio);

  Future<SyncPushResult> pushTransactions(List<Transaction> pending) async {
    final payload = {
      'transactions': pending.map((t) => t.toSyncPayload()).toList(),
      'categories': <dynamic>[],
    };
    final res = await _dio.post(ApiConstants.syncPush, data: payload);
    return SyncPushResult.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<ServerTransaction>> pullChanges(DateTime? since) async {
    final params = since != null
        ? {'since': since.toUtc().toIso8601String()}
        : <String, dynamic>{};
    final res = await _dio.get(ApiConstants.syncPull, queryParameters: params);
    final data = res.data['data'] as Map<String, dynamic>;
    final list = data['transactions'] as List<dynamic>? ?? [];
    return list
        .map((e) => ServerTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ServerTransaction>> getTransactions({
    int page = 1,
    int limit = 50,
    String? type,
    String? categoryKey,
    String? search,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (type != null) 'type': type,
      if (categoryKey != null) 'categoryKey': categoryKey,
      if (search != null) 'search': search,
      if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
    };
    final res = await _dio.get(ApiConstants.transactions, queryParameters: params);
    final list = res.data['data'] as List<dynamic>;
    return list
        .map((e) => ServerTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final transactionApiServiceProvider = Provider<TransactionApiService>((ref) {
  return TransactionApiService(ref.watch(dioProvider));
});
