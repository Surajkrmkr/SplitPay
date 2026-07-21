import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/custom_category.dart';
import '../../data/models/import_models.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/transaction_api_service.dart' show ImportResult;
import '../../data/services/transaction_import_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/sp_button.dart';

enum _Step { intro, preview, done }

class ImportDataScreen extends ConsumerStatefulWidget {
  const ImportDataScreen({super.key});

  @override
  ConsumerState<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends ConsumerState<ImportDataScreen> {
  _Step _step = _Step.intro;
  bool _busy = false;
  String? _fileName;
  ImportPreview? _preview;
  List<CategoryResolution>? _resolutions;
  List<String>? _newLabels;
  String? _fatalError;
  ImportResult? _result;
  int _categoriesCreated = 0;

  Future<void> _downloadSample() async {
    try {
      await transactionImportService.shareSampleCsv();
    } catch (_) {
      _showSnack('Could not share the sample CSV');
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _fatalError = null;
    });
    try {
      final file = await transactionImportService.pickCsvFile();
      if (file == null) return; // user cancelled
      final content = await file.readAsString();
      final preview = transactionImportService.parse(content);

      if (preview.isEmpty) {
        setState(() {
          _fatalError = preview.errors.isNotEmpty
              ? preview.errors.first
              : 'No valid rows found in this file';
        });
        return;
      }

      final existingCustom = ref.read(customCategoriesProvider);
      final resolutions = preview.rows
          .map((r) => transactionImportService.resolveCategory(
              r.categoryLabel, existingCustom))
          .toList();

      // Dedupe new-category labels case-insensitively, keeping first casing seen.
      final seen = <String>{};
      final newLabels = <String>[];
      for (final res in resolutions.where((r) => r.isNew)) {
        final key = res.label.trim().toLowerCase();
        if (seen.add(key)) newLabels.add(res.label.trim());
      }

      setState(() {
        _fileName = file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'import.csv';
        _preview = preview;
        _resolutions = resolutions;
        _newLabels = newLabels;
        _step = _Step.preview;
      });
    } on FileSystemException {
      setState(() => _fatalError = 'Could not read the selected file');
    } catch (_) {
      setState(() => _fatalError = 'Could not read that file as CSV');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace existing data?'),
        content: const Text(
          'Importing will permanently replace all of your existing personal '
          'expense data with the rows from this file. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Replace Data',
                style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runImport();
  }

  Future<void> _runImport() async {
    setState(() {
      _busy = true;
      _fatalError = null;
    });
    try {
      final createdIds = <String, String>{}; // lowercased label -> new id

      for (final label in _newLabels!) {
        final created = await ref
            .read(customCategoriesProvider.notifier)
            .createAndAdd(CustomCategory(
              id: '', // server assigns the real id
              label: label,
              colorIndex: transactionImportService.colorIndexFor(label),
              iconIndex: transactionImportService.iconIndexFor(label),
            ));
        createdIds[label.trim().toLowerCase()] = created.id;
      }

      final transactions = <Transaction>[];
      for (var i = 0; i < _preview!.rows.length; i++) {
        final row = _preview!.rows[i];
        final res = _resolutions![i];
        final now = DateTime.now();

        String? customCategoryId;
        if (res.existing != null) {
          customCategoryId = res.existing!.id;
        } else if (res.isNew) {
          customCategoryId = createdIds[res.label.trim().toLowerCase()];
        }

        transactions.add(Transaction(
          id: const Uuid().v4(),
          amount: row.amount,
          type: row.type,
          category: res.builtIn ?? Category.other,
          customCategoryId: customCategoryId,
          note: row.note,
          date: row.date,
          createdAt: now,
        ));
      }

      final result =
          await ref.read(transactionProvider.notifier).importAll(transactions);

      if (!mounted) return;
      setState(() {
        _result = result;
        _categoriesCreated = createdIds.length;
        _step = _Step.done;
      });
      // Existing custom-category list may now be stale relative to the
      // server's (some labels may have matched an entry created by another
      // device) — cheapest way to reconcile is a full reload.
      ref.invalidate(customCategoriesProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _fatalError =
          'Import failed. Your existing data has not been changed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _step = _Step.intro;
      _fileName = null;
      _preview = null;
      _resolutions = null;
      _newLabels = null;
      _fatalError = null;
      _result = null;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  AppBackButton(
                    onTap: _step == _Step.preview && !_busy ? _reset : null,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Import Data',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: switch (_step) {
                _Step.intro => _IntroView(
                    busy: _busy,
                    error: _fatalError,
                    onDownloadSample: _downloadSample,
                    onPickFile: _pickFile,
                  ),
                _Step.preview => _PreviewView(
                    fileName: _fileName!,
                    preview: _preview!,
                    newLabels: _newLabels!,
                    busy: _busy,
                    error: _fatalError,
                    onConfirm: _confirmAndImport,
                  ),
                _Step.done => _DoneView(
                    result: _result!,
                    categoriesCreated: _categoriesCreated,
                    onFinish: () => Navigator.of(context).pop(),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Intro step ───────────────────────────────────────────────────────────────

class _IntroView extends StatelessWidget {
  final bool busy;
  final String? error;
  final VoidCallback onDownloadSample;
  final VoidCallback onPickFile;

  const _IntroView({
    required this.busy,
    required this.error,
    required this.onDownloadSample,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: isDark ? 0.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.upload_file_rounded,
                    color: AppColors.secondary, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                'Import expenses from a CSV file',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Columns required: Date, Type, Category, Amount. Note is '
                'optional. Categories that don\'t already exist in the app '
                'will be created automatically.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.expense, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Importing replaces ALL of your existing personal '
                        'expense data — this cannot be undone.',
                        style: TextStyle(
                          color: AppColors.expense,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.05),
        const SizedBox(height: 20),
        SpButton(
          label: 'Download Sample CSV',
          icon: Icons.description_outlined,
          onTap: busy ? null : onDownloadSample,
        ),
        const SizedBox(height: 12),
        _OutlinedActionButton(
          label: 'Select CSV File',
          icon: Icons.folder_open_rounded,
          isLoading: busy,
          onTap: busy ? null : onPickFile,
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: error!),
        ],
      ],
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onTap;

  const _OutlinedActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: AppColors.expense, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Preview step ─────────────────────────────────────────────────────────────

class _PreviewView extends ConsumerWidget {
  final String fileName;
  final ImportPreview preview;
  final List<String> newLabels;
  final bool busy;
  final String? error;
  final VoidCallback onConfirm;

  const _PreviewView({
    required this.fileName,
    required this.preview,
    required this.newLabels,
    required this.busy,
    required this.error,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final rows = preview.rows;
    final incomeCount =
        rows.where((r) => r.type == TransactionType.income).length;
    final expenseCount = rows.length - incomeCount;
    final totalIncome = rows
        .where((r) => r.type == TransactionType.income)
        .fold(0.0, (sum, r) => sum + r.amount);
    final totalExpense = rows
        .where((r) => r.type == TransactionType.expense)
        .fold(0.0, (sum, r) => sum + r.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(
          children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fileName,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryGrid(
          rowCount: rows.length,
          incomeCount: incomeCount,
          expenseCount: expenseCount,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          currency: currency,
        ).animate().fadeIn().slideY(begin: 0.05),
        if (newLabels.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'NEW CATEGORIES TO CREATE (${newLabels.length})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: newLabels
                .map((label) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
        if (preview.errors.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'SKIPPED ROWS (${preview.errors.length})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: preview.errors
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(e,
                            style: TextStyle(
                                color: AppColors.warning, fontSize: 12.5)),
                      ))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.expense.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.expense, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This will replace all your existing personal expense data '
                  'with the ${rows.length} row${rows.length == 1 ? '' : 's'} above.',
                  style: TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: error!),
        ],
        const SizedBox(height: 20),
        SpButton(
          label: 'Replace My Data',
          icon: Icons.swap_horiz_rounded,
          isLoading: busy,
          onTap: busy ? null : onConfirm,
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final int rowCount;
  final int incomeCount;
  final int expenseCount;
  final double totalIncome;
  final double totalExpense;
  final String currency;

  const _SummaryGrid({
    required this.rowCount,
    required this.incomeCount,
    required this.expenseCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Rows Found',
            value: '$rowCount',
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Income ($incomeCount)',
            value: CurrencyFormatter.format(totalIncome, symbol: currency),
            color: AppColors.income,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Expense ($expenseCount)',
            value: CurrencyFormatter.format(totalExpense, symbol: currency),
            color: AppColors.expense,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Done step ────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  final ImportResult result;
  final int categoriesCreated;
  final VoidCallback onFinish;

  const _DoneView({
    required this.result,
    required this.categoriesCreated,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: AppColors.income, size: 36),
          ).animate().scale(curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            'Import complete',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Imported ${result.imported} transaction${result.imported == 1 ? '' : 's'}'
            '${categoriesCreated > 0 ? ' · created $categoriesCreated new categor${categoriesCreated == 1 ? 'y' : 'ies'}' : ''}'
            '${result.replaced > 0 ? ' · replaced ${result.replaced} previous entr${result.replaced == 1 ? 'y' : 'ies'}' : ''}.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
          ),
          const Spacer(),
          SpButton(label: 'Done', onTap: onFinish),
        ],
      ),
    );
  }
}
