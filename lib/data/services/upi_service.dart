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

// Known upi_pro_sdk (0.1.3, latest on pub.dev) limitations on iOS:
//  - Google Pay is never detected: the plugin's native Swift app-detection list
//    uses scheme "gpay", but its own Dart trusted-apps allowlist expects "tez"
//    for Google Pay, so the mismatch silently filters it out of
//    getInstalledApps() even when installed. BHIM's scheme matches on both
//    sides, so its absence just means the app isn't installed on-device.
//  - Paytm/PhonePe may show their own "unsafe/suspicious payment" warning:
//    the plugin launches a generic upi://pay URI with only the scheme swapped
//    to the target app, with no transaction reference or signed metadata, so
//    the receiving app can't verify the deep link's origin. This is inherent
//    to the plugin's scheme-swap approach on iOS (no equivalent of Android's
//    system-level UPI Intent) — fixing it would require forking the plugin.
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
