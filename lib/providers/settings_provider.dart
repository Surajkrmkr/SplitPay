import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/custom_category.dart';
import '../data/models/transaction_model.dart';
import '../data/services/hive_service.dart';

final onboardingCompletedProvider = StateProvider<bool>((_) => false);

final currencyProvider = StateNotifierProvider<CurrencyNotifier, String>(
  (ref) => CurrencyNotifier(),
);

class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier() : super('\$') {
    _load();
  }

  void _load() {
    state = HiveService.getSetting<String>('currency') ?? '\$';
  }

  Future<void> setCurrency(String symbol) async {
    state = symbol;
    await HiveService.setSetting('currency', symbol);
  }
}

final customCategoriesProvider =
    StateNotifierProvider<CustomCategoriesNotifier, List<CustomCategory>>(
  (ref) => CustomCategoriesNotifier(),
);

class CustomCategoriesNotifier extends StateNotifier<List<CustomCategory>> {
  CustomCategoriesNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = HiveService.getCustomCategories();
  }

  Future<void> add(CustomCategory cat) async {
    await HiveService.saveCustomCategory(cat);
    _load();
  }

  Future<void> remove(String id) async {
    await HiveService.deleteCustomCategory(id);
    _load();
  }
}

final hiddenCategoriesProvider =
    StateNotifierProvider<HiddenCategoriesNotifier, Set<String>>(
  (ref) => HiddenCategoriesNotifier(),
);

class HiddenCategoriesNotifier extends StateNotifier<Set<String>> {
  HiddenCategoriesNotifier() : super({}) {
    _load();
  }

  void _load() {
    final stored = HiveService.getSetting<List>('hiddenCategories');
    state = stored?.map((e) => e as String).toSet() ?? {};
  }

  Future<void> toggle(Category category) async {
    final name = category.name;
    state = state.contains(name)
        ? ({...state}..remove(name))
        : {...state, name};
    await HiveService.setSetting('hiddenCategories', state.toList());
  }

  bool isHidden(Category category) => state.contains(category.name);
}
