import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_exception.dart';
import '../../data/services/bill_scanner_service.dart';
import 'detected_field_row.dart';

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

      final applied = await showBillScanConfirmDialog(
        context,
        result: result,
        supportsTitle: widget.supportsTitle,
      );
      if (applied != null && !applied.isEmpty) {
        widget.onApply.call(applied);
        _toast('Applied details from your bill', isError: false);
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
      useRootNavigator: true,
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
                    Icon(Icons.document_scanner_rounded,
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
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(Icons.document_scanner_rounded,
                      size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                _busy ? 'Scanning…' : 'Scan',
                style: TextStyle(
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

/// Shows the "what we detected" confirm dialog for a bill scan and returns
/// the user-approved subset to apply (null if cancelled or nothing applied).
/// Pure function of [result] — shared by [BillScanButton] and any other
/// entry point that runs OCR and needs the same confirm step.
Future<BillScanApplied?> showBillScanConfirmDialog(
  BuildContext context, {
  required BillScanResult result,
  required bool supportsTitle,
}) async {
  // The "selected" candidate starts as the parser's top pick. Pills below
  // each row let the user swap to a lower-ranked alternative without leaving
  // the dialog.
  double? selectedAmount = result.amount;
  String? selectedTitle = supportsTitle ? result.title : null;

  bool useAmount = selectedAmount != null;
  bool useTitle = supportsTitle && selectedTitle != null;
  bool useDate = result.dateTime != null;

  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<BillScanApplied>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
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
                DetectedFieldRow(
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
                if (supportsTitle)
                  DetectedFieldRow(
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
                DetectedFieldRow(
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
              BillScanApplied(
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
