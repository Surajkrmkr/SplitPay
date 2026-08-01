import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/balance_model.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/services/upi_service.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/region_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/sp_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sheet state machine
// ─────────────────────────────────────────────────────────────────────────────
enum _SheetView { methods, upiForm, appPicker, processing, result }

class SettleUpSheet extends ConsumerStatefulWidget {
  final BalanceModel balance;
  final String groupId;

  const SettleUpSheet({
    super.key,
    required this.balance,
    required this.groupId,
  });

  @override
  ConsumerState<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<SettleUpSheet> {
  _SheetView _view = _SheetView.methods;

  // UPI form controllers
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;

  // Installed UPI apps
  List<UpiApp> _upiApps = [];
  bool _loadingApps = false;

  // Payment result
  UpiTxnResult? _txnResult;
  bool _manualSettling = false;
  bool _settled = false;
  bool _isLaunchingApp = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.balance.amount.toStringAsFixed(2),
    );
    _noteCtrl = TextEditingController();
    // Load installed UPI apps up front so the method-picker can preview them.
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _loadingApps = true);
    final apps = await ref.read(upiServiceProvider).getInstalledApps();
    if (!mounted) return;
    setState(() {
      _upiApps = apps;
      _loadingApps = false;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _goToUpiForm() {
    setState(() => _view = _SheetView.upiForm);
    if (_upiApps.isEmpty && !_loadingApps) {
      _loadInstalledApps();
    }
  }

  Future<void> _startManualPayFlow() async {
    if (!_validateUpiForm()) return;
    if (_upiApps.isEmpty) {
      _showSnack('No installed UPI apps found on this device');
      return;
    }

    final selectedApp = _upiApps.first;
    setState(() {
      _isLaunchingApp = true;
      _view = _SheetView.processing;
    });

    ref.read(upiServiceProvider).openBareUpiApp(selectedApp);

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _isLaunchingApp = false;
      });
    }
  }

  void _backToMethods() => setState(() => _view = _SheetView.methods);
  void _backToUpiForm() => setState(() => _view = _SheetView.upiForm);

  // ── Validation ───────────────────────────────────────────────────────────────

  bool _validateUpiForm() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount');
      return false;
    }
    final roundedAmount = (amount * 100).round() / 100;
    final roundedDebt = (widget.balance.amount * 100).round() / 100;
    if (roundedAmount - roundedDebt > 0.01) {
      _showSnack('Amount cannot exceed what you owe');
      return false;
    }
    return true;
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  Future<void> _recordSettlementDirect() async {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? widget.balance.amount;
    setState(() => _manualSettling = true);
    try {
      await ref.read(paymentRepositoryProvider).settleViaUpi(
            groupId: widget.groupId,
            payeeId: widget.balance.toUserId,
            amount: amount,
            notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      if (!mounted) return;
      _invalidateProviders();
      setState(() {
        _settled = true;
        _txnResult = const UpiTxnResult(
          status: UpiTxnStatus.success,
        );
        _view = _SheetView.result;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to record settlement: $e');
    } finally {
      if (mounted) setState(() => _manualSettling = false);
    }
  }

  Future<void> _payWithApp(UpiApp app) async {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? widget.balance.amount;
    setState(() => _view = _SheetView.processing);

    final result = await ref.read(paymentRepositoryProvider).payViaUpi(
          app: app,
          groupId: widget.groupId,
          payeeId: widget.balance.toUserId,
          payeeUpiId: '',
          payeeName: widget.balance.toUserName,
          amount: amount,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );

    if (!mounted) return;

    if (result.txn.status == UpiTxnStatus.success) {
      _invalidateProviders();
    }

    setState(() {
      _txnResult = result.txn;
      _view = _SheetView.result;
    });
  }

  Future<void> _settleManually() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount');
      return;
    }
    final roundedAmount = (amount * 100).round() / 100;
    final roundedDebt = (widget.balance.amount * 100).round() / 100;
    if (roundedAmount - roundedDebt > 0.01) {
      _showSnack('Amount cannot exceed what you owe');
      return;
    }

    final confirmed = await _showManualConfirmDialog();
    if (!confirmed || !mounted) return;

    final nav = Navigator.of(context, rootNavigator: true);
    setState(() => _manualSettling = true);
    try {
      await ref.read(paymentRepositoryProvider).settleManually(
            groupId: widget.groupId,
            payeeId: widget.balance.toUserId,
            amount: amount,
            notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      _invalidateProviders();
      if (!mounted) return;
      setState(() {
        _manualSettling = false;
        _settled = true;
        _view = _SheetView.result;
        _txnResult = const UpiTxnResult(status: UpiTxnStatus.success);
      });
      await Future.delayed(const Duration(milliseconds: 1600));
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _manualSettling = false);
      _showSnack(friendlyErrorMessage(e));
    }
  }

  void _invalidateProviders() {
    ref.invalidate(groupBalancesProvider(widget.groupId));
    ref.invalidate(groupSettlementsProvider(widget.groupId));
    ref.invalidate(groupActivityProvider(widget.groupId));
  }

  Future<bool> _showManualConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurface
                : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Mark as Settled?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            content: Text(
              'Are you sure you want to mark this as settled without payment?\n\n'
              'This will record the debt as cleared manually.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes, Settle'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.expense,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── QR Scan ──────────────────────────────────────────────────────────────

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;

    final isResultView = _view == _SheetView.result;
    final initialSize = isResultView ? 0.38 : 0.75;
    final minSize = isResultView ? 0.25 : 0.4;
    final maxSize = isResultView ? 0.5 : 0.95;
    final snapSizes = isResultView ? const [0.38, 0.5] : const [0.75, 0.95];

    return DraggableScrollableSheet(
      key: ValueKey(_view),
      initialChildSize: initialSize,
      maxChildSize: maxSize,
      minChildSize: minSize,
      expand: false,
      snap: true,
      snapSizes: snapSizes,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const _Handle(),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _buildView(isDark),
                ),
              ),
            ),
            if (_view == _SheetView.upiForm)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  (keyboardHeight > 0 ? keyboardHeight : safeBottom) + 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.5,
                    ),
                  ),
                ),
                child: SpButton(
                  label: 'Continue to Pay',
                  onTap: _startManualPayFlow,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _relaunchBareApp() async {
    final selectedApp = _upiApps.isNotEmpty ? _upiApps.first : null;
    if (selectedApp != null) {
      ref.read(upiServiceProvider).openBareUpiApp(selectedApp);
    }
  }

  Widget _buildView(bool isDark) {
    return switch (_view) {
      _SheetView.methods => _MethodPickerView(
          key: const ValueKey('methods'),
          balance: widget.balance,
          isDark: isDark,
          showUpi: ref.watch(showUpiProvider),
          onUpi: _startManualPayFlow,
          onManual: _settleManually,
          isLoading: _manualSettling,
          amountCtrl: _amountCtrl,
          noteCtrl: _noteCtrl,
          upiApps: _upiApps,
        ),
      _SheetView.upiForm => _UpiFormView(
          key: const ValueKey('upiForm'),
          balance: widget.balance,
          isDark: isDark,
          amountCtrl: _amountCtrl,
          noteCtrl: _noteCtrl,
          upiApps: _upiApps,
          loadingApps: _loadingApps,
          onBack: _backToMethods,
          onPay: _startManualPayFlow,
        ),
      _SheetView.appPicker => _AppPickerView(
          key: const ValueKey('appPicker'),
          apps: _upiApps,
          isDark: isDark,
          onBack: _backToUpiForm,
          onSelectApp: _payWithApp,
        ),
      _SheetView.processing => _ProcessingView(
          key: const ValueKey('processing'),
          isLaunching: _isLaunchingApp,
          onRecordSettled: _recordSettlementDirect,
          onRetryApp: _relaunchBareApp,
          onCancel: _backToMethods,
          onEditAmount: _backToMethods,
          isDark: isDark,
        ),
      _SheetView.result => _ResultView(
          key: const ValueKey('result'),
          txnResult: _txnResult,
          isManual: _settled,
          isDark: isDark,
          onRetry: _goToUpiForm,
          onManualFallback: _settleManually,
          onDone: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View 1 — Method Picker
// ─────────────────────────────────────────────────────────────────────────────
class _MethodPickerView extends ConsumerWidget {
  final BalanceModel balance;
  final bool isDark;
  final bool showUpi;
  final VoidCallback onUpi;
  final VoidCallback onManual;
  final bool isLoading;
  final TextEditingController amountCtrl;
  final TextEditingController noteCtrl;
  final List<UpiApp> upiApps;

  const _MethodPickerView({
    super.key,
    required this.balance,
    required this.isDark,
    required this.showUpi,
    required this.onUpi,
    required this.onManual,
    required this.isLoading,
    required this.amountCtrl,
    required this.noteCtrl,
    required this.upiApps,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settle Up',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose how you\'d like to settle',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _AvatarRow(balance: balance, currency: currency),
        const SizedBox(height: 8),

        // Amount & note (compact)
        TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textLight,
          ),
          decoration: InputDecoration(
            prefixText: '$currency ',
            prefixStyle: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: noteCtrl,
          style: TextStyle(
              color: isDark ? Colors.white : AppColors.textLight, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Add a note (optional)',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        if (showUpi) ...[
          _OptionCard(
            isDark: isDark,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: upiApps.isEmpty ? Colors.grey : const Color(0xFF5B6EF5),
            iconBg: upiApps.isEmpty ? Colors.grey : const Color(0xFF5B6EF5),
            title: 'Pay via UPI',
            subtitle: upiApps.isEmpty
                ? 'No UPI apps installed on this device'
                : 'Instant · Secure · Free',
            trailing: _UpiAppPills(apps: upiApps),
            onTap: upiApps.isEmpty ? null : onUpi,
          ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.06),
          const SizedBox(height: 12),
        ],

        _OptionCard(
          isDark: isDark,
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.primary,
          iconBg: AppColors.primary,
          title: 'Mark as Settled',
          subtitle: 'Record a cash or offline payment',
          onTap: isLoading ? null : onManual,
          trailing: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : null,
        )
            .animate(delay: showUpi ? 80.ms : 0.ms)
            .fadeIn(duration: 250.ms)
            .slideY(begin: 0.06),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View 2 — UPI Payment Form
// ─────────────────────────────────────────────────────────────────────────────
class _UpiFormView extends ConsumerWidget {
  final BalanceModel balance;
  final bool isDark;
  final TextEditingController amountCtrl;
  final TextEditingController noteCtrl;
  final List<UpiApp> upiApps;
  final bool loadingApps;
  final VoidCallback onBack;
  final VoidCallback onPay;

  const _UpiFormView({
    super.key,
    required this.balance,
    required this.isDark,
    required this.amountCtrl,
    required this.noteCtrl,
    required this.upiApps,
    required this.loadingApps,
    required this.onBack,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with back button
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_rounded,
                    size: 18,
                    color: isDark ? Colors.white : AppColors.textLight),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Pay via UPI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _AvatarRow(balance: balance, currency: currency),
        const SizedBox(height: 20),

        // Amount
        _FieldLabel('Amount', isDark: isDark),
        const SizedBox(height: 8),
        TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            LengthLimitingTextInputFormatter(50),
            CurrencyInputFormatter(),
          ],
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textLight,
          ),
          decoration: InputDecoration(
            prefixText: '$currency ',
            prefixStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Note
        _FieldLabel('Note', isDark: isDark),
        const SizedBox(height: 8),
        TextField(
          controller: noteCtrl,
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
          style: TextStyle(
              color: isDark ? Colors.white : AppColors.textLight, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Optional note for recipient',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        if (loadingApps)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else if (upiApps.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No UPI apps found. Install Google Pay, PhonePe or Paytm to continue.',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View 3 — UPI App Picker
// ─────────────────────────────────────────────────────────────────────────────
class _AppPickerView extends StatelessWidget {
  final List<UpiApp> apps;
  final bool isDark;
  final VoidCallback onBack;
  final void Function(UpiApp) onSelectApp;

  const _AppPickerView({
    super.key,
    required this.apps,
    required this.isDark,
    required this.onBack,
    required this.onSelectApp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_rounded,
                    size: 18,
                    color: isDark ? Colors.white : AppColors.textLight),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Choose UPI App',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select which app to complete the payment',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        ...apps.asMap().entries.map((entry) {
          final i = entry.key;
          final app = entry.value;
          return _AppPickerTile(
            app: app,
            isDark: isDark,
            onTap: () => onSelectApp(app),
          )
              .animate(delay: (i * 50).ms)
              .fadeIn(duration: 200.ms)
              .slideX(begin: 0.05);
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View 4 — Processing
// ─────────────────────────────────────────────────────────────────────────────
class _ProcessingView extends StatelessWidget {
  final bool isLaunching;
  final VoidCallback onRecordSettled;
  final VoidCallback onRetryApp;
  final VoidCallback onCancel;
  final VoidCallback onEditAmount;
  final bool isDark;

  const _ProcessingView({
    super.key,
    required this.isLaunching,
    required this.onRecordSettled,
    required this.onRetryApp,
    required this.onCancel,
    required this.onEditAmount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isLaunching) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              'Opening payment app…',
              style: TextStyle(
                fontSize: 17,
                color: isDark ? Colors.white : AppColors.textLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Back button
          Row(
            children: [
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 18,
                      color: isDark ? Colors.white : AppColors.textLight),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Confirmation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Did your payment complete?',
            style: TextStyle(
              fontSize: 19,
              color: isDark ? Colors.white : AppColors.textLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Confirm if you finished the transaction in your UPI app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // Option 1: Yes, Mark as Settled
          SpButton(
            label: 'Yes, Mark as Settled',
            icon: Icons.check_circle_rounded,
            onTap: onRecordSettled,
          ),
          const SizedBox(height: 10),
          // Option 2: Re-open UPI App (Retry intent)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onRetryApp,
            icon: const Icon(Icons.open_in_new_rounded,
                size: 18, color: AppColors.primary),
            label: const Text(
              'Re-open UPI App',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Option 3: Settled custom / less amount
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onEditAmount,
            icon: Icon(Icons.edit_rounded,
                size: 18,
                color: isDark ? Colors.white70 : AppColors.textSecondary),
            label: Text(
              'Settled custom or partial amount',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View 5 — Result (Success / Failure / Submitted / Cancelled)
// ─────────────────────────────────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  final UpiTxnResult? txnResult;
  final bool isManual;
  final bool isDark;
  final VoidCallback onRetry;
  final VoidCallback onManualFallback;
  final VoidCallback onDone;

  const _ResultView({
    super.key,
    required this.txnResult,
    required this.isManual,
    required this.isDark,
    required this.onRetry,
    required this.onManualFallback,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final status = txnResult?.status ?? UpiTxnStatus.failure;

    return switch (status) {
      UpiTxnStatus.success => _SuccessView(
          txnResult: txnResult,
          isManual: isManual,
          onDone: onDone,
        ),
      UpiTxnStatus.submitted => _SubmittedView(
          txnResult: txnResult,
          onManualFallback: onManualFallback,
          onDone: onDone,
          isDark: isDark,
        ),
      UpiTxnStatus.cancelled => _CancelledView(
          onRetry: onRetry,
          onDone: onDone,
          isDark: isDark,
        ),
      UpiTxnStatus.failure => _FailureView(
          onRetry: onRetry,
          onManualFallback: onManualFallback,
          isDark: isDark,
        ),
    };
  }
}

class _SuccessView extends StatelessWidget {
  final UpiTxnResult? txnResult;
  final bool isManual;
  final VoidCallback onDone;

  const _SuccessView(
      {required this.txnResult, required this.isManual, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
        )
            .animate()
            .scale(
                begin: const Offset(0.4, 0.4),
                duration: 450.ms,
                curve: Curves.elasticOut)
            .fadeIn(duration: 300.ms),
        const SizedBox(height: 20),
        const Text(
          'Settled Up!',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        Text(
          isManual
              ? 'Recorded as manually settled.'
              : 'UPI payment successful.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ).animate(delay: 220.ms).fadeIn(duration: 300.ms),
        if (txnResult?.transactionId != null && !isManual) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Txn: ${txnResult!.transactionId}',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
        ],
        const SizedBox(height: 28),
        SpButton(label: 'Done', onTap: onDone, icon: Icons.check_rounded)
            .animate(delay: 350.ms)
            .fadeIn(duration: 250.ms),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _SubmittedView extends StatelessWidget {
  final UpiTxnResult? txnResult;
  final VoidCallback onManualFallback;
  final VoidCallback onDone;
  final bool isDark;

  const _SubmittedView({
    required this.txnResult,
    required this.onManualFallback,
    required this.onDone,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.5), width: 2),
          ),
          child: const Icon(Icons.hourglass_top_rounded,
              color: AppColors.warning, size: 32),
        ).animate().scale(
            begin: const Offset(0.6, 0.6),
            duration: 350.ms,
            curve: Curves.easeOut),
        const SizedBox(height: 20),
        Text(
          'Payment Pending',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textLight,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your payment is processing. We\'ll update the balance once confirmed.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        if (txnResult?.transactionId != null) ...[
          const SizedBox(height: 12),
          Text(
            'Ref: ${txnResult!.transactionId}',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
        const SizedBox(height: 28),
        SpButton(label: 'Done', onTap: onDone),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onManualFallback,
          child: Text(
            'Mark manually if payment was received',
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onManualFallback;
  final bool isDark;

  const _FailureView(
      {required this.onRetry,
      required this.onManualFallback,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.expense.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.expense.withValues(alpha: 0.4), width: 2),
          ),
          child: const Icon(Icons.close_rounded,
              color: AppColors.expense, size: 32),
        ).animate().scale(
            begin: const Offset(0.6, 0.6),
            duration: 350.ms,
            curve: Curves.easeOut),
        const SizedBox(height: 20),
        Text(
          'Payment Failed',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textLight,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The transaction did not go through. Your balance has not been changed.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 28),
        SpButton(
            label: 'Try Again', onTap: onRetry, icon: Icons.refresh_rounded),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onManualFallback,
          child: Text(
            'Mark as settled manually instead',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _CancelledView extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onDone;
  final bool isDark;

  const _CancelledView(
      {required this.onRetry, required this.onDone, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.textTertiary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.cancel_outlined,
              color: AppColors.textSecondary, size: 32),
        ).animate().scale(begin: const Offset(0.6, 0.6), duration: 350.ms),
        const SizedBox(height: 20),
        Text(
          'Cancelled',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textLight,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You cancelled the payment. No charges were made.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 28),
        SpButton(
            label: 'Try Again', onTap: onRetry, icon: Icons.refresh_rounded),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onDone,
          child: Text(
            'Close',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.darkBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _AvatarRow extends ConsumerWidget {
  final BalanceModel balance;
  final String currency;
  const _AvatarRow({required this.balance, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _UserPill(
              name: balance.fromUserName,
              avatar: balance.fromUserAvatar,
              label: 'You'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(height: 2),
                Text(
                  '$currency${balance.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppColors.expense,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _UserPill(
              name: balance.toUserName,
              avatar: balance.toUserAvatar,
              label: balance.toUserName.split(' ').first),
        ],
      ),
    );
  }
}

class _UserPill extends StatelessWidget {
  final String name;
  final String? avatar;
  final String label;
  const _UserPill(
      {required this.name, required this.avatar, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarWidget(name: name, imageUrl: avatar, size: 44),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _FieldLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textSecondary : AppColors.textLightSecondary,
      ),
    );
  }
}

class _OptionCard extends StatefulWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _OptionCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: Opacity(
        opacity: widget.onTap == null ? 0.55 : 1.0,
        child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _pressed
                ? (widget.isDark ? AppColors.darkElevated : AppColors.lightCard)
                : (widget.isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : (widget.isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.iconBg,
                      widget.iconBg.withValues(alpha: 0.7)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            widget.isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ] else
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _UpiAppPills extends StatelessWidget {
  final List<UpiApp> apps;
  const _UpiAppPills({required this.apps});

  @override
  Widget build(BuildContext context) {
    // Leave blank when no UPI apps are installed.
    if (apps.isEmpty) return const SizedBox.shrink();

    // Show up to 3 app icons + a "+N" pill if there are more.
    final visible = apps.take(3).toList();
    final extra = apps.length - visible.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final app in visible)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: _UpiAppIcon(app: app),
          ),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 0.6),
              ),
              child: Text(
                '+$extra',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UpiAppIcon extends StatelessWidget {
  final UpiApp app;
  const _UpiAppIcon({required this.app});

  @override
  Widget build(BuildContext context) {
    final hasIcon = app.icon != null && app.icon!.isNotEmpty;
    return ClipOval(
      child: SizedBox(
        width: 22,
        height: 22,
        child: hasIcon
            ? Image.memory(app.icon!, fit: BoxFit.cover)
            : Container(
                color: AppColors.primary.withValues(alpha: 0.2),
                alignment: Alignment.center,
                child: Text(
                  app.name.isNotEmpty ? app.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}

class _AppPickerTile extends StatelessWidget {
  final UpiApp app;
  final bool isDark;
  final VoidCallback onTap;
  const _AppPickerTile(
      {required this.app, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevated : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: app.icon != null && app.icon!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(app.icon!,
                          width: 44, height: 44, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                app.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
