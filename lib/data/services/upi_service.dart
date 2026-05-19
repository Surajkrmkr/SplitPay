import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:upi_pro_sdk/upi_pro_sdk.dart';

export 'package:upi_pro_sdk/upi_pro_sdk.dart'
    show UpiApp, UpiStatus, UpiResponse, UpiPaymentRequest;

enum UpiTxnStatus { success, failure, submitted, cancelled }

class UpiTxnResult {
  final UpiTxnStatus status;
  final String? transactionId;
  final String? approvalRefNo;

  const UpiTxnResult({
    required this.status,
    this.transactionId,
    this.approvalRefNo,
  });
}

class UpiQrData {
  final String upiId;
  final String? name;
  final String? amount;
  final String? note;

  const UpiQrData({
    required this.upiId,
    this.name,
    this.amount,
    this.note,
  });
}

class UpiService {
  final UpiProSdk _sdk = UpiProSdk();

  Future<List<UpiApp>> getInstalledApps() async {
    try {
      return await _sdk.getInstalledApps();
    } catch (_) {
      return [];
    }
  }

  Future<UpiTxnResult> initiatePayment({
    required UpiApp app,
    required String receiverUpiId,
    required String receiverName,
    required double amount,
    String? note,
  }) async {
    final request = UpiPaymentRequest(
      upiId: receiverUpiId.trim(),
      name: receiverName,
      amount: amount,
      note: note,
    );

    try {
      final response = await _sdk.pay(request, app: app);
      final txnId = response.txnId ?? response.approvalRefNo;

      return UpiTxnResult(
        status: switch (response.status) {
          UpiStatus.success => UpiTxnStatus.success,
          UpiStatus.pending => UpiTxnStatus.submitted,
          _ => UpiTxnStatus.failure,
        },
        transactionId: txnId,
        approvalRefNo: response.approvalRefNo,
      );
    } on PaymentCancelledException {
      return const UpiTxnResult(status: UpiTxnStatus.cancelled);
    } on TimeoutException {
      return const UpiTxnResult(status: UpiTxnStatus.cancelled);
    } on AppNotRespondingException {
      return const UpiTxnResult(status: UpiTxnStatus.cancelled);
    } on NoUpiAppFoundException {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    } on UpiSdkException {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    } catch (_) {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    }
  }

  /// Validates UPI ID against the same regex used by the SDK.
  static bool isValidUpiId(String upiId) {
    final trimmed = upiId.trim();
    return RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$').hasMatch(trimmed);
  }

  /// Parses a UPI QR payload: upi://pay?pa=...&pn=...&am=...
  static UpiQrData? parseUpiQr(String raw) {
    if (!raw.startsWith('upi://')) return null;
    try {
      final uri = Uri.parse(raw);
      final upiId = uri.queryParameters['pa'];
      if (upiId == null || upiId.isEmpty) return null;
      return UpiQrData(
        upiId: upiId,
        name: uri.queryParameters['pn'],
        amount: uri.queryParameters['am'],
        note: uri.queryParameters['tn'],
      );
    } catch (_) {
      return null;
    }
  }
}

final upiServiceProvider = Provider<UpiService>((_) => UpiService());
