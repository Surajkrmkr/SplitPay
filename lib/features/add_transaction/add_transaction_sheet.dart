import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/category_app_icons.dart';
import '../../data/models/custom_category.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../shared/widgets/app_icon_picker.dart';
import '../../shared/widgets/bill_scan_button.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  Category _category = Category.food;
  String? _customCategoryId;
  String? _appIcon;
  DateTime _date = DateTime.now();
  RecurrenceType _recurrence = RecurrenceType.none;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyScannedBill(BillScanApplied scan) {
    setState(() {
      if (scan.amount != null) {
        _amountController.text = scan.amount!.toStringAsFixed(2);
      }
      // Add-transaction has no title field — drop the merchant name into the
      // note so it isn't lost. Only fill if note is currently empty.
      if (scan.title != null && _noteController.text.trim().isEmpty) {
        _noteController.text = scan.title!;
      }
      if (scan.dateTime != null) {
        _date = scan.dateTime!;
      }
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    try {
      await ref.read(transactionProvider.notifier).add(
            Transaction(
              id: const Uuid().v4(),
              amount: amount,
              type: _type,
              category: _category,
              customCategoryId: _customCategoryId,
              appIcon: _appIcon,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              date: _date,
              createdAt: DateTime.now(),
              recurrence: _recurrence,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        ));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
          timePickerTheme: TimePickerThemeData(
            dayPeriodColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : Colors.transparent),
            dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.primary),
            dayPeriodBorderSide:
                const BorderSide(color: AppColors.primary, width: 1),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _date = DateTime(
          _date.year,
          _date.month,
          _date.day,
          picked.hour,
          picked.minute,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final hidden = ref.watch(hiddenCategoriesProvider);
    final customCats = ref.watch(customCategoriesProvider);

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;

    final visibleBuiltIn =
        Category.values.where((c) => !hidden.contains(c.name)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      snap: true,
      snapSizes: const [0.75, 0.9],
      builder: (_, scrollController) {
        return Container(
          clipBehavior: Clip.hardEdge,
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

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Add Transaction',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    BillScanButton(
                      supportsTitle: false,
                      onApply: _applyScannedBill,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
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

              // Scrollable form
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  children: [
                    _TypeToggle(
                      selected: _type,
                      onChanged: (t) => setState(() {
                        _type = t;
                        _customCategoryId = null;
                        _appIcon = null;
                        _category = t == TransactionType.income
                            ? Category.salary
                            : Category.food;
                      }),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 20),
                    _AmountInput(
                      controller: _amountController,
                      currency: currency,
                      type: _type,
                    ).animate(delay: 50.ms).fadeIn().slideY(begin: 0.1),
                    const SizedBox(height: 16),
                    _sectionLabel(context, 'Category'),
                    const SizedBox(height: 10),
                    _CategoryPicker(
                      selected: _category,
                      customCategoryId: _customCategoryId,
                      type: _type,
                      visibleBuiltIn: visibleBuiltIn,
                      customCats: customCats,
                      onChanged: (cat, customId) => setState(() {
                        _category = cat;
                        _customCategoryId = customId;
                        // Clear the app icon if it's not relevant to the new
                        // category — keeps suggestions consistent with the
                        // user's pick.
                        if (_appIcon != null &&
                            !CategoryAppIcons.iconsFor(cat)
                                .contains(_appIcon)) {
                          _appIcon = null;
                        }
                      }),
                    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1),
                    const SizedBox(height: 16),
                    if (CategoryAppIcons.iconsFor(_category).isNotEmpty) ...[
                      AppIconPicker(
                        category: _category,
                        selected: _appIcon,
                        onSelected: (v) => setState(() => _appIcon = v),
                        isDark: isDark,
                      ).animate(delay: 130.ms).fadeIn().slideY(begin: 0.1),
                      const SizedBox(height: 16),
                    ],
                    _sectionLabel(context, 'Note (optional)'),
                    const SizedBox(height: 10),
                    _NoteInput(controller: _noteController)
                        .animate(delay: 150.ms)
                        .fadeIn()
                        .slideY(begin: 0.1),
                    const SizedBox(height: 16),
                    _sectionLabel(context, 'Date & Time'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DateSelector(
                            date: _date,
                            onTap: _pickDate,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeSelector(
                            date: _date,
                            onTap: _pickTime,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),
                    const SizedBox(height: 16),
                    _sectionLabel(context, 'Repeats'),
                    const SizedBox(height: 10),
                    _RecurrencePicker(
                      selected: _recurrence,
                      onChanged: (r) => setState(() => _recurrence = r),
                    ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.1),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Fixed button — rises with keyboard
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  (keyboardHeight > 0 ? keyboardHeight : safeAreaBottom) + 16,
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
                  type: _type,
                  onPressed: _save,
                ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.1),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColors.textSecondary),
      );
}

// ─── Type Toggle ──────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: TransactionType.values.map((type) {
          final isSelected = selected == type;
          final isExpense = type == TransactionType.expense;
          final color = isExpense ? AppColors.expense : AppColors.income;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(type);
              },
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: color.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isExpense
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: isSelected ? color : AppColors.textTertiary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isExpense ? 'Expense' : 'Income',
                      style: TextStyle(
                        color: isSelected ? color : AppColors.textTertiary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Amount Input ─────────────────────────────────────────────────────────────

class _AmountInput extends StatelessWidget {
  final TextEditingController controller;
  final String currency;
  final TransactionType type;

  const _AmountInput({
    required this.controller,
    required this.currency,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        type == TransactionType.expense ? AppColors.expense : AppColors.income;

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      autofocus: true,
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1,
      ),
      decoration: InputDecoration(
        prefixText: '$currency ',
        prefixStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.6),
        ),
        hintText: '0.00',
        hintStyle: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.textTertiary,
          letterSpacing: -1,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        filled: true,
        fillColor: color.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}

// ─── Category Picker ──────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  final Category selected;
  final String? customCategoryId;
  final TransactionType type;
  final List<Category> visibleBuiltIn;
  final List<CustomCategory> customCats;
  final void Function(Category cat, String? customId) onChanged;

  const _CategoryPicker({
    required this.selected,
    required this.customCategoryId,
    required this.type,
    required this.visibleBuiltIn,
    required this.customCats,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final builtInForType = type == TransactionType.income
        ? visibleBuiltIn
            .where((c) => c == Category.salary || c == Category.other)
            .toList()
        : visibleBuiltIn.where((c) => c != Category.salary).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...builtInForType.map((cat) {
          final isSelected = customCategoryId == null && selected == cat;
          final color = cat.color;
          return _Chip(
            label: cat.label,
            icon: cat.icon,
            color: color,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onChanged(cat, null),
          );
        }),
        ...customCats.map((cat) {
          final isSelected = customCategoryId == cat.id;
          return _Chip(
            label: cat.label,
            icon: cat.icon,
            color: cat.color,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onChanged(Category.other, cat.id),
          );
        }),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _Chip({
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
            Icon(icon,
                color: isSelected ? color : AppColors.textTertiary, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? color
                    : isDark
                        ? AppColors.textSecondary
                        : AppColors.textLightSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Note Input ───────────────────────────────────────────────────────────────

class _NoteInput extends StatelessWidget {
  final TextEditingController controller;
  const _NoteInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'What was this for?',
        prefixIcon: Icon(Icons.edit_note_rounded, size: 22),
      ),
    );
  }
}

// ─── Date Selector ────────────────────────────────────────────────────────────

class _DateSelector extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  final bool isDark;

  const _DateSelector({
    required this.date,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                DateFormat('d MMM yyyy').format(date),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  final bool isDark;

  const _TimeSelector({
    required this.date,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              TimeOfDay.fromDateTime(date).format(context),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Recurrence Picker ────────────────────────────────────────────────────────

class _RecurrencePicker extends StatelessWidget {
  final RecurrenceType selected;
  final ValueChanged<RecurrenceType> onChanged;

  const _RecurrencePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: RecurrenceType.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final type = RecurrenceType.values[i];
          final isSelected = type == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(type);
            },
            child: AnimatedContainer(
              duration: 180.ms,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark ? AppColors.darkCard : AppColors.lightCard),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: isSelected ? 1.2 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type.icon,
                    size: 14,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
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

// ─── Save Button ──────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool saving;
  final TransactionType type;
  final VoidCallback onPressed;

  const _SaveButton({
    required this.saving,
    required this.type,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = type == TransactionType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: 200.ms,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: saving ? null : onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isExpense
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isExpense ? 'Save Expense' : 'Save Income',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
