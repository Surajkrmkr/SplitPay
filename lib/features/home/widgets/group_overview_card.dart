import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';

class GroupOverviewCard extends ConsumerWidget {
  const GroupOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final groups = groupsAsync.valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final currency = ref.watch(currencyProvider);

    var totalOwed = 0.0;
    var totalLent = 0.0;
    var isLoading = groupsAsync.isLoading;
    var hasError = groupsAsync.hasError;

    for (final group in groups) {
      final balance = ref.watch(groupBalancesProvider(group.id));
      isLoading |= balance.isLoading;
      hasError |= balance.hasError;
      final value = balance.valueOrNull;
      if (value != null) {
        totalOwed += value.totalOwed;
        totalLent += value.totalLent;
      }
    }

    final net = totalLent - totalOwed;
    final netColor = net > 0.005
        ? AppColors.income
        : net < -0.005
            ? AppColors.expense
            : (isDark ? Colors.white : AppColors.textLight);
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? cardBg : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: isDark ? 0.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isDark ? 24 : 20,
            offset: Offset(0, isDark ? 12 : 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/groups'),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : hasError
                        ? _GroupOverviewError(
                            onRetry: () {
                              if (groupsAsync.hasError) {
                                ref.invalidate(groupsProvider);
                              }
                              for (final group in groups) {
                                ref.invalidate(
                                  groupBalancesProvider(group.id),
                                );
                              }
                            },
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Group Overview',
                                    style: TextStyle(
                                      color: isDark
                                          ? primary.withValues(alpha: 0.8)
                                          : AppColors.textLightSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${groups.length} ${groups.length == 1 ? 'group' : 'groups'}',
                                      style: TextStyle(
                                        color: primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                CurrencyFormatter.format(net, symbol: currency),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: netColor,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                net > 0.005
                                    ? 'You are owed overall'
                                    : net < -0.005
                                        ? 'You owe overall'
                                        : 'All group balances are settled',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                height: 0.5,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppColors.lightBorder,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _GroupBalanceMetric(
                                      label: 'You owe',
                                      value: totalOwed,
                                      currency: currency,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                  Container(
                                    width: 0.5,
                                    height: 40,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : AppColors.lightBorder,
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 20),
                                      child: _GroupBalanceMetric(
                                        label: "You're owed",
                                        value: totalLent,
                                        currency: currency,
                                        color: primary,
                                        alignRight: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupOverviewError extends StatelessWidget {
  const _GroupOverviewError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            "Couldn't load group balances.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _GroupBalanceMetric extends StatelessWidget {
  const _GroupBalanceMetric({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
    this.alignRight = false,
  });

  final String label;
  final double value;
  final String currency;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.format(value, symbol: currency),
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
