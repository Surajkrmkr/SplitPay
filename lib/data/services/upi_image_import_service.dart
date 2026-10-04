import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/services/app_logger.dart';
import '../../core/utils/fuzzy_date_parser.dart';
import '../models/transaction_model.dart';

class UpiTransactionDraft {
  final double? amount;
  final String? merchant;
  final DateTime? dateTime;
  final String? reference;

  const UpiTransactionDraft({
    this.amount,
    this.merchant,
    this.dateTime,
    this.reference,
  });
}

class SharedImageBatch {
  final List<String> paths;
  final int omittedCount;

  const SharedImageBatch({
    required this.paths,
    this.omittedCount = 0,
  });
}

class UpiImageImportService {
  static const maxImages = 5;
  static const maxImageBytes = 25 * 1024 * 1024;

  static const _platform = _SharedImagePlatform();

  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<SharedImageBatch> takePendingImages() => _platform.takePendingImages();

  Stream<SharedImageBatch> get sharedImages => _platform.sharedImages;

  Future<void> deleteImages(List<String> paths) async {
    try {
      await _platform.deleteImages(paths);
      AppLogger.instance.d(
        'Temporary shared image cleanup completed (${paths.length} file(s)).',
        tag: 'UPI Import',
      );
    } catch (error) {
      AppLogger.instance.e(
        'Temporary shared image cleanup failed (${error.runtimeType}).',
        tag: 'UPI Import',
      );
      rethrow;
    }
  }

  Future<UpiTransactionDraft> readTransaction(String imagePath) async {
    String? preparedImagePath;
    try {
      AppLogger.instance.i(
        'Preparing and validating shared image for on-device OCR.',
        tag: 'UPI Import',
      );
      preparedImagePath = await _platform.prepareImageForOcr(imagePath);
      AppLogger.instance.i(
        'Shared image validated and normalized for OCR.',
        tag: 'UPI Import',
      );
      AppLogger.instance.i('On-device OCR started.', tag: 'UPI Import');
      final input = InputImage.fromFilePath(preparedImagePath);
      final recognized = await _recognizer.processImage(input);
      AppLogger.instance.i(
        'On-device OCR completed (${recognized.blocks.length} text block(s)).',
        tag: 'UPI Import',
      );
      final draft = parseOcrText(recognized.text);
      AppLogger.instance.i(
        'Transaction parsing completed: '
        'amount=${draft.amount != null}, '
        'merchant=${draft.merchant != null}, '
        'date=${draft.dateTime != null}, '
        'reference=${draft.reference != null}.',
        tag: 'UPI Import',
      );
      return draft;
    } catch (error) {
      final failure = error is PlatformException
          ? 'platform code ${error.code}'
          : error.runtimeType.toString();
      AppLogger.instance.e(
        'Image validation, on-device OCR, or transaction parsing failed '
        '($failure).',
        tag: 'UPI Import',
      );
      rethrow;
    } finally {
      if (preparedImagePath != null) {
        try {
          await deleteImages([preparedImagePath]);
        } catch (_) {
          // deleteImages logs the failure; preserve the OCR result/error.
        }
      }
    }
  }

  Future<void> dispose() async {
    try {
      await _recognizer.close();
      AppLogger.instance
          .d('On-device OCR recognizer closed.', tag: 'UPI Import');
    } catch (error) {
      AppLogger.instance.e(
        'On-device OCR recognizer close failed (${error.runtimeType}).',
        tag: 'UPI Import',
      );
    }
  }

  static UpiTransactionDraft parseOcrText(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final amount = _extractAmount(lines);
    final merchant = _extractMerchant(lines);
    final dateTime =
        extractDateTimeFromLines(lines) ?? _extractDateWithoutYear(lines);
    final reference = _extractReference(lines);
    return UpiTransactionDraft(
      amount: amount,
      merchant: merchant,
      dateTime: dateTime,
      reference: reference,
    );
  }

