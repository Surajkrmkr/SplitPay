import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/group_model.dart';
import '../../../data/models/member_model.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/bill_scan_button.dart';
import '../../../shared/widgets/sp_button.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  final GroupModel group;

  const AddExpenseSheet({super.key, required this.group});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  late TabController _splitTabController;

  String _splitType = 'EQUAL';
  late String _paidById;
  late String _currentUserId;
  late List<String> _selectedParticipantIds;
  DateTime _selectedDate = DateTime.now();

  // For percentage split: map userId -> %
  final Map<String, TextEditingController> _percentControllers = {};
  // For exact split: map userId -> amount
  final Map<String, TextEditingController> _exactControllers = {};

  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _splitTabController = TabController(length: 3, vsync: this);
    _splitTabController.addListener(() {
      setState(() {
        _splitType =
            ['EQUAL', 'PERCENTAGE', 'EXACT'][_splitTabController.index];
      });
    });

    // Fix #5: default paidBy to the currently logged-in user
    _currentUserId = ref.read(currentUserProvider)?.id ?? '';
    final selfMember = widget.group.members
        .where((m) => m.userId == _currentUserId)
        .firstOrNull;
    _paidById = selfMember?.userId ?? widget.group.members.first.userId;

    _selectedParticipantIds =
        widget.group.members.map((m) => m.userId).toList();

    for (final m in widget.group.members) {
      _percentControllers[m.userId] = TextEditingController();
      _exactControllers[m.userId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _splitTabController.dispose();
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;

  double get _equalShare {
    final count = _selectedParticipantIds.length;
    if (count == 0) return 0;
    return _totalAmount / count;
  }

  double get _percentSum {
    return _selectedParticipantIds.fold(0.0, (sum, id) {
      return sum + (double.tryParse(_percentControllers[id]?.text ?? '') ?? 0);
    });
  }

  double get _exactSum {
    return _selectedParticipantIds.fold(0.0, (sum, id) {
      return sum + (double.tryParse(_exactControllers[id]?.text ?? '') ?? 0);
    });
  }

  bool get _isValid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_totalAmount <= 0) return false;
    if (_selectedParticipantIds.isEmpty) return false;
    if (_splitType == 'PERCENTAGE') {
      return (_percentSum - 100).abs() < 0.01;
    }
    if (_splitType == 'EXACT') {
      return (_exactSum - _totalAmount).abs() < 0.01;
    }
    return true;
  }

  List<Map<String, dynamic>> _buildParticipants() {
    return _selectedParticipantIds.map((uid) {
      final member = widget.group.members.firstWhere((m) => m.userId == uid);
      double share;
      double? percentage;
      if (_splitType == 'EQUAL') {
        share = _equalShare;
      } else if (_splitType == 'PERCENTAGE') {
        percentage = double.tryParse(_percentControllers[uid]?.text ?? '') ?? 0;
        share = _totalAmount * percentage / 100;
      } else {
        share = double.tryParse(_exactControllers[uid]?.text ?? '') ?? 0;
      }
      return {
        'userId': uid,
        'userName': member.name,
        'userAvatar': member.avatar,
        'share': share,
        if (percentage != null) 'percentage': percentage,
      };
    }).toList();
  }

  void _applyScannedBill(BillScanApplied scan) {
    setState(() {
      if (scan.amount != null) {
        _amountController.text = scan.amount!.toStringAsFixed(2);
      }
      if (scan.title != null && _titleController.text.trim().isEmpty) {
        _titleController.text = scan.title!;
      }
      if (scan.dateTime != null) {
        _selectedDate = scan.dateTime!;
      }
    });
  }

  Future<void> _addExpense() async {
    if (!_isValid) return;
    setState(() => _creating = true);
    try {
      await ref.read(groupApiServiceProvider).createExpense(
            groupId: widget.group.id,
            title: _titleController.text.trim(),
            amount: _totalAmount,
            paidById: _paidById,
            splitType: _splitType,
            participants: _buildParticipants(),
            notes: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            date: _selectedDate.toUtc().toIso8601String(),
          );
      ref.invalidate(groupExpensesProvider(widget.group.id));
      ref.invalidate(groupBalancesProvider(widget.group.id));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense added!'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.6,
      builder: (context, scrollController) {
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
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Add Expense',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const Spacer(),
                    BillScanButton(onApply: _applyScannedBill),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Amount — large display (tap anywhere to focus)
                    AmountDisplay(
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      isDark: isDark,
                      currency: currency,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    _label('Title *', isDark),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _titleController,
                      hint: 'What was this for?',
                      isDark: isDark,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Date & Time
                    _label('Date & Time', isDark),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerTile(
                            selectedDate: _selectedDate,
                            isDark: isDark,
                            onChanged: (d) => setState(() => _selectedDate = d),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimePickerTile(
                            selectedDate: _selectedDate,
                            isDark: isDark,
                            onChanged: (d) => setState(() => _selectedDate = d),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Paid by
                    _label('Paid by', isDark),
                    const SizedBox(height: 8),
                    PaidByDropdown(
                      members: widget.group.members,
                      selectedUserId: _paidById,
                      currentUserId: _currentUserId,
                      isDark: isDark,
                      onChanged: (id) => setState(() => _paidById = id),
                    ),
                    const SizedBox(height: 20),

                    // Split type
                    _label('Split Type', isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _splitTabController,
                        tabs: const [
                          Tab(text: 'Equal'),
                          Tab(text: 'Percentage'),
                          Tab(text: 'Exact'),
                        ],
                        indicator: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        dividerColor: Colors.transparent,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Participants
                    _label('Participants', isDark),
                    const SizedBox(height: 8),
                    ...widget.group.members.map(
                      (m) => ParticipantRow(
                        member: m,
                        isSelected: _selectedParticipantIds.contains(m.userId),
                        splitType: _splitType,
                        equalShare: _equalShare,
                        percentController: _percentControllers[m.userId]!,
                        exactController: _exactControllers[m.userId]!,
                        isDark: isDark,
                        currency: currency,
                        onToggle: (val) {
                          setState(() {
                            if (val) {
                              _selectedParticipantIds.add(m.userId);
                            } else {
                              _selectedParticipantIds.remove(m.userId);
                            }
                          });
                        },
                        onChanged: () => setState(() {}),
                      ),
                    ),

                    // Validation hints
                    if (_splitType == 'PERCENTAGE' &&
                        _selectedParticipantIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Total: ${_percentSum.toStringAsFixed(1)}% ${(_percentSum - 100).abs() < 0.01 ? '✓' : '(must equal 100%)'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_percentSum - 100).abs() < 0.01
                                ? AppColors.income
                                : AppColors.expense,
                          ),
                        ),
                      ),
                    if (_splitType == 'EXACT' &&
                        _selectedParticipantIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Total: $currency${_exactSum.toStringAsFixed(0)} of $currency${_totalAmount.toStringAsFixed(0)} ${(_exactSum - _totalAmount).abs() < 0.01 ? '✓' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_exactSum - _totalAmount).abs() < 0.01
                                ? AppColors.income
                                : AppColors.expense,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Note
                    _label('Note (optional)', isDark),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _noteController,
                      hint: 'Add a note…',
                      isDark: isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // Bottom bar
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(context).viewPadding.bottom +
                      MediaQuery.of(context).viewInsets.bottom +
                      16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: SpButton(
                  label: 'Add Expense',
                  onTap: _isValid && !_creating ? _addExpense : null,
                  isLoading: _creating,
                  icon: Icons.add_circle_outline_rounded,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textSecondary : AppColors.textLightSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      inputFormatters: [LengthLimitingTextInputFormatter(50)],
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(
        color: isDark ? Colors.white : AppColors.textLight,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class AmountDisplay extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isDark;
  final String currency;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  const AmountDisplay({
    super.key,
    required this.controller,
    this.focusNode,
    required this.isDark,
    required this.currency,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: focusNode != null
          ? () => FocusScope.of(context).requestFocus(focusNode)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          children: [
            Text(
              'Total Amount',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
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
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: autofocus,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(50),
                      CurrencyInputFormatter(),
                    ],
                    onChanged: onChanged,
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
          ],
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime selectedDate;
  final bool isDark;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerTile({
    required this.selectedDate,
    required this.isDark,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    // Preserve the time-of-day component when only the date changes.
    onChanged(DateTime(
      picked.year,
      picked.month,
      picked.day,
      selectedDate.hour,
      selectedDate.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormat('yyyyMMdd').format(selectedDate) ==
        DateFormat('yyyyMMdd').format(DateTime.now());
    final label =
        isToday ? 'Today' : DateFormat('d MMM yyyy').format(selectedDate);

    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final DateTime selectedDate;
  final bool isDark;
  final ValueChanged<DateTime> onChanged;

  const _TimePickerTile({
    required this.selectedDate,
    required this.isDark,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
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
    onChanged(DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      picked.hour,
      picked.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                TimeOfDay.fromDateTime(selectedDate).format(context),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class PaidByDropdown extends StatelessWidget {
  final List<MemberModel> members;
  final String selectedUserId;
  final String currentUserId;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const PaidByDropdown({
    super.key,
    required this.members,
    required this.selectedUserId,
    this.currentUserId = '',
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedUserId,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkCard : Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          items: members.map((m) {
            final isYou = m.userId == currentUserId;
            return DropdownMenuItem(
              value: m.userId,
              child: Row(
                children: [
                  AvatarWidget(name: m.name, imageUrl: m.avatar, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    isYou ? '${m.name} (You)' : m.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isYou ? FontWeight.w600 : FontWeight.w400,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class ParticipantRow extends StatelessWidget {
  final MemberModel member;
  final bool isSelected;
  final String splitType;
  final double equalShare;
  final TextEditingController percentController;
  final TextEditingController exactController;
  final bool isDark;
  final String currency;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;

  const ParticipantRow({
    super.key,
    required this.member,
    required this.isSelected,
    required this.splitType,
    required this.equalShare,
    required this.percentController,
    required this.exactController,
    required this.isDark,
    required this.currency,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (v) => onToggle(v ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          AvatarWidget(name: member.name, imageUrl: member.avatar, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.name,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isSelected) ...[
            if (splitType == 'EQUAL')
              Text(
                '$currency${equalShare.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              )
            else if (splitType == 'PERCENTAGE')
              SizedBox(
                width: 72,
                height: 36,
                child: TextField(
                  controller: percentController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(50),
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textLight,
                  ),
                  decoration: InputDecoration(
                    suffixText: '%',
                    suffixStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    isDense: true,
                  ),
                ),
              )
            else if (splitType == 'EXACT')
              SizedBox(
                width: 80,
                height: 36,
                child: TextField(
                  controller: exactController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(50),
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textLight,
                  ),
                  decoration: InputDecoration(
                    prefixText: currency,
                    prefixStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
