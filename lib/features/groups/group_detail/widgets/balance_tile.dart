import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/balance_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../shared/widgets/avatar_widget.dart';

class BalanceTile extends ConsumerWidget {
  final BalanceModel balance;
  final String groupId;
  final VoidCallback? onSettleUp;
  final Future<void> Function()? onRemind;

  const BalanceTile({
    super.key,
    required this.balance,
    required this.groupId,
    this.onSettleUp,
    this.onRemind,
  });

  static const double _pillWidth = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    final currentUserId = ref.watch(currentUserProvider)?.id ?? 'user_1';
    final currency = ref.watch(currencyProvider);
    final isYouOwing = balance.fromUserId == currentUserId;
    final isYouReceiving = balance.toUserId == currentUserId;
    final isInvolved = isYouOwing || isYouReceiving;

    final accentColor = isYouOwing
        ? AppColors.expense
        : isYouReceiving
            ? primary
            : AppColors.textSecondary;

    return GestureDetector(
      onTap: isYouOwing ? onSettleUp : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? cardBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isInvolved
                ? accentColor.withValues(alpha: 0.35)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isInvolved ? 1.5 : 1,
          ),
          boxShadow: isInvolved
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (isInvolved)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3.5, color: accentColor),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    isInvolved ? 16 : 14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Avatars row ─────────────────────────────
                    Row(
                      children: [
                        // From – fixed width so it's symmetrical
                        SizedBox(
                          width: _pillWidth,
                          child: _UserPill(
                            name: balance.fromUserName,
                            avatar: balance.fromUserAvatar,
                            label: _displayName(balance.fromUserName,
                                currentUserId, balance.fromUserId),
                            isDark: isDark,
                          ),
                        ),
                        // Center: arrow + amount – fills remaining space
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: accentColor,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatAmountWithCommas(balance.amount, symbol: currency),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                              const Text(
                                'owes',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // To – same fixed width as From
                        SizedBox(
                          width: _pillWidth,
                          child: _UserPill(
                            name: balance.toUserName,
                            avatar: balance.toUserAvatar,
                            label: _displayName(balance.toUserName,
                                currentUserId, balance.toUserId),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    // ── Settle button below (only for current user's debts) ──
                    if (isYouOwing) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, primary.withValues(alpha: 0.85)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Settle Up',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                    if (isYouReceiving && onRemind != null) ...[
                      if (isYouOwing) const SizedBox(height: 8),
                      _RemindButton(onPressed: onRemind!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayName(String name, String currentUserId, String userId) =>
      userId == currentUserId ? 'You' : name;
}

class _RemindButton extends StatefulWidget {
  final Future<void> Function() onPressed;

  const _RemindButton({required this.onPressed});

  @override
  State<_RemindButton> createState() => _RemindButtonState();
}

class _RemindButtonState extends State<_RemindButton> {
  bool _isSending = false;

  Future<void> _sendReminder() async {
    setState(() => _isSending = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: _isSending ? null : _sendReminder,
      icon: _isSending
          ? SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                color: colorScheme.onPrimary,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.notifications_active_outlined, size: 17),
      label: Text(_isSending ? 'Sending...' : 'Remind'),
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size.fromHeight(40),
      ),
    );
  }
}

class _UserPill extends StatelessWidget {
  final String name;
  final String? avatar;
  final String label;
  final bool isDark;

  const _UserPill({
    required this.name,
    required this.avatar,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarWidget(name: name, imageUrl: avatar, size: 40),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textLightSecondary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
