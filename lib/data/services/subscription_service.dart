import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionProducts {
  static const monthly = 'splitpay_pro_monthly';
  static const yearly = 'splitpay_pro_yearly';
  static const all = {monthly, yearly};
}

class SubscriptionState {
  const SubscriptionState({
    this.isStoreAvailable = false,
    this.isLoading = true,
    this.isRestoring = false,
    this.isPurchasing = false,
    this.isPremium = false,
    this.products = const [],
    this.notFoundProductIds = const {},
    this.activeProductId,
    this.error,
  });

  final bool isStoreAvailable;
  final bool isLoading;
  final bool isRestoring;
  final bool isPurchasing;
  final bool isPremium;
  final List<ProductDetails> products;
  final Set<String> notFoundProductIds;
  final String? activeProductId;
  final String? error;

  SubscriptionState copyWith({
    bool? isStoreAvailable,
    bool? isLoading,
    bool? isRestoring,
    bool? isPurchasing,
    bool? isPremium,
    List<ProductDetails>? products,
    Set<String>? notFoundProductIds,
    String? activeProductId,
    bool clearActiveProductId = false,
    String? error,
    bool clearError = false,
  }) {
    return SubscriptionState(
      isStoreAvailable: isStoreAvailable ?? this.isStoreAvailable,
      isLoading: isLoading ?? this.isLoading,
      isRestoring: isRestoring ?? this.isRestoring,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isPremium: isPremium ?? this.isPremium,
      products: products ?? this.products,
      notFoundProductIds: notFoundProductIds ?? this.notFoundProductIds,
      activeProductId:
          clearActiveProductId ? null : activeProductId ?? this.activeProductId,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController({InAppPurchase? store})
      : _store = store ?? InAppPurchase.instance,
        super(const SubscriptionState()) {
    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: _handlePurchaseStreamError,
    );
    unawaited(loadStoreProducts());
  }

  final InAppPurchase _store;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  Future<void> loadStoreProducts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final available = await _store.isAvailable();
      if (!available) {
        state = state.copyWith(
          isStoreAvailable: false,
          isLoading: false,
          error: 'The app store is unavailable on this device.',
        );
        return;
      }

      final response =
          await _store.queryProductDetails(SubscriptionProducts.all);
      if (response.error != null) {
        throw StateError(response.error!.message);
      }

      final productsById = <String, ProductDetails>{};
      for (final product in response.productDetails) {
        productsById.putIfAbsent(product.id, () => product);
      }
      state = state.copyWith(
        isStoreAvailable: true,
        isLoading: false,
        products: productsById.values.toList(),
        notFoundProductIds: response.notFoundIDs.toSet(),
      );

      await restorePurchases();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load subscriptions: $error',
      );
    }
  }

  Future<void> purchase(ProductDetails product) async {
    if (!SubscriptionProducts.all.contains(product.id)) {
      state =
          state.copyWith(error: 'Unknown subscription product: ${product.id}');
      return;
    }
    if (!state.isStoreAvailable || state.isPurchasing || state.isPremium) {
      return;
    }
    state = state.copyWith(isPurchasing: true, clearError: true);
    try {
      final launched = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!launched) {
        state = state.copyWith(
          isPurchasing: false,
          error: 'The store could not start this purchase. Please try again.',
        );
      }
    } catch (error) {
      state = state.copyWith(
        isPurchasing: false,
        error: 'Could not start purchase: $error',
      );
    }
  }

  Future<void> restorePurchases() async {
    if (!state.isStoreAvailable) return;
    final wasPremium = state.isPremium;
    final previousProductId = state.activeProductId;
    state = state.copyWith(
      isRestoring: true,
      isPremium: false,
      clearActiveProductId: true,
      clearError: true,
    );
    try {
      await _store.restorePurchases();
    } catch (error) {
      state = state.copyWith(
        isPremium: state.isPremium || wasPremium,
        activeProductId: state.activeProductId ?? previousProductId,
        error: 'Could not restore purchases: $error',
      );
    } finally {
      state = state.copyWith(isRestoring: false);
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (!SubscriptionProducts.all.contains(purchase.productID)) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(isPurchasing: true, clearError: true);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          state = state.copyWith(
            isPremium: true,
            isPurchasing: false,
            activeProductId: purchase.productID,
            clearError: true,
          );
        case PurchaseStatus.error:
          state = state.copyWith(
            isPurchasing: false,
            error:
                purchase.error?.message ?? 'The purchase could not complete.',
          );
        case PurchaseStatus.canceled:
          state = state.copyWith(isPurchasing: false);
      }

      if (purchase.pendingCompletePurchase &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        unawaited(_completePurchase(purchase));
      }
    }
  }

  Future<void> _completePurchase(PurchaseDetails purchase) async {
    try {
      await _store.completePurchase(purchase);
    } catch (error) {
      state =
          state.copyWith(error: 'Could not finish store transaction: $error');
    }
  }

  void _handlePurchaseStreamError(Object error, StackTrace stackTrace) {
    state = state.copyWith(
      isPurchasing: false,
      error: 'The store purchase stream failed: $error',
    );
  }

  @override
  void dispose() {
    _purchaseSubscription.cancel();
    super.dispose();
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>(
  (ref) => SubscriptionController(),
);
