import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/subscription_service.dart';
import '../../shared/widgets/app_back_button.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);
    final controller = ref.read(subscriptionProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 12),
                    Text(
                      'SplitPay Pro',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withValues(alpha: 0.18),
                        AppColors.secondary.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: primary.withValues(alpha: 0.24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.workspace_premium_rounded,
                          color: primary, size: 34),
                      const SizedBox(height: 12),
                      Text(
                        state.isPremium
                            ? 'SplitPay Pro is active'
                            : 'Your finances, with more power',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textLight,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Subscribe to unlock premium features as they arrive. '
                        'Manage or cancel your plan anytime through your app store.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!state.isStoreAvailable)
              SliverToBoxAdapter(
                child: _MessageCard(
                  message: state.error ??
                      'Subscriptions are unavailable. Please try again later.',
                  actionLabel: 'Try again',
                  onAction: controller.loadStoreProducts,
                ),
              )
            else if (state.products.isEmpty)
              SliverToBoxAdapter(
                child: _MessageCard(
                  message: state.notFoundProductIds.isNotEmpty
                      ? 'Subscription products are not available yet. '
                          'Create these IDs in App Store Connect and Google Play '
                          'Console: ${state.notFoundProductIds.join(', ')}.'
                      : state.error ??
                          'No subscription plans are available right now.',
                  actionLabel: 'Refresh',
                  onAction: controller.loadStoreProducts,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverList.separated(
                  itemCount: state.products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = state.products[index];
                    final isActive = state.activeProductId == product.id;
                    final isYearly = product.id == SubscriptionProducts.yearly;
                    return _PlanCard(
                      product: product,
                      isYearly: isYearly,
                      isActive: isActive,
                      isPremium: state.isPremium,
                      isPurchasing: state.isPurchasing,
                      isDark: isDark,
                      onPurchase: () => controller.purchase(product),
                    );
                  },
                ),
              ),
            if (state.notFoundProductIds.isNotEmpty &&
                state.products.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    'Unavailable product IDs: '
                    '${state.notFoundProductIds.join(', ')}. '
                    'Check their setup in the app stores.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            if (state.error != null && state.isStoreAvailable)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    state.error!,
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                child: Column(
                  children: [
                    TextButton.icon(
                      onPressed: state.isRestoring
                          ? null
                          : controller.restorePurchases,
                      icon: state.isRestoring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore_rounded),
                      label: const Text('Restore purchases'),
                    ),
                    if (state.isPremium)
                      TextButton.icon(
                        onPressed: () => _manageSubscriptions(context),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Manage subscription'),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Subscriptions are billed and managed by Apple or Google. '
                      'Prices and renewal terms are shown by the store before purchase.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _manageSubscriptions(BuildContext context) async {
  final uri = Uri.parse(
    Platform.isIOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions'
            '?package=com.splitpay.expensetracker',
  );
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open subscription settings.')),
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open subscription settings: $error')),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.isYearly,
    required this.isActive,
    required this.isPremium,
    required this.isPurchasing,
    required this.isDark,
    required this.onPurchase,
  });

  final ProductDetails product;
  final bool isYearly;
  final bool isActive;
  final bool isPremium;
  final bool isPurchasing;
  final bool isDark;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardTheme.color ?? AppColors.darkCard;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppColors.income
              : isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
          width: isActive ? 1.5 : 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isYearly ? 'Yearly' : 'Monthly',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      const _PlanBadge(
                          label: 'ACTIVE', color: AppColors.income),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  product.price,
                  style: TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'per ${isYearly ? 'year' : 'month'}, auto-renews',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  'Cancel anytime in your app store account',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: isPremium || isPurchasing ? null : onPurchase,
            child: isPurchasing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(isActive
                    ? 'Active'
                    : isPremium
                        ? 'Owned'
                        : 'Continue'),
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.label,
    this.color = const Color(0xFF00D09C),
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
