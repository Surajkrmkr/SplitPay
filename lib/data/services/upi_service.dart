import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:upi_pro_sdk/upi_pro_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:upi_pro_sdk/upi_pro_sdk.dart' show UpiApp, UpiResponse;

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

const _iosSchemeByPackage = <String, String>{
  'com.google.GooglePayIndia': 'gpay',
  'com.phonepe.PhonePeApp': 'phonepe',
  'net.one97.paytm': 'paytmmp',
  'com.amazon.AmazonIN': 'amznmobile',
  'in.gov.uidai.BHIMApp': 'bhim',
  'com.dreamplug.cred': 'cred',
};

class UpiService {
  final _sdk = UpiProSdk();

  Future<List<UpiApp>> getInstalledApps() async {
    try {
      return await _sdk.getInstalledApps();
    } catch (_) {
      return [];
    }
  }

  /// Opens the bare UPI app scheme without pre-filled intent parameters so the user
  /// can paste the copied UPI ID and edit transaction amount freely inside the app.
  Future<bool> openBareUpiApp(UpiApp app) async {
    final scheme = app.scheme ?? _iosSchemeByPackage[app.packageName];
    if (scheme != null && scheme.isNotEmpty) {
      try {
        final url = Uri.parse('$scheme://');
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    try {
      return await launchUrl(Uri.parse('upi://pay'), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
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
      final response = await _sdk.pay(
        request,
        app: app,
        timeoutSeconds: 90,
      );

      final txnId = response.txnId ?? response.approvalRefNo;
      return UpiTxnResult(
        status: switch (response.status) {
          UpiStatus.success => UpiTxnStatus.success,
          UpiStatus.pending => UpiTxnStatus.submitted,
          UpiStatus.failure => UpiTxnStatus.failure,
          _ => UpiTxnStatus.submitted,
        },
        transactionId: txnId,
        approvalRefNo: response.approvalRefNo,
      );
    } on PaymentCancelledException {
      return const UpiTxnResult(status: UpiTxnStatus.cancelled);
    } on TimeoutException {
      return const UpiTxnResult(status: UpiTxnStatus.cancelled);
    } on UpiSdkException {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    } on PlatformException {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    } catch (_) {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    }
  }

  /// Validates UPI ID.
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
