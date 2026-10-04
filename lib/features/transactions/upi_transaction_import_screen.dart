import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/app_logger.dart';
import '../../data/models/group_model.dart';
import '../../data/models/member_model.dart';
import '../../data/services/upi_image_import_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/settings_provider.dart';
import '../../router/app_router.dart' show rootNavigatorKey;
import '../../shared/widgets/sp_button.dart';
import '../add_transaction/add_transaction_sheet.dart';
import '../groups/add_expense/add_expense_sheet.dart';

class SharedImageImportHandler extends StatefulWidget {
  final Widget child;

  const SharedImageImportHandler({super.key, required this.child});

  @override
  State<SharedImageImportHandler> createState() =>
      _SharedImageImportHandlerState();
}

class _SharedImageImportHandlerState extends State<SharedImageImportHandler>
    with WidgetsBindingObserver {
  final _service = UpiImageImportService();
  final _queuedPaths = <String>[];
  final _knownPaths = <String>{};
  StreamSubscription<SharedImageBatch>? _subscription;
  bool _processing = false;
  int _queuedOmittedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _service.sharedImages.listen(
      _queueImages,
      onError: (Object error) {
        AppLogger.instance.e(
          'Shared image event listener failed (${error.runtimeType}).',
          tag: 'UPI Import',
        );
        _showImportError();
      },
    );
    unawaited(_takePendingImages());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_takePendingImages());
  }

  Future<void> _takePendingImages() async {
    try {
      _queueImages(await _service.takePendingImages());
    } catch (error) {
      AppLogger.instance.e(
        'Pending shared image intake failed (${error.runtimeType}).',
        tag: 'UPI Import',
      );
      _showImportError();
    }
  }

  void _queueImages(SharedImageBatch batch) {
    var added = false;
    for (final path in batch.paths.take(UpiImageImportService.maxImages)) {
      if (_knownPaths.add(path)) {
        _queuedPaths.add(path);
        added = true;
      }
    }
    if (added) {
      _queuedOmittedCount += batch.omittedCount;
      AppLogger.instance.i(
        'Queued ${batch.paths.length} shared image(s) for review.',
        tag: 'UPI Import',
      );
    }
    unawaited(_processNext());
  }

  Future<void> _processNext() async {
    if (_processing || _queuedPaths.isEmpty || !mounted) return;
    _processing = true;
    final imagePath = _queuedPaths.removeAt(0);
    final omittedCount = _queuedOmittedCount;
    _queuedOmittedCount = 0;
    UpiTransactionDraft? draft;
    var imagesDeleted = false;
    try {
      AppLogger.instance.i('Processing next shared image.', tag: 'UPI Import');
      draft = await _service.readTransaction(imagePath);
      await _service.deleteImages([imagePath]);
      imagesDeleted = true;
      if (!mounted) return;
      AppLogger.instance.i(
        'Opening transaction review screen.',
        tag: 'UPI Import',
      );
      final navigator = rootNavigatorKey.currentState;
      if (navigator == null) {
        throw StateError('App root navigator is not ready.');
      }
      await navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => UpiTransactionImportScreen(
            draft: draft!,
            additionalImageCount: _queuedPaths.length,
            omittedImageCount: omittedCount,
          ),
        ),
      );
    } catch (error) {
      final failure = error is PlatformException
          ? 'platform code ${error.code}'
          : error.runtimeType.toString();
      AppLogger.instance.e(
        'Shared image processing failed ($failure).',
        tag: 'UPI Import',
      );
      if (mounted) _showImportError();
    } finally {
      try {
        if (!imagesDeleted) await _service.deleteImages([imagePath]);
      } catch (error) {
        AppLogger.instance.e(
          'Shared image cleanup retry failed (${error.runtimeType}).',
          tag: 'UPI Import',
        );
        if (mounted) _showImportError();
      }
      _knownPaths.remove(imagePath);
      _processing = false;
      unawaited(_processNext());
    }
  }

  void _showImportError() {
    AppLogger.instance.w(
      'Showing a shared image import error to the user.',
      tag: 'UPI Import',
    );
    _showMessage('Could not read the shared image. Please try another image.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_service.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class UpiTransactionImportScreen extends ConsumerStatefulWidget {
  final UpiTransactionDraft draft;
  final int additionalImageCount;
  final int omittedImageCount;

  const UpiTransactionImportScreen({
    super.key,
    required this.draft,
    this.additionalImageCount = 0,
    this.omittedImageCount = 0,
  });

  @override
  ConsumerState<UpiTransactionImportScreen> createState() =>
      _UpiTransactionImportScreenState();
}

class _UpiTransactionImportScreenState
    extends ConsumerState<UpiTransactionImportScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _referenceController;
  final _amountFocusNode = FocusNode();
  late DateTime _dateTime;
  GroupModel? _selectedGroup;
  int _destinationIndex = 0;
  bool _openingExpense = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.draft.amount?.toStringAsFixed(2) ?? '',
    );
    _merchantController =
        TextEditingController(text: widget.draft.merchant ?? '');
    _referenceController =
        TextEditingController(text: widget.draft.reference ?? '');
    _dateTime = widget.draft.dateTime ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    _merchantController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _dateTime.isAfter(now) ? now : _dateTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _openExpenseForm() async {
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '').trim());
    final merchant = _merchantController.text.trim();
    if (amount == null || amount <= 0 || merchant.isEmpty) {
      _showMessage('Enter a valid amount and merchant name to continue.');
      return;
    }
    if (_destinationIndex == 1 && _selectedGroup == null) {
      _showMessage('Create or select a group to add a group expense.');
      return;
    }

    setState(() => _openingExpense = true);
    AppLogger.instance.i(
      'Opening prefilled ${_destinationIndex == 0 ? 'personal' : 'group'} expense form.',
      tag: 'UPI Import',
    );
    final reference = _referenceController.text.trim();
    final notes = reference.isEmpty ? null : 'UPI Ref: $reference';
    final category = categoryForMerchant(merchant);
    try {
      final created = await showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _destinationIndex == 0
            ? AddTransactionSheet(
                initialAmount: amount,
                initialNote: [
                  merchant,
                  if (reference.isNotEmpty) 'UPI Ref: $reference',
                ].join(' · '),
                initialDateTime: _dateTime,
                initialCategory: category,
              )
            : AddExpenseSheet(
                group: _selectedGroup!,
                initialAmount: amount,
                initialTitle: merchant,
                initialNotes: notes,
                initialDateTime: _dateTime,
                initialCategory: category,
              ),
      );
      if (created == true && mounted) {
        AppLogger.instance
            .i('Expense saved from imported transaction.', tag: 'UPI Import');
        Navigator.of(context).pop();
      } else {
        AppLogger.instance.d(
          'Expense form closed without saving.',
          tag: 'UPI Import',
        );
      }
    } catch (error) {
      AppLogger.instance.e(
        'Could not open expense form (${error.runtimeType}).',
        tag: 'UPI Import',
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _openingExpense = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final groups = (groupsAsync.valueOrNull ?? const <GroupModel>[])
        .where((group) => group.members.isNotEmpty)
        .toList();
    if (_selectedGroup == null && groups.isNotEmpty) {
      _selectedGroup = groups.first;
    }
    final userId = ref.watch(currentUserProvider)?.id;
    final payer = _selectedGroup?.members
        .where((member) => member.userId == userId)
        .firstOrNull;
    final participants = _selectedGroup?.members ?? const <MemberModel>[];
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Transaction'),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (widget.additionalImageCount > 0) ...[
              _notice(
                'The first image is ready. The other '
                '${widget.additionalImageCount} shared image(s) will be '
                'reviewed next.',
              ),
              const SizedBox(height: 12),
            ],
            if (widget.omittedImageCount > 0) ...[
              _notice(
                '${widget.omittedImageCount} additional image(s) were not '
                'copied. Share up to ${UpiImageImportService.maxImages} '
                'images at a time.',
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Review detected details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            AmountDisplay(
              controller: _amountController,
              focusNode: _amountFocusNode,
              currency: currency,
              isDark: isDark,
              autofocus: false,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _fieldLabel('Merchant'),
            const SizedBox(height: 8),
            _input(
              controller: _merchantController,
              hint: 'What was this for?',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Date & Time'),
            const SizedBox(height: 8),
            _dateButton(),
            const SizedBox(height: 16),
            _fieldLabel('UPI reference (optional)'),
            const SizedBox(height: 8),
            _input(
              controller: _referenceController,
              hint: 'Transaction reference',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Personal')),
                ButtonSegment(value: 1, label: Text('Group')),
              ],
              selected: {_destinationIndex},
              onSelectionChanged: (selection) =>
                  setState(() => _destinationIndex = selection.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: primary.withValues(alpha: 0.16),
                selectedForegroundColor: primary,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                side: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(height: 16),
            if (_destinationIndex == 1)
              _groupSection(
                groups: groups,
                payerName: payer?.name ?? 'You',
                participants: participants,
                amount: amount,
              )
            else
              _sectionCard(
                context: context,
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This transaction will be added to your personal expenses.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            SpButton(
              label: 'Add Expense',
              onTap: _openingExpense ? null : _openExpenseForm,
              isLoading: _openingExpense,
              icon: Icons.add_circle_outline_rounded,
            ),
            const SizedBox(height: 10),
            Text(
              'You can edit every value again before saving.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupSection({
    required List<GroupModel> groups,
    required String payerName,
    required List<MemberModel> participants,
    required double amount,
  }) {
    final theme = Theme.of(context);
    if (groups.isEmpty) {
      return _sectionCard(
        context: context,
        child: const Text(
          'You have no groups yet. Create a group before adding a group expense.',
        ),
      );
    }
    return _sectionCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Group'),
          const SizedBox(height: 8),
          DropdownButtonFormField<GroupModel>(
            initialValue: _selectedGroup,
            decoration: const InputDecoration(hintText: 'Select a group'),
            items: groups
                .map((group) => DropdownMenuItem(
                      value: group,
                      child: Text(group.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (group) => setState(() => _selectedGroup = group),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Paid by'),
          const SizedBox(height: 6),
          Text(payerName, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          _fieldLabel('Equal split'),
          const SizedBox(height: 8),
          for (final member in participants)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          Text(member.name, overflow: TextOverflow.ellipsis)),
                  Text(
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                      decimalDigits: 2,
                    ).format(participants.isEmpty
                        ? 0
                        : amount / participants.length),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (participants.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Members and split type can be changed in the expense form.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateButton() => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickDateTime,
        child: InputDecorator(
          decoration: const InputDecoration(
            suffixIcon: Icon(Icons.calendar_today_rounded),
          ),
          child: Text(
            DateFormat('dd MMM yyyy, hh:mm a').format(_dateTime),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        inputFormatters: hint == 'Transaction reference'
            ? [LengthLimitingTextInputFormatter(40)]
            : null,
        decoration: InputDecoration(
          hintText: hint,
        ),
      );

  Widget _fieldLabel(String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
      );

  Widget _sectionCard({required BuildContext context, required Widget child}) =>
      Card(
        color: Theme.of(context).cardTheme.color,
        shape: Theme.of(context).cardTheme.shape,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      );

  Widget _notice(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
      );
}
