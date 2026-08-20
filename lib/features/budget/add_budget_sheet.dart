import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';

class AddBudgetSheet extends ConsumerStatefulWidget {
  /// Pass an existing budget ID to switch to edit mode.
  final String? editBudgetId;

  const AddBudgetSheet({super.key, this.editBudgetId});

  @override
  ConsumerState<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<AddBudgetSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  BudgetPeriod _period = BudgetPeriod.monthly;
  final Set<String> _selectedCategoryIds = {};
  double _alertThreshold = 0.8;
  int _colorValue = kBudgetColors[0].toARGB32();
  int _iconCodePoint = kBudgetIcons[0].codePoint;
  bool _saving = false;

  bool get _isEdit => widget.editBudgetId != null;

  bool get _isValid {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    return _titleController.text.trim().isNotEmpty &&
        amount != null &&
        amount > 0 &&
        _selectedCategoryIds.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    if (!_isEdit) return;
    final budget = ref
        .read(budgetProvider)
        .cast<Budget?>()
        .firstWhere((b) => b?.id == widget.editBudgetId, orElse: () => null);
    if (budget == null) return;
    setState(() {
      _titleController.text = budget.title;
      _amountController.text = budget.amount.toStringAsFixed(0);
      _period = budget.period;
      _selectedCategoryIds
        ..clear()
        ..addAll(budget.categoryIds);
      _alertThreshold = budget.alertThreshold;
      _colorValue = budget.colorValue;
      _iconCodePoint = budget.iconCodePoint;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isValid) return;
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''))!;

    setState(() => _saving = true);
    try {
      final notifier = ref.read(budgetProvider.notifier);
      final now = DateTime.now();

      if (_isEdit) {
        final existing = ref
            .read(budgetProvider)
            .firstWhere((b) => b.id == widget.editBudgetId!);
        await notifier.update(existing.copyWith(
          title: title,
          amount: amount,
          categoryIds: _selectedCategoryIds.toList(),
          period: _period,
          colorValue: _colorValue,
          iconCodePoint: _iconCodePoint,
          alertThreshold: _alertThreshold,
          updatedAt: now,
        ));
      } else {
        await notifier.add(Budget(
          id: const Uuid().v4(),
          title: title,
          amount: amount,
          categoryIds: _selectedCategoryIds.toList(),
          period: _period,
          startDate: now,
          colorValue: _colorValue,
          iconCodePoint: _iconCodePoint,
          isArchived: false,
          alertThreshold: _alertThreshold,
          createdAt: now,
          updatedAt: now,
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleCategory(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedCategoryIds.contains(id)) {
        _selectedCategoryIds.remove(id);
      } else {
        _selectedCategoryIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customCats = ref.watch(customCategoriesProvider);
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.92,
      minChildSize: 0.6,
      expand: false,
      snap: true,
      snapSizes: const [0.75, 0.92],
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      _isEdit ? 'Edit Budget' : 'New Budget',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Scrollable form body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  children: [
                    // Title
                    _Label('Budget Name'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Monthly Food Budget',
                        prefixIcon: Icon(Icons.label_rounded, size: 20),
                      ),
                    ).animate(delay: 50.ms).fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 16),

                    // Amount
                    _Label('Budget Amount'),
                    const SizedBox(height: 8),
                    _AmountField(
                      controller: _amountController,
                      currency: ref.watch(currencyProvider),
                      onChanged: (_) => setState(() {}),
                    ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 16),

                    // Period
                    _Label('Budget Period'),
                    const SizedBox(height: 8),
                    _PeriodSelector(
                      selected: _period,
                      onChanged: (p) => setState(() => _period = p),
                      isDark: isDark,
                    ).animate(delay: 110.ms).fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 16),

                    // Categories
                    _Label('Categories *'),
                    const SizedBox(height: 8),
                    _CategoryPicker(
                      selectedIds: _selectedCategoryIds,
                      customCats: customCats,
                      isDark: isDark,
                      onToggle: _toggleCategory,
                    ).animate(delay: 140.ms).fadeIn().slideY(begin: 0.1),
                    if (_selectedCategoryIds.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Select at least one category',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.expense,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Color
                    _Label('Color'),
                    const SizedBox(height: 8),
                    _ColorPicker(
                      selectedValue: _colorValue,
                      onChanged: (v) => setState(() => _colorValue = v),
                    ).animate(delay: 170.ms).fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 16),

                    // Icon
                    _Label('Icon'),
                    const SizedBox(height: 8),
                    _IconPicker(
                      selectedCodePoint: _iconCodePoint,
                      color: Color(_colorValue),
                      isDark: isDark,
                      onChanged: (cp) => setState(() => _iconCodePoint = cp),
                    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 16),

                    // Alert threshold
                    _Label(
                        'Alert when ${(_alertThreshold * 100).toStringAsFixed(0)}% spent'),
                    Slider(
                      value: _alertThreshold,
                      min: 0.5,
                      max: 0.95,
                      divisions: 9,
                      activeColor: Color(_colorValue),
                      inactiveColor: Color(_colorValue).withValues(alpha: 0.15),
                      onChanged: (v) => setState(() => _alertThreshold = v),
                    ).animate(delay: 220.ms).fadeIn(),

                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Fixed save button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  (keyboardH > 0 ? keyboardH : safeAreaBottom) + 16,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  border: Border(
                    top: BorderSide(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.5,
                    ),
                  ),
                ),
                child: _SaveButton(
                  saving: _saving,
                  enabled: _isValid,
                  isEdit: _isEdit,
                  color: Color(_colorValue),
                  onPressed: _save,
                ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.1),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Label ────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColors.textSecondary),
      );
}

