import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_constants.dart';
import '../../core/services/offline_sync_queue_service.dart';
import '../../providers/connectivity_provider.dart';
import '../models/settlement_model.dart';
import '../services/group_api_service.dart';
import '../services/upi_service.dart';

/// Orchestrates UPI payment + backend settlement recording.
/// Prevents duplicate settlements via an in-flight guard.
class PaymentRepository {
  final UpiService _upiService;
  final GroupApiService _apiService;
  final OfflineSyncQueueService? _queueService;

  // Guard against concurrent settlement calls for the same debt.
  final _inFlight = <String>{};

  PaymentRepository(this._upiService, this._apiService, [this._queueService]);

  /// Launch a UPI app and, on SUCCESS, automatically record a settlement.
  /// Returns [UpiTxnResult] so callers can render appropriate UI.
  Future<({UpiTxnResult txn, SettlementModel? settlement})> payViaUpi({
    required UpiApp app,
    required String groupId,
    required String payeeId,
    required String payeeUpiId,
    required String payeeName,
    required double amount,
    String? note,
  }) async {
    final dedupeKey = '$groupId:$payeeId:$amount';
    if (_inFlight.contains(dedupeKey)) {
      return (
        txn: const UpiTxnResult(status: UpiTxnStatus.failure),
        settlement: null,
      );
    }

    _inFlight.add(dedupeKey);
    try {
      final txn = await _upiService.initiatePayment(
        app: app,
        receiverUpiId: payeeUpiId,
        receiverName: payeeName,
        amount: amount,
        note: note,
      );

      SettlementModel? settlement;
      if (txn.status == UpiTxnStatus.success) {
        settlement = await _createOrQueueSettlement(
          groupId: groupId,
          payeeId: payeeId,
          amount: amount,
          notes: note,
          paymentMethod: 'UPI',
          settlementType: 'AUTO',
          transactionId: txn.transactionId,
        );
      }

      return (txn: txn, settlement: settlement);
    } finally {
      _inFlight.remove(dedupeKey);
    }
  }

  /// Record a manual (cash / offline) settlement without launching a UPI app.
  Future<SettlementModel> settleManually({
    required String groupId,
    required String payeeId,
    required double amount,
    String? notes,
  }) async {
    return _createOrQueueSettlement(
      groupId: groupId,
      payeeId: payeeId,
      amount: amount,
      notes: notes,
      paymentMethod: 'MANUAL',
      settlementType: 'MANUAL',
    );
  }

  /// Record a confirmed UPI settlement (e.g. after user redirects to UPI app).
  Future<SettlementModel> settleViaUpi({
    required String groupId,
    required String payeeId,
    required double amount,
    String? notes,
    String? transactionId,
  }) async {
    return _createOrQueueSettlement(
      groupId: groupId,
      payeeId: payeeId,
      amount: amount,
      notes: notes,
      paymentMethod: 'UPI',
      settlementType: 'UPI',
      transactionId: transactionId,
    );
  }

  Future<SettlementModel> _createOrQueueSettlement({
    required String groupId,
    required String payeeId,
    required double amount,
    String? notes,
    required String paymentMethod,
    required String settlementType,
    String? transactionId,
  }) async {
    try {
      return await _apiService.createSettlement(
        groupId: groupId,
        payeeId: payeeId,
        amount: amount,
        notes: notes,
        paymentMethod: paymentMethod,
        settlementType: settlementType,
        transactionId: transactionId,
      );
    } catch (e) {
      final queueService = _queueService;
      if (queueService != null) {
        final actionId = 'sync_set_${DateTime.now().millisecondsSinceEpoch}';
        await queueService.enqueue(
          PendingSyncAction(
            id: actionId,
            endpoint: ApiConstants.settlements,
            method: SyncHttpMethod.post,
            body: {
              'groupId': groupId,
              'payeeId': payeeId,
              'amount': amount,
              if (notes != null) 'notes': notes,
              'paymentMethod': paymentMethod,
              'settlementType': settlementType,
              if (transactionId != null) 'transactionId': transactionId,
            },
          ),
        );
      }
      final now = DateTime.now();
      return SettlementModel(
        id: 'offline_${now.millisecondsSinceEpoch}',
        groupId: groupId,
        payerId: 'user_1',
        payerName: 'You',
        payeeId: payeeId,
        payeeName: '',
        amount: amount,
        notes: notes,
        settledAt: now,
        paymentMethod: paymentMethod,
        settlementType: settlementType,
        transactionId: transactionId,
      );
    }
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(
    ref.watch(upiServiceProvider),
    ref.watch(groupApiServiceProvider),
    ref.watch(offlineSyncQueueServiceProvider),
  );
});
