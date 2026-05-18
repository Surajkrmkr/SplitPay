import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/balance_model.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/sp_button.dart';

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
  late TextEditingController _amountController;
  final _noteController = TextEditingController();
  bool _settling = false;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.balance.amount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _settle() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    // Capture navigator before any async gap to avoid null context errors
    final nav = Navigator.of(context, rootNavigator: true);

    setState(() => _settling = true);
    try {
      await ref.read(groupApiServiceProvider).createSettlement(
            groupId: widget.groupId,
            payeeId: widget.balance.toUserId,
            amount: amount,
            notes: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );

      ref.invalidate(groupBalancesProvider(widget.groupId));
      ref.invalidate(groupSettlementsProvider(widget.groupId));

      if (!mounted) return;
      setState(() {
        _settling = false;
        _settled = true;
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _settling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settlement failed: $e'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
      ),
      child: _settled ? _successState() : _settleForm(isDark, currency),
    );
  }

  Widget _successState() {
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
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 36,
          ),
        )
            .animate()
            .scale(begin: const Offset(0.4, 0.4), duration: 400.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 300.ms),
        const SizedBox(height: 20),
        const Text(
          'Settled Up!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        Text(
          'Payment recorded successfully.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ).animate(delay: 250.ms).fadeIn(duration: 300.ms),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _settleForm(bool isDark, String currency) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Settle Up',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textLight,
          ),
        ),
        const SizedBox(height: 20),

        // From → To avatars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                AvatarWidget(
                  name: widget.balance.fromUserName,
                  imageUrl: widget.balance.fromUserAvatar,
                  size: 52,
                ),
                const SizedBox(height: 6),
                Text(
                  'You',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currency${widget.balance.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                AvatarWidget(
                  name: widget.balance.toUserName,
                  imageUrl: widget.balance.toUserAvatar,
                  size: 52,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.balance.toUserName.split(' ').first,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Amount field
        Text(
          'Amount',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondary : AppColors.textLightSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
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
              color: AppColors.primary,
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Note field
        TextField(
          controller: _noteController,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textLight,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Add a note (optional)',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 24),

        SpButton(
          label: 'Settle Up',
          onTap: _settling ? null : _settle,
          isLoading: _settling,
          icon: Icons.check_circle_outline_rounded,
        ),
      ],
    );
  }
}
