import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/group_expense_model.dart';
import '../../../data/models/group_model.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/sp_button.dart';
import 'add_expense_sheet.dart';

class EditExpenseSheet extends ConsumerStatefulWidget {
  final GroupExpenseModel expense;
  final GroupModel group;

  const EditExpenseSheet({super.key, required this.expense, required this.group});

  @override
  ConsumerState<EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends ConsumerState<EditExpenseSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  late TabController _splitTabController;

  late String _splitType;
  late String _paidById;
  late List<String> _selectedParticipantIds;

  final Map<String, TextEditingController> _percentControllers = {};
  final Map<String, TextEditingController> _exactControllers = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(text: widget.expense.amount.toStringAsFixed(2));
    _titleController = TextEditingController(text: widget.expense.title);
    _noteController = TextEditingController(text: widget.expense.notes ?? '');
    _splitType = widget.expense.splitType;
    _paidById = widget.expense.paidById;
    _selectedParticipantIds = widget.expense.participants.map((p) => p.userId).toList();

    final initialIndex = ['EQUAL', 'PERCENTAGE', 'EXACT'].indexOf(_splitType);
    _splitTabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
    _splitTabController.addListener(() {
      setState(() {
        _splitType = ['EQUAL', 'PERCENTAGE', 'EXACT'][_splitTabController.index];
      });
    });

    for (final m in widget.group.members) {
      final participant = widget.expense.participants
          .where((p) => p.userId == m.userId)
          .firstOrNull;
      _percentControllers[m.userId] = TextEditingController(
        text: participant?.percentage != null
            ? participant!.percentage!.toStringAsFixed(1)
            : '',
      );
      _exactControllers[m.userId] = TextEditingController(
        text: participant != null && _splitType == 'EXACT'
            ? participant.share.toStringAsFixed(2)
            : '',
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _splitTabController.dispose();
    for (final c in _percentControllers.values) { c.dispose(); }
    for (final c in _exactControllers.values) { c.dispose(); }
    super.dispose();
  }

  double get _totalAmount => double.tryParse(_amountController.text.trim()) ?? 0;

  double get _equalShare {
    final count = _selectedParticipantIds.length;
    if (count == 0) return 0;
    return _totalAmount / count;
  }

  double get _percentSum => _selectedParticipantIds.fold(0.0, (sum, id) {
        return sum + (double.tryParse(_percentControllers[id]?.text ?? '') ?? 0);
      });

  double get _exactSum => _selectedParticipantIds.fold(0.0, (sum, id) {
        return sum + (double.tryParse(_exactControllers[id]?.text ?? '') ?? 0);
      });

  bool get _isValid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_totalAmount <= 0) return false;
    if (_selectedParticipantIds.isEmpty) return false;
    if (_splitType == 'PERCENTAGE') return (_percentSum - 100).abs() < 0.01;
    if (_splitType == 'EXACT') return (_exactSum - _totalAmount).abs() < 0.01;
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

  Future<void> _saveChanges() async {
    if (!_isValid) return;
    setState(() => _saving = true);
    try {
      await ref.read(groupApiServiceProvider).updateExpense(
            widget.expense.id,
            title: _titleController.text.trim(),
            amount: _totalAmount,
            paidById: _paidById,
            splitType: _splitType,
            participants: _buildParticipants(),
            notes: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );
      ref.invalidate(groupExpensesProvider(widget.expense.groupId));
      ref.invalidate(groupBalancesProvider(widget.expense.groupId));
      ref.invalidate(groupActivityProvider(widget.expense.groupId));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Expense updated!'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.expense,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Edit Expense',
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
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    AmountDisplay(
                      controller: _amountController,
                      isDark: isDark,
                      currency: currency,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    _label('Title *', isDark),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _titleController,
                      hint: 'What was this for?',
                      isDark: isDark,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _label('Paid by', isDark),
                    const SizedBox(height: 8),
                    PaidByDropdown(
                      members: widget.group.members,
                      selectedUserId: _paidById,
                      isDark: isDark,
                      onChanged: (id) => setState(() => _paidById = id),
                    ),
                    const SizedBox(height: 20),
                    _label('Split Type', isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
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
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        dividerColor: Colors.transparent,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    if (_splitType == 'PERCENTAGE' && _selectedParticipantIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Total: ${_percentSum.toStringAsFixed(1)}% ${(_percentSum - 100).abs() < 0.01 ? '✓' : '(must equal 100%)'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_percentSum - 100).abs() < 0.01 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ),
                    if (_splitType == 'EXACT' && _selectedParticipantIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Total: $currency${_exactSum.toStringAsFixed(0)} of $currency${_totalAmount.toStringAsFixed(0)} ${(_exactSum - _totalAmount).abs() < 0.01 ? '✓' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_exactSum - _totalAmount).abs() < 0.01 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
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
                    top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                child: SpButton(
                  label: 'Save Changes',
                  onTap: _isValid && !_saving ? _saveChanges : null,
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
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textLight, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
