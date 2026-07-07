import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:upi_intent/upi_intent.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:upi_intent/upi_intent.dart' show UpiApp, UpiResponse;

// iOS packageName -> URL scheme, matching upi_intent's own iOS detection list
// (ios/Classes/UpiIntentPlugin.swift). Used to work around that plugin
// ignoring the picked app on iOS — see the class doc below.
const _iosSchemeByPackage = <String, String>{
  'com.google.GooglePayIndia': 'gpay',
  'com.phonepe.PhonePeApp': 'phonepe',
  'net.one97.paytm': 'paytmmp',
  'com.amazon.AmazonIN': 'amznmobile',
  'in.gov.uidai.BHIMApp': 'bhim',
};

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

// Known upi_intent (1.0.1, latest on pub.dev) limitations on iOS:
//  - App detection relies on canOpenURL against a fixed scheme list
//    (gpay://, phonepe://, paytmmp://, amznmobile://, bhim://), gated by
//    LSApplicationQueriesSchemes in Info.plist — apps outside that list are
//    never detected, and none of iOS's own OS-level installed-app info is
//    available (no equivalent of Android's PackageManager query).
//  - UpiIntent.payWithApp's native iOS side never reads which app was picked
//    — it only opens the generic upi://pay URL, which iOS then resolves to
//    whichever installed app claims that bare scheme (e.g. WhatsApp Pay),
//    regardless of the app the user tapped. We work around this below by
//    scheme-swapping to the picked app's own URI scheme and launching that
//    directly, the same way the Android intent targets a specific package.
//  - A successful iOS launch never returns real transaction data; the
//    backend must reconcile the actual outcome later.
class UpiService {
  Future<List<UpiApp>> getInstalledApps() async {
    try {
      return await UpiIntent.getInstalledApps();
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
    final payment = UpiPayment(
      payeeVpa: receiverUpiId.trim(),
      payeeName: receiverName,
      amount: amount,
      transactionNote: note,
    );

    try {
      if (Platform.isIOS) {
        return await _payOnIOS(app: app, payment: payment)
            .timeout(const Duration(seconds: 90));
      }

      final response = await UpiIntent.payWithApp(payment: payment, app: app)
          .timeout(const Duration(seconds: 90));

      if (response == null) {
        return const UpiTxnResult(status: UpiTxnStatus.cancelled);
      }

      final txnId = response.transactionId ?? response.approvalRefNo;
      return UpiTxnResult(
        status: switch (response.status) {
          UpiTransactionStatus.success => UpiTxnStatus.success,
          UpiTransactionStatus.submitted => UpiTxnStatus.submitted,
          UpiTransactionStatus.unknown => UpiTxnStatus.submitted,
          UpiTransactionStatus.failure => UpiTxnStatus.failure,
        },
        transactionId: txnId,
        approvalRefNo: response.approvalRefNo,
      );
    } on TimeoutException {
      return const UpiTxnResult(status: UpiTxnStatus.cancelled);
    } on UpiException {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    } on PlatformException {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    } catch (_) {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    }
  }

  /// Launches the picked app's own URI scheme directly, since upi_intent's
  /// iOS native code ignores which app was selected (see class doc above).
  Future<UpiTxnResult> _payOnIOS({
    required UpiApp app,
    required UpiPayment payment,
  }) async {
    final scheme = _iosSchemeByPackage[app.packageName];
    if (scheme == null) {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    }

    final genericUrl = Uri.parse(UpiIntent.buildUpiUrl(payment));
    final appUrl = genericUrl.replace(scheme: scheme);

    final launched = await launchUrl(
      appUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      return const UpiTxnResult(status: UpiTxnStatus.failure);
    }

    // iOS never hands back real transaction data — the backend must
    // reconcile the actual outcome later.
    return const UpiTxnResult(status: UpiTxnStatus.submitted);
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
