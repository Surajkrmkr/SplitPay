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
import '../../../shared/widgets/category_dropdown_field.dart';
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
  Category? _category;
  String? _customCategoryId;
  String? _appIcon;
  late DateTime _date;
  late RecurrenceType _recurrence;
  bool _saving = false;

  bool get _isValid {
    final amount = double.tryParse(_amountController.text.trim());
    return amount != null &&
        amount > 0 &&
        (_category != null || _customCategoryId != null);
  }

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
    _recurrence = widget.transaction.recurrence;
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
    if (_category == null && _customCategoryId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(transactionProvider.notifier).update(
            widget.transaction.copyWith(
              amount: amount,
              type: _type,
              category: _category ?? Category.other,
              customCategoryId: _customCategoryId,
              appIcon: _appIcon,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              date: _date,
              recurrence: _recurrence,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
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

  Future<void> _pickDateTime() async {
    await _pickDate();
    if (!mounted) return;
    await _pickTime();
  }

  void _showRecurrencePicker() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurrencePickerSheet(
        selected: _recurrence,
        onChanged: (r) => setState(() => _recurrence = r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    // Hug content height instead of always claiming the full screen — with
    // the keyboard closed there's often a lot of empty middle space. Capped
    // at 92% of screen height as a safety net for small devices / long
    // content.
    //
    // showModalBottomSheet doesn't reposition for the keyboard on its own —
    // padding the *outside* of the sheet by the keyboard height is what
    // actually shifts it up to clear the keyboard; the maxHeight budget is
    // shrunk by the same amount so the whole thing still fits on screen.
    //
    // Only the middle (amount/note/app-icon) section scrolls — wrapping the
    // date/category/save row in the same scroll view let it get pushed below
    // the fold (and out of sight) whenever the middle content grew taller
    // than the available space. Flexible (not Expanded) lets the middle
    // shrink-to-fit when there's room, so the sheet still hugs short content
    // instead of always maxing out its height budget.
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92 - bottomInset,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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

                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.close_rounded,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Center(
                          child: _TypeToggle(
                            selected: _type,
                            onChanged: (t) => setState(() {
                              if (_type == t) return;
                              _type = t;
                              _customCategoryId = null;
                              _appIcon = null;
                              _category = null;
                            }),
                          ),
                        ),
                      ),
                      _CircleIconButton(
                        icon: Icons.repeat_rounded,
                        isDark: isDark,
                        active: _recurrence != RecurrenceType.none,
                        onTap: _showRecurrencePicker,
                      ),
                    ],
                  ),
                ),

                // Amount, note, app icon suggestions — the only scrollable part
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        _AmountInput(
                          controller: _amountController,
                          currency: currency,
                          type: _type,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),
                        _NotePill(controller: _noteController),
                        if (_category != null &&
                            CategoryAppIcons.iconsFor(_category).isNotEmpty &&
                            _customCategoryId == null) ...[
                          const SizedBox(height: 20),
                          AppIconPicker(
                            category: _category!,
                            selected: _appIcon,
                            onSelected: (v) => setState(() => _appIcon = v),
                            isDark: isDark,
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Date/time + category, and save — always fully visible
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    MediaQuery.of(context).viewPadding.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DateTimeField(
                              date: _date,
                              isDark: isDark,
                              onTap: _pickDateTime,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CategoryDropdownField(
                              selectedCategory: _category,
                              customCategoryId: _customCategoryId,
                              type: _type,
                              onChanged: (cat, customId) => setState(() {
                                _category = cat;
                                _customCategoryId = customId;
                                if (_appIcon != null &&
                                    !CategoryAppIcons.iconsFor(cat)
                                        .contains(_appIcon)) {
                                  _appIcon = null;
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SpButton(
                        label: 'Save Changes',
                        onTap: (_saving || !_isValid) ? null : _save,
                        isLoading: _saving,
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TransactionType.values.map((type) {
          final isSelected = selected == type;
          final isExpense = type == TransactionType.expense;
          final color = isExpense ? AppColors.expense : AppColors.income;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: color.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                isExpense ? 'Expense' : 'Income',
                style: TextStyle(
                  color: isSelected ? color : AppColors.textTertiary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
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
  final ValueChanged<String>? onChanged;

  const _AmountInput({
    required this.controller,
    required this.currency,
    required this.type,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        type == TransactionType.expense ? AppColors.expense : AppColors.income;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            currency,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              LengthLimitingTextInputFormatter(20),
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -1,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppColors.textTertiary,
                letterSpacing: -1,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Note Pill ────────────────────────────────────────────────────────────────

class _NotePill extends StatelessWidget {
  final TextEditingController controller;
  const _NotePill({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: TextField(
        controller: controller,
        inputFormatters: [LengthLimitingTextInputFormatter(20)],
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Add Note',
          icon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.notes_rounded,
                size: 16, color: AppColors.textSecondary),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ─── Date & Time field ────────────────────────────────────────────────────────

class _DateTimeField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  final bool isDark;

  const _DateTimeField({
    required this.date,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final dateLabel = isToday
        ? 'Today, ${DateFormat('d MMM').format(date)}'
        : DateFormat('d MMM yyyy').format(date);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            Icon(Icons.calendar_today_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    TimeOfDay.fromDateTime(date).format(context),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Circle Icon Button ───────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool active;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(12),
          border: active
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: active ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Recurrence Picker Sheet ──────────────────────────────────────────────────

class _RecurrencePickerSheet extends StatelessWidget {
  final RecurrenceType selected;
  final ValueChanged<RecurrenceType> onChanged;

  const _RecurrencePickerSheet({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repeat',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RecurrenceType.values.map((type) {
              final isSelected = type == selected;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(type);
                  Navigator.of(context).pop();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : (isDark ? AppColors.darkCard : AppColors.lightCard),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                      width: isSelected ? 1.2 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type.icon,
                        size: 15,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 13,
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
            }).toList(),
          ),
        ],
      ),
    );
  }
}
