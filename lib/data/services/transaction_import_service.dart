import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/custom_category.dart';
import '../models/import_models.dart';
import '../models/transaction_model.dart';

class TransactionImportService {
  static const sampleAssetPath = 'assets/sample/import_sample.csv';

  static const _requiredColumns = ['date', 'type', 'category', 'amount'];

  /// Opens the system file picker restricted to .csv files. Returns null if
  /// the user cancels.
  Future<File?> pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  /// Copies the bundled sample CSV to a temp file and opens the native share
  /// sheet so the user can save a copy to their device (Files/Downloads/etc)
  /// to see the expected format before importing their own data.
  Future<void> shareSampleCsv() async {
    final bytes = await rootBundle.load(sampleAssetPath);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/import_sample.csv');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'SplitPay sample import CSV',
    );
  }

  /// Parses raw CSV text into rows, skipping (and reporting) any row that
  /// fails to parse rather than aborting the whole import.
  ImportPreview parse(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final table = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(normalized)
        .where((row) => row.any((cell) => cell.toString().trim().isNotEmpty))
        .toList();

    if (table.isEmpty) {
      return const ImportPreview(rows: [], errors: ['The file is empty']);
    }

    final header =
        table.first.map((c) => c.toString().trim().toLowerCase()).toList();
    final missing = _requiredColumns.where((c) => !header.contains(c));
    if (missing.isNotEmpty) {
      return ImportPreview(
        rows: const [],
        errors: ['Missing required column(s): ${missing.join(', ')}'],
      );
    }

    final dateIdx = header.indexOf('date');
    final typeIdx = header.indexOf('type');
    final categoryIdx = header.indexOf('category');
    final amountIdx = header.indexOf('amount');
    final noteIdx = header.indexOf('note');

    final rows = <ImportRow>[];
    final errors = <String>[];

    for (var i = 1; i < table.length; i++) {
      final line = i + 1; // 1-based, header is line 1
      final cols = table[i];

      String cell(int idx) =>
          idx >= 0 && idx < cols.length ? cols[idx].toString().trim() : '';

      final date = DateTime.tryParse(cell(dateIdx));
      if (date == null) {
        errors
            .add('Row $line: invalid date "${cell(dateIdx)}" (use YYYY-MM-DD)');
        continue;
      }

      final category = cell(categoryIdx);
      if (category.isEmpty) {
        errors.add('Row $line: category is required');
        continue;
      }

      final rawAmount = cell(amountIdx).replaceAll(RegExp(r'[^0-9.\-]'), '');
      final parsedAmount = double.tryParse(rawAmount);
      if (parsedAmount == null) {
        errors.add('Row $line: invalid amount "${cell(amountIdx)}"');
        continue;
      }

      final typeText = cell(typeIdx).toLowerCase();
      TransactionType type;
      if (typeText.contains('incom') ||
          typeText == 'credit' ||
          typeText == 'cr') {
        type = TransactionType.income;
      } else if (typeText.contains('expens') ||
          typeText == 'debit' ||
          typeText == 'dr') {
        type = TransactionType.expense;
      } else {
        // No usable Type column (e.g. a signed-amount bank export) — fall
        // back to the amount's sign.
        type =
            parsedAmount < 0 ? TransactionType.expense : TransactionType.income;
      }

      final note = cell(noteIdx);

      rows.add(ImportRow(
        date: date,
        type: type,
        categoryLabel: category,
        amount: parsedAmount.abs(),
        lineNumber: line,
        note: note.isEmpty ? null : note,
      ));
    }

    return ImportPreview(rows: rows, errors: errors);
  }

  /// Matches a CSV category label against the built-in [Category] enum
  /// (by label) and the user's existing custom categories (by label),
  /// case-insensitively. Falls through to "new" if neither matches.
  CategoryResolution resolveCategory(
      String label, List<CustomCategory> existingCustom) {
    final normalized = label.trim().toLowerCase();

    for (final cat in Category.values) {
      if (cat.label.toLowerCase() == normalized) {
        return CategoryResolution(label: label, builtIn: cat);
      }
    }
    for (final cat in existingCustom) {
      if (cat.label.toLowerCase() == normalized) {
        return CategoryResolution(label: label, existing: cat);
      }
    }
    return CategoryResolution(label: label);
  }

  /// Deterministic color/icon picks for a brand-new custom category, so the
  /// same label always maps to the same look and different labels tend to
  /// spread across the palette.
  int colorIndexFor(String label) =>
      label.trim().toLowerCase().hashCode.abs() % CustomCategory.colors.length;

  int iconIndexFor(String label) =>
      (label.trim().toLowerCase().hashCode ~/ 7).abs() %
      CustomCategory.icons.length;
}

final transactionImportService = TransactionImportService();
