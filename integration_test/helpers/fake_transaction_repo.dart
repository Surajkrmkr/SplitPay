import 'package:mocktail/mocktail.dart';
import 'package:splitpay/data/models/transaction_model.dart';
import 'package:splitpay/data/repositories/transaction_repository.dart';
import 'package:splitpay/data/services/transaction_api_service.dart';

// Satisfies the TransactionRepository constructor without hitting real Dio.
class _FakeApiService extends Fake implements TransactionApiService {}

class FakeTransactionRepository extends TransactionRepository {
  final List<Transaction> _store;

  FakeTransactionRepository({List<Transaction> seed = const []})
      : _store = List.of(seed),
        super(_FakeApiService());

  @override
  Future<List<Transaction>> getAll() async => List.of(_store);

  @override
  Future<void> create(Transaction tx) async => _store.insert(0, tx);

  @override
  Future<void> update(Transaction tx) async {
    final idx = _store.indexWhere((t) => t.id == tx.id);
    if (idx != -1) _store[idx] = tx;
  }

  @override
  Future<void> delete(Transaction tx) async {
    _store.removeWhere((t) => t.id == tx.id);
  }
}
