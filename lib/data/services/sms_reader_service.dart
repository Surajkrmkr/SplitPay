import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/sms_category_helper.dart';
import '../models/parsed_sms_transaction.dart';
import '../models/transaction_model.dart';
import 'sms_parser_service.dart';

enum SmsPermissionState {
  granted,
  denied,
  permanentlyDenied,
  unsupported,
}

class SmsReaderService {
  final SmsParserService _parser;
  static const String _importedSmsIdsKey = 'imported_sms_message_ids_v1';

  SmsReaderService(this._parser);

  /// Checks whether SMS permission is granted, denied, or unsupported.
  Future<SmsPermissionState> checkPermission() async {
    // SMS inbox reading is restricted to Android devices.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return SmsPermissionState.unsupported;
    }

    final status = await Permission.sms.status;
    if (status.isGranted) {
      return SmsPermissionState.granted;
    } else if (status.isPermanentlyDenied) {
      return SmsPermissionState.permanentlyDenied;
    } else {
      return SmsPermissionState.denied;
    }
  }

  /// Requests SMS permission from the system.
  Future<SmsPermissionState> requestPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return SmsPermissionState.unsupported;
    }

    final status = await Permission.sms.request();
    if (status.isGranted) {
      return SmsPermissionState.granted;
    } else if (status.isPermanentlyDenied) {
      return SmsPermissionState.permanentlyDenied;
    } else {
      return SmsPermissionState.denied;
    }
  }

  /// Reads SMS messages from device inbox and extracts relevant transactions.
  Future<List<ParsedSmsTransaction>> fetchTransactionMessages() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return [];
    }

    final status = await Permission.sms.status;
    if (!status.isGranted) {
      return [];
    }

    final SmsQuery query = SmsQuery();
    final List<SmsMessage> messages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 250,
    );

    final importedIds = await getImportedSmsIds();
    final List<ParsedSmsTransaction> candidates = [];

    for (final msg in messages) {
      final body = msg.body;
      if (body == null || body.trim().isEmpty) continue;

      // ── Hard filters: drop messages that are definitely not spend alerts ──
      if (_isNoise(body)) continue;

      // ── Require explicit debit/credit financial keywords ──
      if (!_isFinancialTransaction(body)) continue;

      final parseResult = _parser.parse(body);
      if (parseResult.amount == null || parseResult.amount! <= 0) continue;

      final smsId = msg.id?.toString() ??
          '${msg.date?.millisecondsSinceEpoch ?? 0}_${body.hashCode}';
      final isImported = importedIds.contains(smsId);

      final sender = msg.address ?? 'Bank';
      final title = parseResult.title ?? _cleanSenderName(sender);
      final type = parseResult.type ?? TransactionType.expense;
      final date = parseResult.dateTime ?? msg.date ?? DateTime.now();

      final category = SmsCategoryHelper.suggestCategory(
        title: title,
        sender: sender,
        body: body,
        type: type,
      );

      candidates.add(
        ParsedSmsTransaction(
          id: smsId,
          sender: sender,
          body: body,
          amount: parseResult.amount!,
          title: title,
          type: type,
          date: date,
          category: category,
          isSelected: !isImported,
          isImported: isImported,
        ),
      );
    }

    // Sort newest first
    candidates.sort((a, b) => b.date.compareTo(a.date));
    return candidates;
  }

  // ── Noise keywords: drop immediately if body contains any of these ─────────

  // Compiled once, reused every call.
  static final RegExp _noiseRe = RegExp(
    r'\b('
    // OTPs & verification codes
    r'otp|one.?time.?password|verification code|is your (otp|code|pin)'
    r'|do not share|never share (your|this)'
    r'|transaction password|tpin'
    // Recharge reminders & telecom promos
    r'|recharge (reminder|due|now|before)|your plan (expires|will expire)'
    r'|validity (expires|ending)|renew (now|your plan)'
    r'|data (balance|pack|expires|booster)'
    r'|talk.?time|calling (pack|plan)'
    r'|your number will be (deactivated|suspended)'
    // Account balance / statement alerts (not actual transactions)
    r'|available balance|closing balance|account balance is'
    r'|your balance as on|account summary'
    // Promotional / marketing
    r'|click here|visit (our|the) (website|store)|limited (time|offer|period)'
    r'|special (offer|deal|discount)|exclusive (offer|deal)'
    r'|congratulations! you (have|are)'
    r'|cashback offer|earn (reward|point|cashback) (on|when)'
    r'|download (our|the) app|install (our|the) app'
    r'|pre-approved (loan|offer)|credit (limit increase|card offer)'
    // Delivery & logistics (not financial)
    r'|your (order|shipment|parcel|package) (has been|is|will be)'
    r'|out for delivery|delivered to|estimated delivery'
    r'|track your (order|shipment)'
    // Missed call / call back alerts
    r'|missed call|called you|please call back'
    // Login / session alerts
    r'|logged in (from|to|via)|new (login|sign.?in) detected'
    r'|login (attempt|alert)|your account (was|has been) (logged|accessed)'
    // Declined / failed / reversed transactions
    r'|declined|transaction (failed|unsuccessful|could not be processed|has been declined)'
    r'|payment (failed|declined|unsuccessful|not (processed|completed))'
    r'|transaction (reversed|reversal)|amount (reversed|refunded due to failure)'
    r'|insufficient (funds|balance)|your card has been (blocked|declined)'
    r'|unable to process|could not complete (the|your) (payment|transaction)'
    r')\b',
    caseSensitive: false,
  );

  bool _isNoise(String body) => _noiseRe.hasMatch(body);

  // ── Financial transaction keywords: must have at least one ────────────────

  static final RegExp _financialRe = RegExp(
    r'\b('
    r'debited|debit|dr\b'
    r'|credited|credit|cr\b'
    r'|paid|payment (of|made|received|successful)'
    r'|spent|purchase(d)?'
    r'|transferred|transfer (of|to|from)'
    r'|withdrawn|withdrawal'
    r'|received|deposited|refunded'
    r'|charged|deducted'
    r'|transaction (of|id|no|ref)'
    r'|sent (to|via|using)'
    r'|upi (payment|transaction|transfer)'
    r'|imps|neft|rtgs'
    r')\b',
    caseSensitive: false,
  );

  bool _isFinancialTransaction(String body) => _financialRe.hasMatch(body);

  /// Returns the set of SMS message IDs already imported into expenses.
  Future<Set<String>> getImportedSmsIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_importedSmsIdsKey) ?? [];
    return list.toSet();
  }

  /// Marks a list of SMS IDs as imported in SharedPreferences.
  Future<void> markSmsAsImported(List<String> ids) async {
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getStringList(_importedSmsIdsKey) ?? []).toSet();
    existing.addAll(ids);
    await prefs.setStringList(_importedSmsIdsKey, existing.toList());
  }

  String _cleanSenderName(String sender) {
    final clean = sender.replaceAll(RegExp(r'^[A-Za-z]{2}-'), '').trim();
    if (clean.isEmpty) return 'Bank SMS';
    return clean;
  }
}

final smsReaderServiceProvider = Provider<SmsReaderService>((ref) {
  final parser = ref.watch(smsParserServiceProvider);
  return SmsReaderService(parser);
});
