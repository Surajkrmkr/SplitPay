import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/fuzzy_date_parser.dart';
import '../models/transaction_model.dart';

/// What we managed to extract from a pasted bank/UPI SMS.
///
/// Amount and title ship as ranked candidate lists (best guess first), same
/// shape as [BillScanResult] so the confirm UI can be shared.
class SmsParseResult {
  final List<double> amountCandidates;
  final List<String> titleCandidates;
  final DateTime? dateTime;
  final TransactionType? type;
  final String rawText;

  const SmsParseResult({
    this.amountCandidates = const [],
    this.titleCandidates = const [],
    this.dateTime,
    this.type,
    required this.rawText,
  });

  double? get amount =>
      amountCandidates.isNotEmpty ? amountCandidates.first : null;
  String? get title =>
      titleCandidates.isNotEmpty ? titleCandidates.first : null;

  bool get isEmpty =>
      amount == null && title == null && dateTime == null && type == null;
  bool get hasAny => !isEmpty;
}

/// Best-effort parser for bank/UPI debit-credit alert SMS. Unlike the bill
/// scanner, the message text is short and highly templated, so this leans on
/// a handful of keyword-anchored patterns rather than positional scoring.
class SmsParserService {
  SmsParseResult parse(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    _log('▶ parse() "$normalized"');

    final type = _extractType(normalized);
    final amounts = _extractAmounts(normalized);
    final titles = _extractTitles(normalized);
    final dateTime = extractDateTimeFromLines([normalized]);

    _log('  type   : ${type?.name ?? "(unknown)"}');
    _log('  amounts: ${amounts.isEmpty ? "(none)" : amounts.join(", ")}');
    _log('  titles : ${titles.isEmpty ? "(none)" : titles.join(" | ")}');
    _log('  date   : ${dateTime?.toIso8601String() ?? "(not found)"}');

    return SmsParseResult(
      amountCandidates: amounts,
      titleCandidates: titles,
      dateTime: dateTime,
      type: type,
      rawText: normalized,
    );
  }

  // ── Debit vs credit ────────────────────────────────────────────────────────

  static final _debitRe = RegExp(
    r'\b(debited|debit|spent|paid|withdrawn|purchase|sent|deducted)\b',
    caseSensitive: false,
  );
  static final _creditRe = RegExp(
    r'\b(credited|credit|received|deposited|refund(ed)?|cashback)\b',
    caseSensitive: false,
  );

  TransactionType? _extractType(String text) {
    final isDebit = _debitRe.hasMatch(text);
    final isCredit = _creditRe.hasMatch(text);
    if (isDebit && !isCredit) return TransactionType.expense;
    if (isCredit && !isDebit) return TransactionType.income;
    return null;
  }

  // ── Amount ─────────────────────────────────────────────────────────────────

  static final _amountRe = RegExp(
    r'(?:rs\.?|inr|₹)\s*([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  List<double> _extractAmounts(String text) {
    final seen = <double>{};
    final ordered = <double>[];
    for (final m in _amountRe.allMatches(text)) {
      final value = _toDouble(m.group(1)!);
      if (value == null || value <= 0 || value > 10000000) continue;
      if (seen.add(value)) ordered.add(value);
    }
    // SMS bodies almost always lead with the transaction amount — first
    // currency-prefixed number wins, in appearance order.
    return ordered.take(5).toList();
  }

  // ── Merchant / payee ───────────────────────────────────────────────────────

  // UPI: "...to VPA merchant@bank..." or "...to merchant@bank..."
  static final _vpaRe = RegExp(
    r'(?:to|from)\s+(?:VPA\s+)?([\w.\-]+@[\w.\-]+)',
    caseSensitive: false,
  );

  // Card swipe: "...at MERCHANT NAME on 01-01-24..." / "...at MERCHANT NAME."
  static final _atRe = RegExp(
    r"\bat\s+([A-Za-z0-9&.\-' ]{2,40}?)(?=\s+on\b|\s+via\b|\s+ref\b|[.,]|$)",
    caseSensitive: false,
  );

  // Bank transfer / P2P: "...to RAHUL SHARMA on..." / "...from RAHUL SHARMA."
  static final _toFromRe = RegExp(
    r"\b(?:to|from)\s+([A-Za-z][A-Za-z .\-']{2,40}?)(?=\s+on\b|\s+via\b|\s+ref\b|[.,]|$)",
    caseSensitive: false,
  );

  static final _accountLikeRe =
      RegExp(r'\bvpa\b|a/c|account|bank|card', caseSensitive: false);

  List<String> _extractTitles(String text) {
    final candidates = <String>[];

    final vpaMatch = _vpaRe.firstMatch(text);
    if (vpaMatch != null) {
      candidates.add(_cleanMerchant(vpaMatch.group(1)!.split('@').first));
    }

    final atMatch = _atRe.firstMatch(text);
    if (atMatch != null) candidates.add(_cleanMerchant(atMatch.group(1)!));

    final toFromMatch = _toFromRe.firstMatch(text);
    if (toFromMatch != null) {
      final raw = toFromMatch.group(1)!.trim();
      if (!_accountLikeRe.hasMatch(raw)) candidates.add(_cleanMerchant(raw));
    }

    final seen = <String>{};
    final result = <String>[];
    for (final c in candidates) {
      final key = c.toLowerCase();
      if (c.length >= 2 && seen.add(key)) result.add(c);
      if (result.length >= 3) break;
    }
    return result;
  }

  String _cleanMerchant(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[._\-]+$'), '');
    return cleaned
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double? _toDouble(String raw) => double.tryParse(raw.replaceAll(',', ''));

  void _log(String msg) {
    if (!kDebugMode) return;
    debugPrint('[SmsParser] $msg');
  }
}

final smsParserServiceProvider =
    Provider<SmsParserService>((ref) => SmsParserService());
