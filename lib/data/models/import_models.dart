import 'custom_category.dart';
import 'transaction_model.dart';

/// One row parsed out of a CSV file, before category resolution.
class ImportRow {
  final DateTime date;
  final TransactionType type;
  final String categoryLabel;
  final double amount;
  final String? note;

  /// 1-based line number in the source file (header is line 1) — used to
  /// point the user at the right row when reporting parse errors.
  final int lineNumber;

  const ImportRow({
    required this.date,
    required this.type,
    required this.categoryLabel,
    required this.amount,
    required this.lineNumber,
    this.note,
  });
}

/// Result of parsing a CSV file: the rows that parsed cleanly, plus a
/// human-readable error per row that didn't (row is skipped, not fatal).
class ImportPreview {
  final List<ImportRow> rows;
  final List<String> errors;

  const ImportPreview({required this.rows, required this.errors});

  bool get isEmpty => rows.isEmpty;
}

/// How a CSV row's category label maps onto the app's category system.
class CategoryResolution {
  final Category? builtIn;
  final CustomCategory? existing;
  final String label;

  const CategoryResolution({required this.label, this.builtIn, this.existing});

  bool get isNew => builtIn == null && existing == null;

  String get categoryKey => builtIn?.name ?? Category.other.name;
}
