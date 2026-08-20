import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/category_app_icons.dart';
import '../../data/models/custom_category.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/settings_provider.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/create_category_dialog.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  void _openCreateCategorySheet(BuildContext context,
      {CustomCategory? categoryToEdit}) {
    showCreateCategoryBottomSheet(
      context,
      categoryToEdit: categoryToEdit,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CustomCategory cat) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Delete "${cat.label}"? Existing transactions will remain unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(customCategoriesProvider.notifier).remove(cat.id);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customCategories = ref.watch(customCategoriesProvider);
    final hiddenCategories = ref.watch(hiddenCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Page Header matching SplitPay Navigation Style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 14),
                  Text(
                    'Manage Categories',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  // Top App Bar Action Button for New Category
                  GestureDetector(
                    onTap: () => _openCreateCategorySheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Scrollable Category Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  // Section Header: Custom Categories
                  Text(
                    'CUSTOM CATEGORIES (${customCategories.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (customCategories.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 32,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No custom categories created',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "+" at the top to create your first category with suggested apps.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: customCategories.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.30,
                      ),
                      itemBuilder: (context, index) {
                        final cat = customCategories[index];
                        return _CustomCategoryGridTile(
                          cat: cat,
                          isDark: isDark,
                          onEdit: () => _openCreateCategorySheet(
                            context,
                            categoryToEdit: cat,
                          ),
                          onDelete: () => _confirmDelete(context, ref, cat),
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  // Section Header: Default System Categories
                  const Text(
                    'SYSTEM CATEGORIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: Category.values.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.30,
                    ),
                    itemBuilder: (context, index) {
                      final sysCat = Category.values[index];
                      final isHidden = hiddenCategories.contains(sysCat.name);
                      final builtInApps = CategoryAppIcons.iconsFor(sysCat);

                      return _SystemCategoryGridTile(
                        sysCat: sysCat,
                        isHidden: isHidden,
                        builtInApps: builtInApps,
                        isDark: isDark,
                        onToggle: () {
                          ref
                              .read(hiddenCategoriesProvider.notifier)
                              .toggle(sysCat);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomCategoryGridTile extends StatelessWidget {
  final CustomCategory cat;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomCategoryGridTile({
    required this.cat,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? cardBg : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.6,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.expense,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (cat.suggestedApps.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: cat.suggestedApps.map((fileName) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          CategoryAppIcons.pathFor(fileName),
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.apps_rounded,
                            size: 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              Text(
                'No apps linked',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SystemCategoryGridTile extends StatelessWidget {
  final Category sysCat;
  final bool isHidden;
  final List<String> builtInApps;
  final bool isDark;
  final VoidCallback onToggle;

  const _SystemCategoryGridTile({
    required this.sysCat,
    required this.isHidden,
    required this.builtInApps,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? cardBg : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.6,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: sysCat.color.withValues(alpha: isHidden ? 0.08 : 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sysCat.icon,
                    color: isHidden ? AppColors.textSecondary : sysCat.color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sysCat.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isHidden
                          ? AppColors.textSecondary
                          : (isDark ? Colors.white : AppColors.textLight),
                      decoration: isHidden ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IgnorePointer(
                  child: SizedBox(
                    height: 24,
                    width: 36,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch.adaptive(
                        value: !isHidden,
                        activeTrackColor: primary,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (builtInApps.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: builtInApps.take(5).map((fileName) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          CategoryAppIcons.pathFor(fileName),
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.apps_rounded,
                            size: 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              Text(
                'No default apps',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
