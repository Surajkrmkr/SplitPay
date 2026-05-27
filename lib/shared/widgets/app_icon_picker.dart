import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/category_app_icons.dart';
import '../../data/models/transaction_model.dart';

/// Horizontal carousel of brand-icon suggestions for the given [category].
///
/// - Hidden entirely when the category has no suggested icons (keeps the form
///   clean for Salary/Bills/Other).
/// - Tap an icon to select it; tap the selected icon again to clear.
/// - The selected value is the asset filename (e.g. `Swiggy.png`), which is
///   what's persisted on the transaction / expense.
class AppIconPicker extends StatelessWidget {
  final Category category;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final bool isDark;

  const AppIconPicker({
    super.key,
    required this.category,
    required this.selected,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final icons = CategoryAppIcons.iconsFor(category);
    if (icons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Suggested apps',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textLightSecondary,
                letterSpacing: 0.3,
              ),
            ),
            if (selected != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onSelected(null),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: icons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final fileName = icons[i];
              final isSelected = selected == fileName;
              return _IconTile(
                fileName: fileName,
                selected: isSelected,
                isDark: isDark,
                onTap: () =>
                    onSelected(isSelected ? null : fileName),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Compact category chip row used by group-expense sheets to narrow which
/// icons [AppIconPicker] suggests. The category itself isn't persisted on the
/// expense — it just filters the suggestions.
class IconCategoryFilter extends StatelessWidget {
  final Category selected;
  final bool isDark;
  final ValueChanged<Category> onChanged;
  final List<Category> categories;

  const IconCategoryFilter({
    super.key,
    required this.selected,
    required this.isDark,
    required this.onChanged,
    this.categories = const [
      Category.food,
      Category.shopping,
      Category.travel,
      Category.entertainment,
      Category.subscription,
      Category.health,
    ],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.color.withValues(alpha: 0.15)
                    : (isDark
                        ? AppColors.darkCard
                        : AppColors.lightCard),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? cat.color
                      : (isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                  width: isSelected ? 1.2 : 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon,
                      size: 12,
                      color: isSelected
                          ? cat.color
                          : AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? cat.color
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final String fileName;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _IconTile({
    required this.fileName,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  String get _label {
    // Strip the .png extension for the label. Don't rename — the asset path
    // still uses the original filename.
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                  width: selected ? 2 : 0.8,
                ),
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
              ),
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  CategoryAppIcons.pathFor(fileName),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
