import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_exception.dart';
import '../../data/services/bill_scanner_service.dart';

/// Outcome returned from the scan flow. Callers apply whichever fields are
/// non-null and leave the rest of their form untouched.
class BillScanApplied {
  final double? amount;
  final String? title;
  final DateTime? dateTime;

  const BillScanApplied({this.amount, this.title, this.dateTime});

  bool get isEmpty => amount == null && title == null && dateTime == null;
}

/// Compact button that runs the full bill-scan flow: source pick → OCR →
/// confirm dialog → reports the user-approved subset back via [onApply].
class BillScanButton extends ConsumerStatefulWidget {
  /// Whether the sheet shows a "Title" field — controls whether the confirm
  /// dialog offers the merchant name as an applicable field. (The
  /// add-transaction sheet has no title, only a note.)
  final bool supportsTitle;
  final ValueChanged<BillScanApplied> onApply;

  const BillScanButton({
    super.key,
    required this.onApply,
    this.supportsTitle = true,
  });

  @override
  ConsumerState<BillScanButton> createState() => _BillScanButtonState();
}

class _BillScanButtonState extends ConsumerState<BillScanButton> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _startFlow() async {
    if (_busy) return;
    final source = await _pickSource();
    if (source == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      // Run OCR. Keep the busy state on so the button shows the spinner.
      final result = await ref.read(billScannerServiceProvider).scan(file.path);
      if (!mounted) return;
      setState(() => _busy = false);

      if (!result.hasAny) {
        _toast('Couldn\'t detect any fields. Try a clearer photo.',
            isError: true);
        return;
      }

      final applied = await _showConfirmDialog(result);
      if (applied != null && applied.hasAny) {
        widget.onApply.call(applied._toBillScanApplied());
        _toast(applied.summary, isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(friendlyErrorMessage(e), isError: true);
      }
    }
  }

  Future<ImageSource?> _pickSource() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Scan a bill',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'We\'ll try to read the amount, merchant, and date. Anything we can\'t find stays as-is.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SourceTile(
                icon: Icons.photo_camera_rounded,
                label: 'Take a photo',
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Pick from gallery',
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<_ConfirmedResult?> _showConfirmDialog(BillScanResult result) async {
    // The "selected" candidate starts as the parser's top pick. Pills below
    // each row let the user swap to a lower-ranked alternative without leaving
    // the dialog.
    double? selectedAmount = result.amount;
    String? selectedTitle = widget.supportsTitle ? result.title : null;

    bool useAmount = selectedAmount != null;
    bool useTitle = widget.supportsTitle && selectedTitle != null;
    bool useDate = result.dateTime != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<_ConfirmedResult>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Detected from your bill',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tap a pill to swap; untick anything you want to leave unchanged.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetectedRow(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Amount',
                    value: selectedAmount?.toStringAsFixed(2),
                    checked: useAmount,
                    onChanged: selectedAmount == null
                        ? null
                        : (v) => setLocal(() => useAmount = v),
                    pills: result.amountCandidates
                        .map((v) => v.toStringAsFixed(2))
                        .toList(),
                    selectedPill: selectedAmount?.toStringAsFixed(2),
                    onPickPill: (label) {
                      final picked = double.tryParse(label);
                      if (picked == null) return;
                      setLocal(() {
                        selectedAmount = picked;
                        useAmount = true;
                      });
                    },
                  ),
                  if (widget.supportsTitle)
                    _DetectedRow(
                      icon: Icons.storefront_rounded,
                      label: 'Title',
                      value: selectedTitle,
                      checked: useTitle,
                      onChanged: selectedTitle == null
                          ? null
                          : (v) => setLocal(() => useTitle = v),
                      pills: result.titleCandidates,
                      selectedPill: selectedTitle,
                      onPickPill: (label) => setLocal(() {
                        selectedTitle = label;
                        useTitle = true;
                      }),
                    ),
                  _DetectedRow(
                    icon: Icons.event_rounded,
                    label: 'Date & Time',
                    value: result.dateTime != null
                        ? DateFormat('d MMM yyyy · h:mm a')
                            .format(result.dateTime!)
                        : null,
                    checked: useDate,
                    onChanged: result.dateTime == null
                        ? null
                        : (v) => setLocal(() => useDate = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(
                _ConfirmedResult(
                  amount: useAmount ? selectedAmount : null,
                  title: useTitle ? selectedTitle : null,
                  dateTime: useDate ? result.dateTime : null,
                ),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.expense : AppColors.income,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Scan a bill',
      child: GestureDetector(
        onTap: _busy ? null : _startFlow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: _busy
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.primary.withValues(alpha: 0.08),
                    ],
                  ),
            color: _busy ? AppColors.primary.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.document_scanner_rounded,
                      size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                _busy ? 'Scanning…' : 'Scan',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}

class _DetectedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  /// Optional alternative candidates from the parser. Rendered below the main
  /// value as tappable pills — the [selectedPill] is highlighted; tapping a
  /// pill calls [onPickPill] so the caller can swap the selection.
  final List<String> pills;
  final String? selectedPill;
  final ValueChanged<String>? onPickPill;

  const _DetectedRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.checked,
    required this.onChanged,
    this.pills = const [],
    this.selectedPill,
    this.onPickPill,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onChanged == null;
    // Only show alternatives — drop the one we're already displaying.
    final alternatives =
        pills.where((p) => p != selectedPill).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value ?? 'Not detected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDisabled
                            ? AppColors.textTertiary
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontStyle: isDisabled ? FontStyle.italic : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: checked,
                onChanged: isDisabled ? null : (v) => onChanged!(v ?? false),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
          if (alternatives.isNotEmpty && onPickPill != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in alternatives)
                    _SuggestionPill(
                      label: p,
                      onTap: () => onPickPill!(p),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmedResult {
  final double? amount;
  final String? title;
  final DateTime? dateTime;
  const _ConfirmedResult({this.amount, this.title, this.dateTime});

  bool get hasAny => amount != null || title != null || dateTime != null;

  String get summary {
    final parts = <String>[];
    if (amount != null) parts.add('amount');
    if (title != null) parts.add('title');
    if (dateTime != null) parts.add('date');
    return 'Applied ${parts.join(', ')} from your bill';
  }

  BillScanApplied _toBillScanApplied() =>
      BillScanApplied(amount: amount, title: title, dateTime: dateTime);
}
