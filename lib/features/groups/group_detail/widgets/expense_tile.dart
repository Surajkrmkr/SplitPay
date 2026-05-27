import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/category_app_icons.dart';
import '../../../../data/models/expense_participant_model.dart';
import '../../../../data/models/group_expense_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../shared/widgets/avatar_widget.dart';

class ExpenseTile extends ConsumerStatefulWidget {
  final GroupExpenseModel expense;
  final bool showDivider; // kept for API compat but unused in new design
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.showDivider = true,
    this.onEdit,
    this.onDelete,
  });

  @override
  ConsumerState<ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends ConsumerState<ExpenseTile> {
  bool _expanded = false;

  // Stable color palette so each member keeps the same color across the bar
  // and the list — index-based so it's predictable.
  static const _memberPalette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.catFood,
    AppColors.catTravel,
    AppColors.catEntertainment,
    AppColors.catShopping,
    AppColors.catHealth,
    AppColors.catSubscription,
    AppColors.catBills,
    AppColors.warning,
  ];

  Color _colorForIndex(int i) => _memberPalette[i % _memberPalette.length];

  static IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('food') || t.contains('lunch') || t.contains('dinner') ||
        t.contains('breakfast') || t.contains('restaurant') ||
        t.contains('shack') || t.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (t.contains('hotel') || t.contains('stay') || t.contains('resort') ||
        t.contains('airbnb')) {
      return Icons.hotel_rounded;
    }
    if (t.contains('travel') || t.contains('taxi') || t.contains('uber') ||
        t.contains('cab') || t.contains('fuel') || t.contains('petrol') ||
        t.contains('flight')) {
      return Icons.directions_car_rounded;
    }
    if (t.contains('drink') || t.contains('beer') || t.contains('wine') ||
        t.contains('alcohol')) {
      return Icons.local_bar_rounded;
    }
    if (t.contains('coffee') || t.contains('tea')) {
      return Icons.local_cafe_rounded;
    }
    if (t.contains('groceri') || t.contains('supermarket') ||
        t.contains('market')) {
      return Icons.shopping_cart_rounded;
    }
    if (t.contains('bill') || t.contains('electric') || t.contains('rent') ||
        t.contains('utility')) {
      return Icons.receipt_long_rounded;
    }
    if (t.contains('movie') || t.contains('cinema') ||
        t.contains('entertain')) {
      return Icons.movie_rounded;
    }
    if (t.contains('dive') || t.contains('scuba') || t.contains('swim')) {
      return Icons.scuba_diving_rounded;
    }
    return Icons.attach_money_rounded;
  }

  static Color _colorFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('food') || t.contains('lunch') || t.contains('dinner') ||
        t.contains('restaurant') || t.contains('shack')) {
      return AppColors.catFood;
    }
    if (t.contains('hotel') || t.contains('stay') || t.contains('resort') ||
        t.contains('travel') || t.contains('taxi') || t.contains('fuel') ||
        t.contains('cab') || t.contains('flight')) {
      return AppColors.catTravel;
    }
    if (t.contains('drink') || t.contains('coffee') || t.contains('tea')) {
      return AppColors.catEntertainment;
    }
    if (t.contains('groceri') || t.contains('market')) {
      return AppColors.catShopping;
    }
    if (t.contains('bill') || t.contains('rent') || t.contains('electric')) {
      return AppColors.catBills;
    }
    if (t.contains('movie') || t.contains('entertain')) {
      return AppColors.catEntertainment;
    }
    return AppColors.secondary;
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }

  String _splitTypeLabel(String type) {
    switch (type) {
      case 'PERCENTAGE':
        return 'Split by %';
      case 'EXACT':
        return 'Custom split';
      case 'EQUAL':
      default:
        return 'Equal split';
    }
  }

  IconData _splitTypeIcon(String type) {
    switch (type) {
      case 'PERCENTAGE':
        return Icons.percent_rounded;
      case 'EXACT':
        return Icons.tune_rounded;
      case 'EQUAL':
      default:
        return Icons.balance_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final currency = ref.watch(currencyProvider);

    final isPaidByMe = expense.paidById == currentUserId;
    final myShare = expense.shareForUser(currentUserId);
    final accentColor = _colorFor(expense.title);

    final String statusLabel;
    final Color statusColor;
    if (isPaidByMe) {
      statusLabel = 'you paid';
      statusColor = AppColors.income;
    } else if (myShare > 0) {
      statusLabel = 'owe $currency${myShare.toStringAsFixed(0)}';
      statusColor = AppColors.expense;
    } else {
      statusLabel = 'not involved';
      statusColor = AppColors.textTertiary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(width: 4, color: accentColor),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: expense.appIcon != null
                                // Match the AppIconPicker tile treatment: a
                                // card-colored container with a subtle border
                                // and `BoxFit.contain` so the brand icon reads
                                // the same here as in the picker.
                                ? Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkCard
                                          : AppColors.lightCard,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(7),
                                      child: Image.asset(
                                        CategoryAppIcons.pathFor(
                                            expense.appIcon!),
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(
                                          _iconFor(expense.title),
                                          color: accentColor,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  )
                                : _ExpenseIconBubble(
                                    icon: _iconFor(expense.title),
                                    color: accentColor,
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  expense.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textLight,
                                    letterSpacing: -0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Payer row — avatar + name reads at a glance
                                Row(
                                  children: [
                                    AvatarWidget(
                                      name: expense.paidByName,
                                      imageUrl: expense.paidByAvatar,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: RichText(
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: isPaidByMe
                                                  ? 'You'
                                                  : expense.paidByName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: isPaidByMe
                                                    ? AppColors.primary
                                                    : (isDark
                                                        ? Colors.white
                                                        : AppColors.textLight),
                                              ),
                                            ),
                                            const TextSpan(text: ' paid'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Meta row — date + split type. Chip is
                                // Flexible so it ellipsises before overflowing
                                // when the date label is long.
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 10,
                                        color: AppColors.textTertiary),
                                    const SizedBox(width: 3),
                                    Text(
                                      _formatDate(expense.date),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: _SplitTypeChip(
                                        icon:
                                            _splitTypeIcon(expense.splitType),
                                        label: _splitTypeLabel(
                                            expense.splitType),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$currency${expense.amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textLight,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onEdit != null || widget.onDelete != null)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                color: AppColors.textTertiary, size: 18),
                            color: isDark ? AppColors.darkCard : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val == 'edit') widget.onEdit?.call();
                              if (val == 'delete') widget.onDelete?.call();
                            },
                            itemBuilder: (_) => [
                              if (widget.onEdit != null)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ]),
                                ),
                              if (widget.onDelete != null)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ]),
                                ),
                            ],
                          )
                        else
                          const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: _SplitBreakdown(
                      expense: expense,
                      currentUserId: currentUserId,
                      currency: currency,
                      isDark: isDark,
                      colorForIndex: _colorForIndex,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseIconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _ExpenseIconBubble({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SplitTypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SplitTypeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.primary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitBreakdown extends StatelessWidget {
  final GroupExpenseModel expense;
  final String currentUserId;
  final String currency;
  final bool isDark;
  final Color Function(int) colorForIndex;

  const _SplitBreakdown({
    required this.expense,
    required this.currentUserId,
    required this.currency,
    required this.isDark,
    required this.colorForIndex,
  });

  @override
  Widget build(BuildContext context) {
    final total = expense.amount;
    final participants = expense.participants;
    if (participants.isEmpty || total <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // Stacked bar — each segment proportional to that member's share
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (var i = 0; i < participants.length; i++)
                    Expanded(
                      flex: ((participants[i].share / total) * 1000)
                          .clamp(1, 1000)
                          .round(),
                      child: Container(color: colorForIndex(i)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(participants.length, (i) {
            final p = participants[i];
            final isYou = p.userId == currentUserId;
            final pct = total > 0 ? (p.share / total) * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MemberRow(
                participant: p,
                color: colorForIndex(i),
                share: p.share,
                pct: pct,
                isYou: isYou,
                currency: currency,
                isDark: isDark,
                splitType: expense.splitType,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final ExpenseParticipantModel participant;
  final Color color;
  final double share;
  final double pct;
  final bool isYou;
  final String currency;
  final bool isDark;
  final String splitType;

  const _MemberRow({
    required this.participant,
    required this.color,
    required this.share,
    required this.pct,
    required this.isYou,
    required this.currency,
    required this.isDark,
    required this.splitType,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = splitType == 'PERCENTAGE' &&
            participant.percentage != null
        ? '${participant.percentage!.toStringAsFixed(1)}%'
        : '${pct.toStringAsFixed(0)}%';

    return Row(
      children: [
        // Color swatch matches the stacked bar
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        AvatarWidget(
          name: participant.userName,
          imageUrl: participant.userAvatar,
          size: 28,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isYou ? '${participant.userName} (You)' : participant.userName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isYou ? FontWeight.w700 : FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textLight,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          secondaryLabel,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$currency${share.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
