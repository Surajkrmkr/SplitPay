import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/transaction_api_service.dart';

class TransactionRepository {
  final TransactionApiService _api;

  TransactionRepository(this._api);

  Future<List<Transaction>> getAll() async {
    final allTxs = <ServerTransaction>[];
    int page = 1;
    const limit = 100;
    while (page <= 50) {
      final pageTxs = await _api.getTransactions(page: page, limit: limit);
      allTxs.addAll(pageTxs);
      if (pageTxs.length < limit) break;
      page++;
    }
    return allTxs.map((s) => s.toApiTransaction()).toList();
  }

  Future<void> create(Transaction tx) async {
    await _api.createTransaction(tx);
  }

  Future<void> update(Transaction tx) async {
    await _api.updateTransaction(tx.serverId!, tx);
  }

  Future<void> delete(Transaction tx) async {
    await _api.deleteTransaction(tx.serverId!);
  }

  Future<ImportResult> importAll(List<Transaction> transactions) async {
    return _api.importTransactions(transactions);
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(transactionApiServiceProvider));
});
