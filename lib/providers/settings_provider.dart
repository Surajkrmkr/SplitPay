import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_constants.dart';
import '../core/storage/preferences_service.dart';
import '../core/storage/token_storage.dart';
import '../data/models/custom_category.dart';
import '../data/models/transaction_model.dart';

// ─── Onboarding ───────────────────────────────────────────────────────────────

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier()
      : super(PreferencesService.get<bool>('onboarding_completed') ?? false);

  Future<void> complete() async {
    state = true;
    await PreferencesService.set('onboarding_completed', true);
  }
}

final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingNotifier, bool>(
        (ref) => OnboardingNotifier());

// ─── Currency ─────────────────────────────────────────────────────────────────

class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier()
      : super(PreferencesService.get<String>('currency') ?? '\$');

  Future<void> setCurrency(String symbol) async {
    state = symbol;
    await PreferencesService.set('currency', symbol);
  }
}

final currencyProvider = StateNotifierProvider<CurrencyNotifier, String>(
  (ref) => CurrencyNotifier(),
);

// ─── Custom Categories (API-backed) ───────────────────────────────────────────

class CustomCategoriesNotifier extends StateNotifier<List<CustomCategory>> {
  CustomCategoriesNotifier(this._dio, this._tokenStorage) : super([]) {
    _load();
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<void> _load() async {
    // Invalidated (and, if still watched by a kept-alive tab, eagerly
    // rebuilt) as part of logout/session-expiry cleanup — skip the fetch
    // once there's no token so that doesn't fire a doomed API call.
    if (!await _tokenStorage.hasTokens()) return;
    try {
      final res = await _dio.get(ApiConstants.categories);
      final list = res.data['data'] as List<dynamic>;
      state = list
          .map((e) => CustomCategory.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> add(CustomCategory cat) async {
    try {
      final res = await _dio.post(ApiConstants.categories, data: cat.toMap());
      final created =
          CustomCategory.fromMap(res.data['data'] as Map<String, dynamic>);
      state = [...state, created];
    } catch (_) {}
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete(ApiConstants.categoryById(id));
      state = state.where((c) => c.id != id).toList();
    } catch (_) {}
  }
}

final customCategoriesProvider =
    StateNotifierProvider<CustomCategoriesNotifier, List<CustomCategory>>(
  (ref) => CustomCategoriesNotifier(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  ),
);

// ─── Hidden Categories ────────────────────────────────────────────────────────

class HiddenCategoriesNotifier extends StateNotifier<Set<String>> {
  HiddenCategoriesNotifier() : super({}) {
    _load();
  }

  void _load() {
    final stored = PreferencesService.getStringList('hiddenCategories');
    state = (stored?.toSet() ?? {})..remove(Category.other.name);
  }

  Future<void> toggle(Category category) async {
    // "Other" is the fallback bucket custom categories map to — it must
    // always stay visible.
    if (category == Category.other) return;
    final name = category.name;
    state =
        state.contains(name) ? ({...state}..remove(name)) : {...state, name};
    await PreferencesService.set('hiddenCategories', state.toList());
  }

  bool isHidden(Category category) => state.contains(category.name);
}

final hiddenCategoriesProvider =
    StateNotifierProvider<HiddenCategoriesNotifier, Set<String>>(
  (ref) => HiddenCategoriesNotifier(),
);

// ─── Biometric Lock ───────────────────────────────────────────────────────────

class BiometricLockNotifier extends StateNotifier<bool> {
  BiometricLockNotifier()
      : super(PreferencesService.get<bool>('biometric_lock') ?? false);

  Future<void> setEnabled(bool value) async {
    state = value;
    await PreferencesService.set('biometric_lock', value);
  }
}

final biometricLockProvider =
    StateNotifierProvider<BiometricLockNotifier, bool>(
        (ref) => BiometricLockNotifier());
