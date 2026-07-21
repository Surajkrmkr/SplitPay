import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../debug/debug_log_screen.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/services/biometric_service.dart';
import '../../data/models/custom_category.dart';
import '../../data/models/transaction_model.dart';
import '../../shared/widgets/create_category_dialog.dart';
import 'import_data_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _Header(),
                  const SizedBox(height: 24),
                  _ProfileCard(isDark: isDark),
                  const SizedBox(height: 24),
                  _SectionLabel(label: 'Preferences'),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    children: [
                      _ThemeTile(isDark: isDark, ref: ref),
                      _Divider(),
                      _CurrencyTile(currency: currency, ref: ref),
                      _Divider(),
                      _CategoriesTile(ref: ref),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(label: 'Notifications'),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    children: [
                      _NotificationsTile(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(label: 'Security'),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    children: [
                      _BiometricTile(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(label: 'Data'),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    children: [
                      _SettingsTile(
                        icon: Icons.file_download_rounded,
                        iconColor: AppColors.secondary,
                        title: 'Import Data',
                        subtitle: 'Import expenses from a CSV file',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ImportDataScreen(),
                          ),
                        ),
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.upload_file_rounded,
                        iconColor: AppColors.secondary,
                        title: 'Export Data',
                        subtitle: 'Export as CSV (coming soon)',
                        onTap: () => _showComingSoon(context),
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.backup_rounded,
                        iconColor: AppColors.warning,
                        title: 'Backup',
                        subtitle: 'Cloud backup (coming soon)',
                        onTap: () => _showComingSoon(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(label: 'About'),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppColors.primary,
                        title: 'App Version',
                        subtitle: '1.0.0 (MVP)',
                        onTap: null,
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.star_outline_rounded,
                        iconColor: AppColors.warning,
                        title: 'Rate SplitPay',
                        subtitle: 'Love the app? Leave a review',
                        onTap: () => _showComingSoon(context),
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: AppColors.secondary,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () => _showComingSoon(context),
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.share_rounded,
                        iconColor: AppColors.primary,
                        title: 'Share SplitPay',
                        subtitle: 'Invite friends to track expenses together',
                        onTap: () => Share.share(
                          'Check out SplitPay — the smart expense tracker for individuals and groups! 💸\nhttps://play.google.com/store/apps/details?id=com.splitpay.expensetracker',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(label: 'Account'),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    children: [
                      _LogoutTile(ref: ref),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _AppBadge(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Coming soon!'),
      duration: Duration(seconds: 2),
    ),
  );
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Profile',
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _ProfileCard extends ConsumerWidget {
  final bool isDark;

  const _ProfileCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: isDark ? 0.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isDark ? 24 : 16,
            offset: Offset(0, isDark ? 12 : 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          ClipOval(
            child: user?.avatar != null
                ? Image.network(
                    user!.avatar!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _InitialsAvatar(name: user.name),
                  )
                : _InitialsAvatar(name: user?.name ?? '?'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'User',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.8)
                        : AppColors.textLightSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1);
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Container(
      width: 60,
      height: 60,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(children: children),
    ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.1);
  }
}

class _ThemeTile extends StatelessWidget {
  final bool isDark;
  final WidgetRef ref;

  const _ThemeTile({required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
      iconColor: isDark ? AppColors.secondary : AppColors.warning,
      title: 'Appearance',
      subtitle: isDark ? 'Dark mode' : 'Light mode',
      trailing: Switch(
        value: isDark,
        onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
        activeThumbColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
      ),
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  final String currency;
  final WidgetRef ref;

  const _CurrencyTile({required this.currency, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.attach_money_rounded,
      iconColor: AppColors.income,
      title: 'Currency',
      subtitle: _currencyLabel(currency),
      onTap: () => _showCurrencyPicker(context, ref),
    );
  }

  String _currencyLabel(String symbol) {
    final entry = CurrencyFormatter.currencies.entries.firstWhere(
        (e) => e.value == symbol,
        orElse: () => const MapEntry('USD', '\$'));
    return '${entry.key} ($symbol)';
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.attach_money_rounded,
                          color: AppColors.income, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Select Currency',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 0.5,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                  ),
                  children: CurrencyFormatter.currencies.entries.map((e) {
                    final isSelected = currency == e.value;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : (isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3))
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.primary
                                  : isDark
                                      ? Colors.white
                                      : AppColors.textLight,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        e.key,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.primary : null,
                          fontSize: 15,
                        ),
                      ),
                      trailing: isSelected
                          ? Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: AppColors.primary, size: 16),
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(currencyProvider.notifier)
                            .setCurrency(e.value);
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoriesTile extends StatelessWidget {
  final WidgetRef ref;
  const _CategoriesTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.category_rounded,
      iconColor: AppColors.secondary,
      title: 'Manage Categories',
      subtitle: 'Show or hide expense categories',
      onTap: () => _showCategoryManager(context),
    );
  }

  void _showCategoryManager(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => _CategoryManagerSheet(
            isDark: isDark, scrollController: scrollController),
      ),
    );
  }
}

class _CategoryManagerSheet extends ConsumerWidget {
  final bool isDark;
  final ScrollController scrollController;

  const _CategoryManagerSheet({
    required this.isDark,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hiddenCategoriesProvider);
    final customCats = ref.watch(customCategoriesProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.category_rounded,
                      color: AppColors.secondary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Categories',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Toggle visibility · create or delete custom ones',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 20),
                  ),
                  onPressed: () => _showCreateDialog(context, ref),
                ),
              ],
            ),
          ),
          Container(
            height: 0.5,
            margin: const EdgeInsets.only(top: 8),
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom + 16,
              ),
              children: [
                // Built-in categories (toggle visibility)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                  child: Text(
                    'BUILT-IN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                ...Category.values.map((cat) {
                  final isVisible = !hidden.contains(cat.name);
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cat.color
                            .withValues(alpha: isVisible ? 0.15 : 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cat.icon,
                          color: isVisible ? cat.color : AppColors.textTertiary,
                          size: 20),
                    ),
                    title: Text(
                      cat.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isVisible
                            ? (isDark ? Colors.white : AppColors.textLight)
                            : AppColors.textTertiary,
                      ),
                    ),
                    trailing: cat == Category.other
                        ? Icon(Icons.lock_outline_rounded,
                            color: AppColors.textTertiary, size: 18)
                        : Switch(
                            value: isVisible,
                            onChanged: (_) => ref
                                .read(hiddenCategoriesProvider.notifier)
                                .toggle(cat),
                            activeThumbColor: cat.color,
                            activeTrackColor: cat.color.withValues(alpha: 0.35),
                          ),
                  );
                }),

                // Custom categories (create / delete)
                if (customCats.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                    child: Text(
                      'CUSTOM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  ...customCats.map((cat) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 2),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 20),
                        ),
                        title: Text(
                          cat.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isDark ? Colors.white : AppColors.textLight,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline_rounded,
                              color: AppColors.expense, size: 20),
                          onPressed: () => _confirmDelete(context, ref, cat),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => const CreateCategoryDialog(),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CustomCategory cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Delete "${cat.label}"? This won\'t affect existing transactions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(customCategoriesProvider.notifier).remove(cat.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textLightSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  (onTap != null
                      ? Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                          size: 20,
                        )
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool _busy = false;

  Future<void> _toggle(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (enabled) {
        final available = await BiometricService.instance.isAvailable();
        if (!available) {
          _showSnackBar('Biometrics not available on this device');
          return;
        }
        final result = await BiometricService.instance.authenticate(
          reason: 'Verify your identity to enable biometric lock',
        );
        switch (result) {
          case BiometricResult.success:
            break;
          case BiometricResult.cancelled:
            _showSnackBar('Authentication cancelled');
            return;
          case BiometricResult.notEnrolled:
            _showSnackBar(
                'No biometrics enrolled. Set up fingerprint or Face ID in device settings.');
            return;
          case BiometricResult.notAvailable:
            _showSnackBar('Biometrics not available on this device');
            return;
          case BiometricResult.lockedOut:
            _showSnackBar(
                'Too many attempts. Use your PIN to unlock the device first.');
            return;
          case BiometricResult.failed:
            _showSnackBar('Authentication failed. Please try again.');
            return;
        }
      }
      await ref.read(biometricLockProvider.notifier).setEnabled(enabled);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(biometricLockProvider);
    return _SettingsTile(
      icon: Icons.fingerprint_rounded,
      iconColor: AppColors.primary,
      title: 'Biometric Lock',
      subtitle: enabled ? 'Unlock app with biometrics' : 'Disabled',
      trailing: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: enabled,
              onChanged: _toggle,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
      onTap: () => _toggle(!enabled),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final WidgetRef ref;
  const _LogoutTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.logout_rounded,
      iconColor: AppColors.expense,
      title: 'Sign Out',
      subtitle: 'Sign out of your account',
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.expense),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(authProvider.notifier).signOut();
        }
      },
    );
  }
}

// ── Notifications nav tile ────────────────────────────────────────────────────

class _NotificationsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.notifications_active_rounded,
      iconColor: AppColors.income,
      title: 'Reminders',
      subtitle: 'Daily reminders and recurring alerts (coming soon)',
      onTap: () => _showComingSoon(context),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 68),
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }
}

class _AppBadge extends StatefulWidget {
  @override
  State<_AppBadge> createState() => _AppBadgeState();
}

class _AppBadgeState extends State<_AppBadge> {
  bool _glowing = false;

  Future<void> _onDoubleTap() async {
    setState(() => _glowing = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _glowing = false);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DebugLogScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onDoubleTap: _onDoubleTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: _glowing
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.55),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: AnimatedScale(
                scale: _glowing ? 0.88 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 56,
                    height: 56,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'SplitPay',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Made with ♥ · v1.0.0',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 400.ms).fadeIn().scale(curve: Curves.elasticOut);
  }
}
