import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget_model.dart';
import '../services/budget_api_service.dart';

class BudgetRepository {
  final BudgetApiService _api;

  BudgetRepository(this._api);

  Future<List<Budget>> getAll() async {
    final serverBudgets = await _api.getBudgets();
    return serverBudgets.map((s) => s.toBudget()).toList();
  }

  Future<void> create(Budget budget) async {
    await _api.createBudget(budget);
  }

  Future<void> update(Budget budget) async {
    await _api.updateBudget(budget.id, budget);
  }

  Future<void> delete(String id) async {
    await _api.deleteBudget(id);
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(budgetApiServiceProvider));
});