  static double? _extractAmount(List<String> lines) {
    const number = r'((?:\d{1,3}(?:[,\s]\d{2,3})+|\d+)(?:\.\d{1,2})?)';
    final currencyAmount = RegExp(
      '(?:₹|INR|Rs\\.?)\\s*$number|$number\\s*(?:INR|Rs\\.?)',
      caseSensitive: false,
    );
    for (final line in lines) {
      for (final match in currencyAmount.allMatches(line)) {
        final amountText = match.group(1) ?? match.group(2);
        final amount = _parseAmount(amountText);
        if (amount != null) return amount;
      }
    }

    final labeledAmount = RegExp(
      '\\b(?:amount|total|paid|payment|debited|sent|transferred)\\b'
      '[^\\d]{0,8}$number',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (_isReferenceLine(line) || _looksLikeDateOrTime(line)) continue;
      final match = labeledAmount.firstMatch(line);
      if (match == null) continue;
      final amount = _parseAmount(match.group(1));
      if (amount != null) return amount;
    }

    // Some UPI apps show the amount alone after stripping currency glyphs
    // during OCR. Only accept it when the receipt has one unambiguous amount.
    final standaloneAmounts = <double>{};
    for (final line in lines) {
      if (_isReferenceLine(line) ||
          _looksLikeDateOrTime(line) ||
          RegExp(r'[A-Za-z]').hasMatch(line)) {
        continue;
      }
      final match =
          RegExp('^\\s*$number\\s*\$', caseSensitive: false).firstMatch(line);
      final amount = _parseAmount(match?.group(1));
      if (amount != null) standaloneAmounts.add(amount);
    }
    if (standaloneAmounts.length == 1) return standaloneAmounts.single;
    return null;
  }

  static double? _parseAmount(String? value) {
    if (value == null) return null;
    final amount = double.tryParse(value.replaceAll(RegExp(r'[,\s]'), ''));
    if (amount == null || amount <= 0 || amount > 10000000) return null;
    return amount;
  }

  static bool _looksLikeDateOrTime(String line) => RegExp(
        r'\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b'
        r'|\b\d{1,4}[-/]\d{1,2}[-/]\d{1,4}\b'
        r'|\b\d{1,2}:\d{2}(?::\d{2})?\b',
        caseSensitive: false,
      ).hasMatch(line);

