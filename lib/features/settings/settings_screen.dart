import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../debug/debug_log_screen.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/services/biometric_service.dart';
import '../../data/models/auth_user_model.dart';
import '../../core/services/update_service.dart';
import 'import_data_screen.dart';
import '../transactions/sms_import_screen.dart';
import '../../shared/utils/guest_guard.dart';

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
                        onTap: () => requireAuth(
                          context,
                          ref,
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ImportDataScreen(),
                            ),
                          ),
                        ),
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.upload_file_rounded,
                        iconColor: AppColors.secondary,
                        title: 'Export Data',
                        subtitle: 'Export last 2 months as CSV',
                        onTap: () => _exportData(context, ref),
                      ),
                      if (Platform.isAndroid) ...[
                        _Divider(),
                        _SettingsTile(
                          icon: Icons.sms_rounded,
                          iconColor: AppColors.primary,
                          title: 'Sync SMS Transactions',
                          subtitle:
                              'Auto-detect bank & UPI transactions from SMS',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SmsImportScreen(),
                            ),
                          ),
                        ),
                      ],
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
                        subtitle: ref.watch(appVersionProvider).valueOrNull ??
                            'Loading...',
                        onTap: null,
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.system_update_rounded,
                        iconColor: AppColors.secondary,
                        title: 'Check for Updates',
                        subtitle: 'Check for latest app updates',
                        onTap: () => UpdateService.instance.checkForUpdate(
                          context: context,
                          showNoUpdateToast: true,
                        ),
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.star_outline_rounded,
                        iconColor: AppColors.warning,
                        title: 'Rate SplitPay',
                        subtitle: 'Love the app? Leave a review',
                        onTap: () async {
                          final isIos =
                              Theme.of(context).platform == TargetPlatform.iOS;
                          final url = Uri.parse(
                            isIos
                                ? 'https://apps.apple.com/app/id6470000000'
                                : 'https://play.google.com/store/apps/details?id=com.splitpay.expensetracker',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                      _Divider(),
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: AppColors.secondary,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () async {
                          final url = Uri.parse(
                            'https://doc-hosting.flycricket.io/splitpay-privacy-policy/81c23815-2230-40e4-bc43-7d80f0625aee/privacy',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          }
                        },
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

Future<void> _exportData(BuildContext context, WidgetRef ref) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  try {
    final now = DateTime.now();
    final cutoffDate = DateTime(now.year, now.month - 2, now.day);
    final allTxs = ref.read(transactionProvider);

    final filteredTxs = allTxs
        .where((tx) => !tx.date.isBefore(cutoffDate))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (filteredTxs.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('No transactions found in the last 2 months.'),
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Date,Type,Category,Amount,Note,Recurrence');
    for (final tx in filteredTxs) {
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.date);
      final typeStr = tx.type.name;
      final catStr = tx.customCategoryId != null ? 'Custom' : tx.category.name;
      final amountStr = tx.amount.toStringAsFixed(2);
      final noteStr = '"${(tx.note ?? '').replaceAll('"', '""')}"';
      final recurrenceStr = tx.recurrence.name;
      buffer.writeln(
          '$dateStr,$typeStr,$catStr,$amountStr,$noteStr,$recurrenceStr');
    }

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/splitpay_export_${DateFormat('yyyyMMdd').format(now)}.csv';
    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'SplitPay Transactions Export (Last 2 Months)',
    );
  } catch (e) {
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Failed to export data: $e')),
    );
  }
}

void _showEditNameDialog(
    BuildContext context, WidgetRef ref, AuthUserModel user) {
  final nameParts = user.name.trim().split(RegExp(r'\s+'));
  final firstNameInitial = nameParts.isNotEmpty ? nameParts.first : '';
  final lastNameInitial =
      nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

  final firstNameController = TextEditingController(text: firstNameInitial);
  final lastNameController = TextEditingController(text: lastNameInitial);

  showDialog(
    context: context,
    builder: (ctx) {
      bool isSaving = false;
      return StatefulBuilder(
        builder: (ctx, setState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: const Text('Edit Profile Name',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: firstNameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      filled: true,
                      fillColor:
                          isDark ? AppColors.darkCard : AppColors.lightCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      filled: true,
                      fillColor:
                          isDark ? AppColors.darkCard : AppColors.lightCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        final fn = firstNameController.text.trim();
                        final ln = lastNameController.text.trim();
                        await ref.read(authProvider.notifier).updateProfile(
                              firstName: fn,
                              lastName: ln,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
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
    final authState = ref.watch(authProvider).valueOrNull;
    final isGuest = authState?.isGuest == true;
    final user = ref.watch(currentUserProvider);

    return GestureDetector(
      onTap: isGuest ? () => requireAuth(context, ref, () {}) : null,
      child: Container(
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
            if (isGuest)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              )
            else
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
                    isGuest ? 'Guest User' : (user?.name ?? 'User'),
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
                    isGuest
                        ? 'Tap to sign in & sync data'
                        : (user?.email ?? ''),
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
            if (isGuest) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else if (user != null) ...[
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: () => _showEditNameDialog(context, ref, user),
                tooltip: 'Edit Profile Name',
              ),
            ],
          ],
        ),
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
      subtitle: 'Customize, edit, and manage categories',
      onTap: () => requireAuth(
        context,
        ref,
        () => context.push('/settings/categories'),
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
    final bool comingSoon = subtitle.toLowerCase().contains('coming soon');

    final effectiveIconColor =
        comingSoon ? AppColors.textTertiary.withValues(alpha: 0.5) : iconColor;
    final effectiveBgColor = comingSoon
        ? AppColors.textTertiary.withValues(alpha: 0.08)
        : iconColor.withValues(alpha: 0.12);

    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: comingSoon
              ? (isDark
                  ? AppColors.textSecondary.withValues(alpha: 0.6)
                  : AppColors.textLightSecondary.withValues(alpha: 0.6))
              : null,
        );

    final subtitleStyle = TextStyle(
      color: comingSoon
          ? AppColors.textTertiary.withValues(alpha: 0.6)
          : (isDark ? AppColors.textSecondary : AppColors.textLightSecondary),
      fontSize: 12,
    );

    final Widget defaultTrailing = comingSoon
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.textTertiary.withValues(alpha: 0.15)
                  : AppColors.textTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Soon',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          )
        : (onTap != null
            ? const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 20,
              )
            : const SizedBox.shrink());

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
                  color: effectiveBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: titleStyle,
                    ),
                    Text(
                      subtitle,
                      style: subtitleStyle,
                    ),
                  ],
                ),
              ),
              trailing ?? defaultTrailing,
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
    final isGuest = ref.watch(authProvider).valueOrNull?.isGuest == true;

    if (isGuest) {
      return _SettingsTile(
        icon: Icons.login_rounded,
        iconColor: AppColors.primary,
        title: 'Sign In',
        subtitle: 'Sign in to sync your data and access all features',
        onTap: () => requireAuth(context, ref, () {}),
      );
    }

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
              'Made with ♥',
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