// ─── Amount field ─────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String currency;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  const _AmountField({
    required this.controller,
    required this.currency,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        LengthLimitingTextInputFormatter(50),
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -1,
      ),
      decoration: InputDecoration(
        prefixText: '$currency ',
        prefixStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        hintText: '0',
        hintStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textTertiary,
          letterSpacing: -1,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        filled: true,
        fillColor: primary.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ─── Period selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final BudgetPeriod selected;
  final ValueChanged<BudgetPeriod> onChanged;
  final bool isDark;

  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? cardBg : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: BudgetPeriod.values.map((p) {
          final isSelected = selected == p;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(p);
              },
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: primary.withValues(alpha: 0.4))
                      : null,
                ),
                child: Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? primary : AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Category multi-picker ────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  final Set<String> selectedIds;
  final List<dynamic> customCats;
  final bool isDark;
  final ValueChanged<String> onToggle;

  const _CategoryPicker({
    required this.selectedIds,
    required this.customCats,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Only show expense-relevant categories
    final builtIn = Category.values.where((c) => c != Category.salary).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...builtIn.map((cat) {
          final isSelected = selectedIds.contains(cat.name);
          return _CategoryChip(
            label: cat.label,
            icon: cat.icon,
            color: cat.color,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onToggle(cat.name),
          );
        }),
        ...customCats.map((cat) {
          final isSelected = selectedIds.contains(cat.id);
          return _CategoryChip(
            label: cat.label,
            icon: cat.icon,
            color: cat.color,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onToggle(cat.id),
          );
        }),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 13)
            else
              Icon(icon, color: AppColors.textTertiary, size: 13),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? color
                    : isDark
                        ? AppColors.textSecondary
                        : AppColors.textLightSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Color picker ──────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  final int selectedValue;
  final ValueChanged<int> onChanged;

  const _ColorPicker({required this.selectedValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kBudgetColors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final color = kBudgetColors[i];
          final isSelected = color.toARGB32() == selectedValue;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(color.toARGB32());
            },
            child: AnimatedContainer(
              duration: 200.ms,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ─── Icon picker ──────────────────────────────────────────────────────────────

class _IconPicker extends StatelessWidget {
  final int selectedCodePoint;
  final Color color;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _IconPicker({
    required this.selectedCodePoint,
    required this.color,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kBudgetIcons.map((icon) {
        final isSelected = icon.codePoint == selectedCodePoint;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(icon.codePoint);
          },
          child: AnimatedContainer(
            duration: 200.ms,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : isDark
                      ? AppColors.darkCard
                      : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.5)
                    : isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? color : AppColors.textTertiary,
              size: 22,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Save button ──────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool saving;
  final bool enabled;
  final bool isEdit;
  final Color color;
  final VoidCallback onPressed;

  const _SaveButton({
    required this.saving,
    required this.enabled,
    required this.isEdit,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final canSubmit = enabled && !saving;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: 200.ms,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: canSubmit
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Opacity(
          opacity: canSubmit ? 1 : 0.4,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canSubmit ? onPressed : null,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        isEdit ? 'Update Budget' : 'Create Budget',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
