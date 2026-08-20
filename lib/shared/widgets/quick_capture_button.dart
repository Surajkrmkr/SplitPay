import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/bill_scanner_service.dart';
import '../../data/services/sms_parser_service.dart';
import 'bill_scan_button.dart';
import 'detected_field_row.dart';

/// Outcome of the SMS-paste flow — same contract as [BillScanApplied], plus
/// [type] since bank SMS usually say outright whether it's a debit or credit.
class SmsPasteApplied {
  final double? amount;
  final String? title;
  final DateTime? dateTime;
  final TransactionType? type;

  const SmsPasteApplied({this.amount, this.title, this.dateTime, this.type});

  bool get isEmpty =>
      amount == null && title == null && dateTime == null && type == null;
}

enum _CaptureOption { camera, gallery, sms }

/// Single entry point for auto-filling a transaction from a bill photo or a
/// pasted bank/UPI SMS. Replaces having separate "Scan" and "SMS" buttons
/// competing for space next to the sheet title — one compact trigger opens
/// an action sheet where the user picks how they want to auto-fill.
class QuickCaptureButton extends ConsumerStatefulWidget {
  /// Whether the confirm dialogs offer the merchant/payee name as an
  /// applicable field. (The add-transaction sheet has no title, only a note.)
  final bool supportsTitle;
  final ValueChanged<BillScanApplied> onScanApply;
  final ValueChanged<SmsPasteApplied> onSmsApply;

  const QuickCaptureButton({
    super.key,
    required this.onScanApply,
    required this.onSmsApply,
    this.supportsTitle = true,
  });

  @override
  ConsumerState<QuickCaptureButton> createState() => _QuickCaptureButtonState();
}

class _QuickCaptureButtonState extends ConsumerState<QuickCaptureButton> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _startFlow() async {
    if (_busy) return;
    final option = await _pickOption();
    if (option == null || !mounted) return;

    setState(() => _busy = true);
    try {
      switch (option) {
        case _CaptureOption.camera:
          await _runScan(ImageSource.camera);
        case _CaptureOption.gallery:
          await _runScan(ImageSource.gallery);
        case _CaptureOption.sms:
          await _runSmsPaste();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_CaptureOption?> _pickOption() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<_CaptureOption>(
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
                    const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Auto-fill this transaction',
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
                  'Scan a bill or paste a bank/UPI SMS — we\'ll fill in the amount, note, and date for you.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.photo_camera_rounded,
                label: 'Take a photo of a bill',
                onTap: () => Navigator.of(ctx).pop(_CaptureOption.camera),
              ),
              _OptionTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose a bill from gallery',
                onTap: () => Navigator.of(ctx).pop(_CaptureOption.gallery),
              ),
              _OptionTile(
                icon: Icons.sms_rounded,
                label: 'Paste a bank/UPI SMS',
                onTap: () => Navigator.of(ctx).pop(_CaptureOption.sms),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runScan(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (file == null || !mounted) return;

      final result = await ref.read(billScannerServiceProvider).scan(file.path);
      if (!mounted) return;

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
        widget.onScanApply(applied);
        _toast('Applied details from your bill', isError: false);
      }
    } catch (e) {
      if (mounted) _toast(friendlyErrorMessage(e), isError: true);
    }
  }

  Future<void> _runSmsPaste() async {
    final text = await _showSmsPasteInputDialog();
    if (text == null || text.trim().isEmpty || !mounted) return;

    final result = ref.read(smsParserServiceProvider).parse(text);
    if (!result.hasAny) {
      _toast("Couldn't detect any details from that text.", isError: true);
      return;
    }

    final applied = await _showSmsConfirmDialog(result);
    if (applied != null && !applied.isEmpty) {
      widget.onSmsApply(applied);
      _toast('Applied details from your SMS', isError: false);
    }
  }

  Future<String?> _showSmsPasteInputDialog() async {
    final controller = TextEditingController();
    try {
      final clip = await Clipboard.getData('text/plain');
      final clipText = clip?.text?.trim();
      if (clipText != null && clipText.isNotEmpty) controller.text = clipText;
    } catch (_) {
      // Clipboard access can fail on some platforms — not fatal, just skip
      // the convenience prefill.
    }
    if (!mounted) return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.sms_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            const Text('Paste SMS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Paste your bank/UPI debit or credit SMS here…',
              hintStyle: const TextStyle(fontSize: 13),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(controller.text),
            child: const Text('Parse'),
          ),
        ],
      ),
    );
  }

  Future<SmsPasteApplied?> _showSmsConfirmDialog(SmsParseResult result) async {
    double? selectedAmount = result.amount;
    String? selectedTitle = widget.supportsTitle ? result.title : null;
    TransactionType? selectedType = result.type;

    bool useAmount = selectedAmount != null;
    bool useTitle = widget.supportsTitle && selectedTitle != null;
    bool useDate = result.dateTime != null;
    bool useType = selectedType != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<SmsPasteApplied>(
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
              const Text('Detected from your SMS',
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
                    icon: Icons.swap_vert_rounded,
                    label: 'Type',
                    value: selectedType == null
                        ? null
                        : (selectedType == TransactionType.expense
                            ? 'Expense'
                            : 'Income'),
                    checked: useType,
                    onChanged: selectedType == null
                        ? null
                        : (v) => setLocal(() => useType = v),
                    pills: const ['Expense', 'Income'],
                    selectedPill: selectedType == null
                        ? null
                        : (selectedType == TransactionType.expense
                            ? 'Expense'
                            : 'Income'),
                    onPickPill: (label) => setLocal(() {
                      selectedType = label == 'Expense'
                          ? TransactionType.expense
                          : TransactionType.income;
                      useType = true;
                    }),
                  ),
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
                  if (widget.supportsTitle)
                    DetectedFieldRow(
                      icon: Icons.storefront_rounded,
                      label: 'Payee / Merchant',
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
                    label: 'Date',
                    value: result.dateTime != null
                        ? DateFormat('d MMM yyyy').format(result.dateTime!)
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
                SmsPasteApplied(
                  amount: useAmount ? selectedAmount : null,
                  title: useTitle ? selectedTitle : null,
                  dateTime: useDate ? result.dateTime : null,
                  type: useType ? selectedType : null,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _busy ? null : _startFlow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.16),
              AppColors.secondary.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _busy
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              _busy ? 'Working…' : 'Autofill from bill or SMS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionTile({
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
