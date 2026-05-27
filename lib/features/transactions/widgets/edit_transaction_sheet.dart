import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/category_app_icons.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../shared/widgets/app_icon_picker.dart';
import '../../../shared/widgets/sp_button.dart';

class EditTransactionSheet extends ConsumerStatefulWidget {
  final Transaction transaction;

  const EditTransactionSheet({super.key, required this.transaction});

  @override
  ConsumerState<EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late Category _category;
  String? _customCategoryId;
  String? _appIcon;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(2),
    );
    _noteController =
        TextEditingController(text: widget.transaction.note ?? '');
    _type = widget.transaction.type;
    _category = widget.transaction.category;
    _customCategoryId = widget.transaction.customCategoryId;
    _appIcon = widget.transaction.appIcon;
    _date = widget.transaction.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    try {
      await ref.read(transactionProvider.notifier).update(
            widget.transaction.copyWith(
              amount: amount,
              type: _type,
              category: _category,
              customCategoryId: _customCategoryId,
              appIcon: _appIcon,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              date: _date,
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.primary, onPrimary: Colors.white),
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.primary, onPrimary: Colors.white),
          timePickerTheme: TimePickerThemeData(
            dayPeriodColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : Colors.transparent),
            dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.primary),
            dayPeriodBorderSide: const BorderSide(
                color: AppColors.primary, width: 1),
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
    final visibleCategories = Category.values
        .where((c) => !hidden.contains(c.name) || (c == _category && _customCategoryId == null))
        .toList();
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      snap: true,
      snapSizes: const [0.75, 0.9],
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Edit Transaction',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Scrollable form
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  children: [
                    // Amount
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            currency,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          IntrinsicWidth(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              onChanged: (_) => setState(() {}),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.textLight,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Type toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: TransactionType.values.map((t) {
                          final selected = _type == t;
                          final color = t == TransactionType.income
                              ? AppColors.income
                              : AppColors.expense;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _type = t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.all(4),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? color.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: selected
                                      ? Border.all(color: color.withValues(alpha: 0.4))
                                      : null,
                                ),
                                child: Text(
                                  t == TransactionType.income ? 'Income' : 'Expense',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? color : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    _label('Category', isDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...visibleCategories.map((cat) {
                          final selected = _customCategoryId == null && _category == cat;
                          return _CategoryChip(
                            label: cat.label,
                            icon: cat.icon,
                            color: cat.color,
                            selected: selected,
                            isDark: isDark,
                            onTap: () => setState(() {
                              _category = cat;
                              _customCategoryId = null;
                              if (_appIcon != null &&
                                  !CategoryAppIcons.iconsFor(cat)
                                      .contains(_appIcon)) {
                                _appIcon = null;
                              }
                            }),
                          );
                        }),
                        ...customCats.map((cat) {
                          final selected = _customCategoryId == cat.id;
                          return _CategoryChip(
                            label: cat.label,
                            icon: cat.icon,
                            color: cat.color,
                            selected: selected,
                            isDark: isDark,
                            onTap: () => setState(() {
                              _category = Category.other;
                              _customCategoryId = cat.id;
                              _appIcon = null;
                            }),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (CategoryAppIcons.iconsFor(_category).isNotEmpty &&
                        _customCategoryId == null) ...[
                      AppIconPicker(
                        category: _category,
                        selected: _appIcon,
                        onSelected: (v) => setState(() => _appIcon = v),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Note
                    _label('Note', isDark),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textLight,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a note…',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                        filled: true,
                        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date & Time
                    _label('Date & Time', isDark),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DateTimeTile(
                            icon: Icons.calendar_today_rounded,
                            label: DateFormat('d MMM yyyy').format(_date),
                            isDark: isDark,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateTimeTile(
                            icon: Icons.access_time_rounded,
                            label: TimeOfDay.fromDateTime(_date).format(context),
                            isDark: isDark,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Fixed button — rises with keyboard
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  20, 12, 20,
                  (keyboardHeight > 0 ? keyboardHeight : safeAreaBottom) + 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.5,
                    ),
                  ),
                ),
                child: SpButton(
                  label: 'Save Changes',
                  onTap: _saving ? null : _save,
                  isLoading: _saving,
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textSecondary : AppColors.textLightSecondary,
          letterSpacing: 0.3,
        ),
      );
}

class _DateTimeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _DateTimeTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
