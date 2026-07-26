import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/custom_category.dart';
import '../../providers/settings_provider.dart';

/// Dialog for creating a custom category — name, color, icon. Pops with the
/// server-assigned [CustomCategory] on success (null on cancel), so callers
/// that need to act on the new category (e.g. auto-select it) can await it.
class CreateCategoryDialog extends ConsumerStatefulWidget {
  const CreateCategoryDialog({super.key});

  @override
  ConsumerState<CreateCategoryDialog> createState() =>
      _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends ConsumerState<CreateCategoryDialog> {
  final _nameController = TextEditingController();
  int _selectedIcon = 0;
  int _selectedColor = 0;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created =
          await ref.read(customCategoriesProvider.notifier).createAndAdd(
                CustomCategory(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  label: name,
                  iconIndex: _selectedIcon,
                  colorIndex: _selectedColor,
                ),
              );
      if (mounted) Navigator.pop(context, created);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't create category — try again";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: const Text('New Category',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Category name',
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Text('Color',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                CustomCategory.colors.length,
                (i) => GestureDetector(
                  onTap: () => setState(() => _selectedColor = i),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: CustomCategory.colors[i],
                      shape: BoxShape.circle,
                      border: _selectedColor == i
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                      boxShadow: _selectedColor == i
                          ? [
                              BoxShadow(
                                  color: CustomCategory.colors[i]
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Icon',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                CustomCategory.icons.length,
                (i) => GestureDetector(
                  onTap: () => setState(() => _selectedIcon = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _selectedIcon == i
                          ? CustomCategory.colors[_selectedColor]
                              .withValues(alpha: 0.2)
                          : (isDark ? AppColors.darkCard : AppColors.lightCard),
                      borderRadius: BorderRadius.circular(10),
                      border: _selectedIcon == i
                          ? Border.all(
                              color: CustomCategory.colors[_selectedColor]
                                  .withValues(alpha: 0.6))
                          : null,
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: AppColors.expense, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
