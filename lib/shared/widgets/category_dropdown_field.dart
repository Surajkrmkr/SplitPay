import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/custom_category.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/settings_provider.dart';
import 'create_category_dialog.dart';
import 'empty_state.dart';

/// Tappable field showing the selected category; opens a bottom sheet list
/// (instead of a Wrap of chips, which floods the form once there are more
/// than a handful of categories) with an inline "add custom category" entry
/// point so the user never has to leave the transaction sheet to make one.
class CategoryDropdownField extends ConsumerWidget {
  final Category selectedCategory;
  final String? customCategoryId;
  final TransactionType type;
  final void Function(Category category, String? customCategoryId) onChanged;

  const CategoryDropdownField({
    super.key,
    required this.selectedCategory,
    required this.customCategoryId,
    required this.type,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customCats = ref.watch(customCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    CustomCategory? selectedCustom;
    if (customCategoryId != null) {
      for (final c in customCats) {
        if (c.id == customCategoryId) {
          selectedCustom = c;
          break;
        }
      }
    }
    final color = selectedCustom?.color ?? selectedCategory.color;
    final icon = selectedCustom?.icon ?? selectedCategory.icon;
    final label = selectedCustom?.label ?? selectedCategory.label;

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPickerSheet(
        selectedCategory: selectedCategory,
        customCategoryId: customCategoryId,
        type: type,
        onChanged: onChanged,
      ),
    );
  }
}

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  final Category selectedCategory;
  final String? customCategoryId;
  final TransactionType type;
  final void Function(Category category, String? customCategoryId) onChanged;

  const _CategoryPickerSheet({
    required this.selectedCategory,
    required this.customCategoryId,
    required this.type,
    required this.onChanged,
  });

  @override
  ConsumerState<_CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hidden = ref.watch(hiddenCategoriesProvider);
    final customCats = ref.watch(customCategoriesProvider);
    final isIncome = widget.type == TransactionType.income;
    final query = _query.trim().toLowerCase();

    // Always keep the currently-selected category selectable even if the
    // user has hidden it since — an existing pick shouldn't vanish.
    final builtIn = Category.values
        .where((c) =>
            !hidden.contains(c.name) ||
            (c == widget.selectedCategory && widget.customCategoryId == null))
        .where((c) => isIncome
            ? c == Category.salary || c == Category.other
            : c != Category.salary)
        .where((c) => query.isEmpty || c.label.toLowerCase().contains(query))
        .toList();

    final matchingCustomCats = isIncome
        ? const <CustomCategory>[]
        : customCats
            .where(
                (c) => query.isEmpty || c.label.toLowerCase().contains(query))
            .toList();

    final noResults = builtIn.isEmpty && matchingCustomCats.isEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) {
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
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Text(
                      'Select Category',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    if (!isIncome)
                      TextButton.icon(
                        onPressed: () => _createCustomCategory(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = '';
                            }),
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: noResults
                    ? const EmptyState(
                        icon: Icons.category_outlined,
                        title: 'No categories found',
                        subtitle: 'Try a different search term',
                      )
                    : ListView(
                        controller: scrollController,
                        padding: EdgeInsets.only(
                          bottom:
                              MediaQuery.of(context).viewPadding.bottom + 16,
                        ),
                        children: [
                          ...builtIn.map((cat) {
                            final selected = widget.customCategoryId == null &&
                                widget.selectedCategory == cat;
                            return _CategoryRow(
                              label: cat.label,
                              icon: cat.icon,
                              color: cat.color,
                              selected: selected,
                              isDark: isDark,
                              onTap: () {
                                widget.onChanged(cat, null);
                                Navigator.of(context).pop();
                              },
                            );
                          }),
                          ...matchingCustomCats.map((cat) {
                            final selected = widget.customCategoryId == cat.id;
                            return _CategoryRow(
                              label: cat.label,
                              icon: cat.icon,
                              color: cat.color,
                              selected: selected,
                              isDark: isDark,
                              onTap: () {
                                widget.onChanged(Category.other, cat.id);
                                Navigator.of(context).pop();
                              },
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createCustomCategory(BuildContext context) async {
    final created = await showDialog<CustomCategory>(
      context: context,
      builder: (_) => const CreateCategoryDialog(),
    );
    if (created == null) return;
    widget.onChanged(Category.other, created.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _CategoryRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isDark ? Colors.white : AppColors.textLight,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: color, size: 20)
          : null,
    );
  }
}
