import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/utils/fuzzy_date_parser.dart';

/// What we managed to extract from a scanned bill.
///
/// Amount and title now ship as ranked candidate lists (best guess first) so
/// the UI can show alternatives as pills. The convenience getters [amount]
/// and [title] return the top pick (or null when nothing was detected).
class BillScanResult {
  final List<double> amountCandidates;
  final List<String> titleCandidates;
  final DateTime? dateTime;
  final String rawText;

  const BillScanResult({
    this.amountCandidates = const [],
    this.titleCandidates = const [],
    this.dateTime,
    required this.rawText,
  });

  double? get amount =>
      amountCandidates.isNotEmpty ? amountCandidates.first : null;
  String? get title =>
      titleCandidates.isNotEmpty ? titleCandidates.first : null;

  bool get isEmpty => amount == null && title == null && dateTime == null;
  bool get hasAny => !isEmpty;
}

class _Candidate<T> {
  final T value;
  final int score;
  final String source;
  const _Candidate(this.value, this.score, this.source);
}

class BillScannerService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Runs OCR on [imagePath] and best-effort parses common bill fields.
  Future<BillScanResult> scan(String imagePath) async {
    _log('▶ scan() path=$imagePath');
    final sw = Stopwatch()..start();
    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(input);
    _log('OCR finished in ${sw.elapsedMilliseconds}ms, '
        '${recognized.blocks.length} block(s), '
        '${recognized.text.length} chars');
    return _parse(recognized);
  }

  void dispose() => _recognizer.close();

  // ── Parsing ────────────────────────────────────────────────────────────────

  BillScanResult _parse(RecognizedText recognized) {
    final fullText = recognized.text;

    // Build a structured line view (text + box info from MLKit blocks). The
    // box height is a decent proxy for relative font size — useful for
    // ranking title candidates.
    final lines = <_Line>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        lines.add(_Line(
          text: text,
          height: line.boundingBox.height,
          y: line.boundingBox.top,
        ));
      }
    }
    // Keep visual top-to-bottom order so position-based scoring is stable.
    lines.sort((a, b) => a.y.compareTo(b.y));

    _log('━━━━━ RAW TEXT ━━━━━');
    for (final l in fullText.split('\n')) {
      _log('  | $l');
    }
    _log('━━━━━ LINES (${lines.length}) ━━━━━');
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      _log('  [$i] h=${l.height.toStringAsFixed(0)} "${l.text}"');
    }

    final amounts = _extractAmounts(lines);
    final titles = _extractTitles(lines);
    final dateTime =
        extractDateTimeFromLines(lines.map((l) => l.text).toList());

    _log('━━━━━ PARSED ━━━━━');
    _log('  amounts  : ${amounts.isEmpty ? "(none)" : amounts.join(", ")}');
    _log('  titles   : ${titles.isEmpty ? "(none)" : titles.join(" | ")}');
    _log('  dateTime : ${dateTime?.toIso8601String() ?? "(not found)"}');
    _log('━━━━━━━━━━━━━━━━━━');

    return BillScanResult(
      amountCandidates: amounts,
      titleCandidates: titles,
      dateTime: dateTime,
      rawText: fullText,
    );
  }

  // ── Amount ─────────────────────────────────────────────────────────────────

  // Lines that mention any of these are typically *not* about money.
  static const _nonMoneyLineKeywords = [
    'phone',
    'tel.',
    'tel:',
    'tel ',
    'telephone',
    'mob',
    'mobile',
    'fax',
    'cell',
    'contact',
    'customer care',
    'helpline',
    'whatsapp',
    'gstin',
    'gst no',
    'gst:',
    'pan',
    'cin',
    'fssai',
    'invoice no',
    'bill no',
    'order no',
    'order id',
    'table no',
    'kot',
    'pin code',
    'pincode',
    'zip',
  ];

  // Lines that strongly suggest the number on them is the bill total.
  // First list wins ties — earlier = stronger signal.
  static const _amountKeywordsRanked = [
    ['grand total'],
    [
      'amount due',
      'total amount',
      'net amount',
      'net payable',
      'bill amount',
      'amount payable',
      'final total',
      'final amount'
    ],
    ['total'],
    ['amount', 'subtotal', 'sub total', 'net', 'payable', 'due'],
  ];

  static final _amountRe = RegExp(
    // Optional currency prefix, then digits with optional thousands sep,
    // optional 1-2 decimals. We capture the number itself in group 1.
    r'(?:rs\.?|inr|₹|\$)?\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  // Long digit runs that almost certainly aren't prices.
  static final _phoneLikeRe = RegExp(r'(?:\+?91[\s-]?)?[6-9]\d{9}');
  static final _longDigitRunRe = RegExp(r'\d{10,}');

  List<double> _extractAmounts(List<_Line> lines) {
    final candidates = <_Candidate<double>>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].text;
      final lower = line.toLowerCase();

      // Hard exclude: phone, GSTIN, PAN, invoice-number lines.
      if (_nonMoneyLineKeywords.any(lower.contains)) {
        _log('amount  · skip line $i (non-money keyword): "$line"');
        continue;
      }

      // Strip phone-number tokens from the line so they can't pollute the
      // number scan (e.g. a phone next to an amount on the same line).
      final cleaned =
          line.replaceAll(_phoneLikeRe, ' ').replaceAll(_longDigitRunRe, ' ');

      for (final m in _amountRe.allMatches(cleaned)) {
        final raw = m.group(1)!;
        final value = _toDouble(raw);
        if (value == null) continue;

        // Sanity bands. Bills aren't ₹0 and aren't ₹10M either.
        if (value < 1 || value > 1000000) continue;

        // Year-like integers (no decimal) are almost never the total.
        if (value >= 1900 && value <= 2100 && !raw.contains('.')) {
          _log('amount  · skip "$raw" (year-like) on "$line"');
          continue;
        }

        var score = 0;

        // Keyword ranks — strongest signal.
        var keywordRank = -1;
        for (var rank = 0; rank < _amountKeywordsRanked.length; rank++) {
          if (_amountKeywordsRanked[rank].any(lower.contains)) {
            keywordRank = rank;
            break;
          }
        }
        if (keywordRank == 0) {
          score += 100;
        } else if (keywordRank == 1) {
          score += 80;
        } else if (keywordRank == 2) {
          score += 60;
        } else if (keywordRank == 3) {
          score += 40;
        }

        // Visual cues.
        if (RegExp(r'(₹|\$|rs\.?|inr)', caseSensitive: false).hasMatch(line)) {
          score += 8;
        }
        if (raw.contains('.')) score += 12; // monetary decimals
        // Numbers at end-of-line are usually totals; line items often have
        // qty, rate, amount columns where the amount is right-most too.
        if (cleaned.trim().endsWith(raw) ||
            cleaned.trim().endsWith('$raw.00')) {
          score += 4;
        }

        // Position bias — totals live toward the bottom half of bills.
        final positionRatio = i / lines.length;
        if (positionRatio > 0.5) score += 8;
        if (positionRatio > 0.75) score += 4;

        // Magnitude bias — totals usually >= 10. Sub-rupee values are
        // almost always tax % or per-unit cents.
        if (value >= 10) score += 4;

        candidates.add(_Candidate(value, score, line));
        _log('amount  · candidate $value score=$score from "$line"');
      }
    }

    if (candidates.isEmpty) {
      _log('amount  → none found');
      return const [];
    }

    // Deduplicate by value, keeping the highest score for each unique value.
    final bestByValue = <double, _Candidate<double>>{};
    for (final c in candidates) {
      final existing = bestByValue[c.value];
      if (existing == null || c.score > existing.score) {
        bestByValue[c.value] = c;
      }
    }

    final sorted = bestByValue.values.toList()
      ..sort((a, b) {
        // Higher score first; on ties, larger value (totals > line items).
        if (a.score != b.score) return b.score.compareTo(a.score);
        return b.value.compareTo(a.value);
      });

    final top = sorted.take(5).map((c) => c.value).toList();
    _log('amount  → top picks: ${top.join(", ")}');
    return top;
  }

  // ── Title ──────────────────────────────────────────────────────────────────

  static final _titleJunkRe = RegExp(
    r'(invoice|receipt|bill|tax|gstin|order|table|cashier|gst|kot|'
    r'fssai|cin|pan|date|time|served|welcome|thank|powered)',
    caseSensitive: false,
  );
  static final _addressKeywordRe = RegExp(
    r'\b(road|street|nagar|colony|sector|floor|opp|near|lane|cross|'
    r'avenue|block|plot|tower|building|complex|mall|estate|landmark|main)\b',
    caseSensitive: false,
  );

  List<String> _extractTitles(List<_Line> lines) {
    if (lines.isEmpty) return const [];

    // "Tall" lines (likely larger font) get a prominence boost. Use the
    // median height of the first 10 lines as a baseline.
    final topSlice = lines.take(10).toList();
    final heights = topSlice.map((l) => l.height).toList()..sort();
    final medianHeight = heights.isEmpty ? 0.0 : heights[heights.length ~/ 2];

    final candidates = <_Candidate<String>>[];

    for (var i = 0; i < lines.length && i < 8; i++) {
      final line = lines[i].text;
      final length = line.length;
      if (length < 2 || length > 40) continue;

      final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
      final ratio = letters / length;
      if (ratio < 0.55) {
        _log(
            'title   · skip "$line" (alpha ratio ${ratio.toStringAsFixed(2)})');
        continue;
      }

      if (_titleJunkRe.hasMatch(line)) {
        _log('title   · skip "$line" (header/junk pattern)');
        continue;
      }
      if (_phoneLikeRe.hasMatch(line) || _longDigitRunRe.hasMatch(line)) {
        _log('title   · skip "$line" (phone-like)');
        continue;
      }
      if (RegExp(r',\s*\d').hasMatch(line)) {
        _log('title   · skip "$line" (address: comma + digit)');
        continue;
      }
      if (_addressKeywordRe.hasMatch(line)) {
        _log('title   · skip "$line" (address keyword)');
        continue;
      }

      var score = 0;

      // Position — names live at the very top of the bill.
      if (i == 0) {
        score += 100;
      } else if (i == 1) {
        score += 80;
      } else if (i <= 3) {
        score += 50;
      } else {
        score += 20;
      }

      // Prominence via box height.
      if (medianHeight > 0 && lines[i].height >= medianHeight * 1.2) {
        score += 25;
      }

      // High letter ratio is good.
      if (ratio >= 0.85) score += 15;

      // All-caps brand names are extremely common.
      final upperLetters = line.replaceAll(RegExp(r'[^A-Z]'), '').length;
      if (letters > 0 && upperLetters / letters >= 0.7) score += 10;

      // Shorter title-cased lines feel right (2-25 chars sweet spot).
      if (length >= 2 && length <= 25) score += 5;

      candidates.add(_Candidate(_toTitleCase(line), score, line));
      _log('title   · candidate "${_toTitleCase(line)}" score=$score');
    }

    if (candidates.isEmpty) {
      _log('title   → none found');
      return const [];
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    // Deduplicate by lowercased value while preserving order.
    final seen = <String>{};
    final top = <String>[];
    for (final c in candidates) {
      final key = c.value.toLowerCase();
      if (seen.add(key)) {
        top.add(c.value);
        if (top.length >= 4) break;
      }
    }
    _log('title   → top picks: ${top.join(" | ")}');
    return top;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Debug-only log helper. `debugPrint` is a no-op in release builds.
  void _log(String msg) {
    if (!kDebugMode) return;
    debugPrint('[BillScanner] $msg');
  }

  double? _toDouble(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[,\s]'), '');
    return double.tryParse(cleaned);
  }

  String _toTitleCase(String s) {
    return s
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _Line {
  final String text;
  final double height;
  final double y;
  const _Line({required this.text, required this.height, required this.y});
}

final billScannerServiceProvider = Provider<BillScannerService>((ref) {
  final svc = BillScannerService();
  ref.onDispose(svc.dispose);
  return svc;
});