  static String? _extractMerchant(List<String> lines) {
    final labeledMerchant = RegExp(
      r'\b(?:paid\s+to|sent\s+to|payment\s+to|merchant|at)\s*[:\-]?\s*(.+)$',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = labeledMerchant.firstMatch(line);
      if (match == null) continue;
      final merchant = _cleanMerchant(match.group(1)!);
      if (merchant != null) return merchant;
    }

    const ignored = [
      'success',
      'successful',
      'completed',
      'transaction',
      'payment',
      'upi',
      'reference',
      'ref no',
      'utr',
      'date',
      'time',
      'amount',
      'debited',
      'credited',
      'paid',
      'sent',
      'received',
      'thank you',
      'view details',
    ];
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_isReferenceLine(line) ||
          ignored.any(lower.contains) ||
          RegExp(r'^(?:₹|inr|rs\.?)\s*[\d,.]+$', caseSensitive: false)
              .hasMatch(line) ||
          RegExp(r'^\d').hasMatch(line) ||
          line.length < 2 ||
          line.length > 50) {
        continue;
      }
      return _cleanMerchant(line);
    }
    return null;
  }

  static String? _cleanMerchant(String value) {
    final merchant = value
        .replaceAll(
            RegExp(r'\s+(?:on|at)\s+\d{1,2}[:/].*$', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'\s+(?:UPI|IMPS|NEFT)\b.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[\s:,\-]+|[\s,;]+$'), '')
        .trim();
    if (merchant.isEmpty ||
        merchant.length > 50 ||
        RegExp(r'^\d').hasMatch(merchant)) {
      return null;
    }
    return merchant;
  }

  static String? _extractReference(List<String> lines) {
    final labeled = RegExp(
      r'\b(?:UPI\s*(?:ref(?:erence)?|txn|transaction)|'
      r'(?:txn|transaction)\s*(?:id|ref(?:erence)?|no\.?)|UTR)\b'
      r'\s*[:#\-]?\s*([A-Z0-9][A-Z0-9\-]{5,29})',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = labeled.firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static bool _isReferenceLine(String line) => RegExp(
          r'\b(?:UTR|UPI\s*(?:ref|txn|transaction)|transaction\s*(?:id|ref))\b',
          caseSensitive: false)
      .hasMatch(line);

  static DateTime? _extractDateWithoutYear(List<String> lines) {
    const monthNames = r'Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec';
    final datePattern = RegExp(
      r'\b(\d{1,2})[\s,/-]+(' + monthNames + r')\.?(?:[\s,/-]+\d{2,4})?\b',
      caseSensitive: false,
    );
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    for (final line in lines) {
      final match = datePattern.firstMatch(line);
      if (match == null) continue;
      final day = int.tryParse(match.group(1)!);
      final month = months[match.group(2)!.toLowerCase()];
      if (day == null || month == null) continue;
      final date = DateTime(DateTime.now().year, month, day);
      if (date.month != month || date.day != day) continue;
      final time = extractTimeFromLines(lines);
      return time == null
          ? date
          : DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
    return null;
  }
}

class _SharedImagePlatform {
  const _SharedImagePlatform();

  static const _method = MethodChannel(
    'com.splitpay.expensetracker/shared_images',
  );
  static const _events = EventChannel(
    'com.splitpay.expensetracker/shared_images/events',
  );

  Future<SharedImageBatch> takePendingImages() async {
    try {
      final payload =
          await _method.invokeMapMethod<String, dynamic>('takePendingImages');
      final batch = _batchFromPayload(payload);
      AppLogger.instance.d(
        'Retrieved ${batch.paths.length} pending shared image(s).',
        tag: 'UPI Import',
      );
      return batch;
    } catch (error) {
      AppLogger.instance.e(
        'Could not retrieve pending shared images (${error.runtimeType}).',
        tag: 'UPI Import',
      );
      rethrow;
    }
  }

  Future<String> prepareImageForOcr(String path) async {
    try {
      final preparedPath = await _method.invokeMethod<String>(
        'prepareImageForOcr',
        {'path': path},
      );
      if (preparedPath == null || preparedPath.isEmpty) {
        throw PlatformException(
          code: 'image_prepare_failed',
          message: 'The shared image could not be decoded.',
        );
      }
      return preparedPath;
    } catch (error) {
      final failure = error is PlatformException
          ? 'platform code ${error.code}'
          : error.runtimeType.toString();
      AppLogger.instance.e(
        'Native shared image validation failed ($failure).',
        tag: 'UPI Import',
      );
      rethrow;
    }
  }

  Stream<SharedImageBatch> get sharedImages =>
      _events.receiveBroadcastStream().map((event) {
        final batch = _batchFromPayload(
          (event as Map<dynamic, dynamic>).cast<String, dynamic>(),
        );
        AppLogger.instance.i(
          'Received ${batch.paths.length} shared image(s); '
          '${batch.omittedCount} could not be copied.',
          tag: 'UPI Import',
        );
        return batch;
      }).handleError((Object error) {
        AppLogger.instance.e(
          'Native shared image delivery failed (${error.runtimeType}).',
          tag: 'UPI Import',
        );
      });

  SharedImageBatch _batchFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return const SharedImageBatch(paths: []);
    final paths = (payload['paths'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final omittedCount = (payload['omittedCount'] as num?)?.toInt() ?? 0;
    return SharedImageBatch(paths: paths, omittedCount: omittedCount);
  }

  Future<void> deleteImages(List<String> paths) async {
    try {
      await _method.invokeMethod<void>('deleteImages', {'paths': paths});
    } catch (error) {
      AppLogger.instance.e(
        'Native temporary image deletion failed (${error.runtimeType}).',
        tag: 'UPI Import',
      );
      rethrow;
    }
  }
}

Category categoryForMerchant(String merchant) {
  final name = merchant.toLowerCase();
  if (RegExp(r'swiggy|zomato|restaurant|cafe|food|eat|dine').hasMatch(name)) {
    return Category.food;
  }
  if (RegExp(r'uber|ola|rapido|irctc|metro|flight|airline').hasMatch(name)) {
    return Category.travel;
  }
  if (RegExp(r'amazon|flipkart|myntra|retail|store').hasMatch(name)) {
    return Category.shopping;
  }
  if (RegExp(r'netflix|spotify|prime|hotstar').hasMatch(name)) {
    return Category.subscription;
  }
  return Category.other;
}
