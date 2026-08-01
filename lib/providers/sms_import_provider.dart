import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/parsed_sms_transaction.dart';
import '../data/models/transaction_model.dart';
import '../data/services/sms_reader_service.dart';
import 'transaction_provider.dart';

class SmsImportState {
  final SmsPermissionState permissionState;
  final bool isLoading;
  final bool isSyncing;
  final List<ParsedSmsTransaction> transactions;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final int lastImportedCount;

  const SmsImportState({
    this.permissionState = SmsPermissionState.denied,
    this.isLoading = false,
    this.isSyncing = false,
    this.transactions = const [],
    this.lastSyncedAt,
    this.errorMessage,
    this.lastImportedCount = 0,
  });

  int get selectedCount =>
      transactions.where((t) => t.isSelected && !t.isImported).length;

  int get unimportedCount => transactions.where((t) => !t.isImported).length;

  SmsImportState copyWith({
    SmsPermissionState? permissionState,
    bool? isLoading,
    bool? isSyncing,
    List<ParsedSmsTransaction>? transactions,
    DateTime? lastSyncedAt,
    String? errorMessage,
    int? lastImportedCount,
  }) {
    return SmsImportState(
      permissionState: permissionState ?? this.permissionState,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      transactions: transactions ?? this.transactions,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      lastImportedCount: lastImportedCount ?? this.lastImportedCount,
    );
  }
}

class SmsImportNotifier extends StateNotifier<SmsImportState> {
  final SmsReaderService _smsReader;
  final TransactionNotifier _transactionNotifier;

  SmsImportNotifier(this._smsReader, this._transactionNotifier)
      : super(const SmsImportState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final perm = await _smsReader.checkPermission();
      state = state.copyWith(permissionState: perm);
      if (perm == SmsPermissionState.granted) {
        await syncMessages();
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to initialize SMS reader: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> requestPermissionAndFetch() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final perm = await _smsReader.requestPermission();
      state = state.copyWith(permissionState: perm);
      if (perm == SmsPermissionState.granted) {
        await syncMessages();
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Permission request failed: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Syncs latest SMS messages from device inbox.
  Future<void> syncMessages() async {
    state = state.copyWith(isSyncing: true, errorMessage: null);
    try {
      final candidates = await _smsReader.fetchTransactionMessages();
      state = state.copyWith(
        transactions: candidates,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error syncing SMS messages: $e');
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  void toggleSelection(String id) {
    state = state.copyWith(
      transactions: state.transactions.map((t) {
        if (t.id == id && !t.isImported) {
          return t.copyWith(isSelected: !t.isSelected);
        }
        return t;
      }).toList(),
    );
  }

  void selectAll(bool select) {
    state = state.copyWith(
      transactions: state.transactions.map((t) {
        if (!t.isImported) {
          return t.copyWith(isSelected: select);
        }
        return t;
      }).toList(),
    );
  }

  void updateCategory(String id, Category category) {
    state = state.copyWith(
      transactions: state.transactions.map((t) {
        if (t.id == id) {
          return t.copyWith(category: category);
        }
        return t;
      }).toList(),
    );
  }

  void updateTitle(String id, String newTitle) {
    state = state.copyWith(
      transactions: state.transactions.map((t) {
        if (t.id == id) {
          return t.copyWith(title: newTitle);
        }
        return t;
      }).toList(),
    );
  }

  /// Imports all currently selected candidate transactions into personal expenses.
  Future<int> importSelected() async {
    final selected = state.transactions
        .where((t) => t.isSelected && !t.isImported)
        .toList();

    if (selected.isEmpty) return 0;

    const uuid = Uuid();
    final now = DateTime.now();

    for (final item in selected) {
      final tx = Transaction(
        id: uuid.v4(),
        amount: item.amount,
        type: item.type,
        category: item.category,
        note: item.title,
        date: item.date,
        createdAt: now,
      );
      await _transactionNotifier.add(tx);
    }

    final importedIds = selected.map((t) => t.id).toList();
    await _smsReader.markSmsAsImported(importedIds);

    // Update state to mark items as imported
    final updatedList = state.transactions.map((t) {
      if (importedIds.contains(t.id)) {
        return t.copyWith(isImported: true, isSelected: false);
      }
      return t;
    }).toList();

    state = state.copyWith(
      transactions: updatedList,
      lastImportedCount: selected.length,
    );

    return selected.length;
  }
}

final smsImportProvider =
    StateNotifierProvider<SmsImportNotifier, SmsImportState>((ref) {
  final reader = ref.watch(smsReaderServiceProvider);
  final txNotifier = ref.watch(transactionProvider.notifier);
  return SmsImportNotifier(reader, txNotifier);
});
