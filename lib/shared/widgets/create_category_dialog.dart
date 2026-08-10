import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/category_app_icons.dart';
import '../../data/models/custom_category.dart';
import '../../providers/settings_provider.dart';

/// Opens the category bottom sheet for creating or editing a [CustomCategory].
Future<CustomCategory?> showCreateCategoryBottomSheet(
  BuildContext context, {
  CustomCategory? categoryToEdit,
}) {
  final topPadding = MediaQuery.paddingOf(context).top;
  final maxHeight = (MediaQuery.sizeOf(context).height - topPadding) * 0.9;
  return showModalBottomSheet<CustomCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (_) => CreateCategoryBottomSheet(categoryToEdit: categoryToEdit),
  );
}

class CreateCategoryBottomSheet extends ConsumerStatefulWidget {
  final CustomCategory? categoryToEdit;

  const CreateCategoryBottomSheet({super.key, this.categoryToEdit});

  @override
  ConsumerState<CreateCategoryBottomSheet> createState() =>
      _CreateCategoryBottomSheetState();
}

class _CreateCategoryBottomSheetState
    extends ConsumerState<CreateCategoryBottomSheet> {
  late final TextEditingController _nameController;
  late int _selectedIcon;
  late int _selectedColor;
  late List<String> _selectedApps;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cat = widget.categoryToEdit;
    _nameController = TextEditingController(text: cat?.label ?? '');
    _selectedIcon = cat?.iconIndex ?? 0;
    _selectedColor = cat?.colorIndex ?? 0;
    _selectedApps = List.from(cat?.suggestedApps ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.categoryToEdit != null) {
        final updated = widget.categoryToEdit!.copyWith(
          label: name,
          iconIndex: _selectedIcon,
          colorIndex: _selectedColor,
          suggestedApps: _selectedApps,
        );
        await ref.read(customCategoriesProvider.notifier).update(updated);
        if (mounted) Navigator.pop(context, updated);
      } else {
        final created =
            await ref.read(customCategoriesProvider.notifier).createAndAdd(
                  CustomCategory(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    label: name,
                    iconIndex: _selectedIcon,
                    colorIndex: _selectedColor,
                    suggestedApps: _selectedApps,
                  ),
                );
        if (mounted) Navigator.pop(context, created);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.categoryToEdit != null
              ? "Couldn't update category — try again"
              : "Couldn't create category — try again";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = (MediaQuery.sizeOf(context).height - topPadding) * 0.9;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.categoryToEdit != null
                    ? 'Edit Category'
                    : 'New Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable Content Inputs
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Field
                  TextField(
                    controller: _nameController,
                    inputFormatters: [LengthLimitingTextInputFormatter(50)],
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Category name (e.g. Subscriptions)',
                      filled: true,
                      fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Color Selector
                  Text(
                    'COLOR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        CustomCategory.colors.length,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedColor = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: CustomCategory.colors[i],
                                shape: BoxShape.circle,
                                border: _selectedColor == i
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: _selectedColor == i
                                    ? [
                                        BoxShadow(
                                          color: CustomCategory.colors[i]
                                              .withValues(alpha: 0.5),
                                          blurRadius: 10,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Horizontal Scrolling Icon Selector
                  Text(
                    'ICON',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        CustomCategory.icons.length,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedIcon = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _selectedIcon == i
                                    ? CustomCategory.colors[_selectedColor]
                                        .withValues(alpha: 0.2)
                                    : (isDark
                                        ? AppColors.darkCard
                                        : AppColors.lightCard),
                                borderRadius: BorderRadius.circular(12),
                                border: _selectedIcon == i
                                    ? Border.all(
                                        color: CustomCategory.colors[_selectedColor],
                                        width: 1.8,
                                      )
                                    : Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                      ),
                              ),
                              child: Icon(
                                CustomCategory.icons[i],
                                size: 20,
                                color: _selectedIcon == i
                                    ? CustomCategory.colors[_selectedColor]
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Suggested Apps Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SUGGESTED APPS (${_selectedApps.length} SELECTED)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (_selectedApps.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _selectedApps.clear()),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2-line Horizontal Grid for Suggested Apps with Checked/Unchecked UI
                  SizedBox(
                    height: 130,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: CategoryAppIcons.allAvailableAppIcons.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        final fileName =
                            CategoryAppIcons.allAvailableAppIcons[index];
                        final isSelected = _selectedApps.contains(fileName);
                        final displayName = fileName.replaceAll('.png', '');

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedApps.remove(fileName);
                              } else {
                                _selectedApps.add(fileName);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : (isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                                width: isSelected ? 1.8 : 0.8,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        CategoryAppIcons.pathFor(fileName),
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.apps_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(1.5),
                                          child: const Icon(
                                            Icons.check,
                                            size: 8,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white
                                            : AppColors.textLight),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                          color: AppColors.expense, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Pinned Bottom Save Button (ALWAYS Visible!)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.categoryToEdit != null
                          ? 'Save Category'
                          : 'Create Category',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
