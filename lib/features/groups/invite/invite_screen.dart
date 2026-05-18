import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/group_provider.dart';
import '../../../shared/widgets/sp_button.dart';

class InviteScreen extends ConsumerStatefulWidget {
  // null when opened from Groups screen (join-only mode)
  final String? groupId;
  const InviteScreen({super.key, this.groupId});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _generatedCode;
  DateTime? _expiresAt;
  bool _generating = false;

  final _codeController = TextEditingController();
  bool _joining = false;
  String? _joinPreview;
  bool _loadingPreview = false;

  bool get _joinOnly => widget.groupId == null;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: _joinOnly ? 1 : 2,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(InviteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.groupId == null) != (widget.groupId == null)) {
      _tabs.dispose();
      _tabs = TabController(length: _joinOnly ? 1 : 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // ── Generate ────────────────────────────────────────────────

  Future<void> _generateCode() async {
    setState(() => _generating = true);
    try {
      final result = await ref.read(groupApiServiceProvider).generateInvite(widget.groupId!);
      setState(() {
        _generatedCode = result['code'] as String?;
        final expiresStr = result['expiresAt'] as String?;
        _expiresAt = expiresStr != null ? DateTime.parse(expiresStr) : null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _copyCode() {
    if (_generatedCode == null) return;
    Clipboard.setData(ClipboardData(text: _generatedCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Code copied to clipboard'),
        backgroundColor: AppColors.income,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareCode() {
    if (_generatedCode == null) return;
    Clipboard.setData(ClipboardData(text: 'Join my SplitPay group with invite code: $_generatedCode'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Share text copied — paste it anywhere!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Join ────────────────────────────────────────────────────

  Future<void> _previewInvite(String code) async {
    if (code.length < 6) return;
    setState(() { _loadingPreview = true; _joinPreview = null; });
    try {
      final info = await ref.read(groupApiServiceProvider).getInviteInfo(code.trim().toUpperCase());
      if (mounted) {
        setState(() => _joinPreview = '${info['groupName']} · ${info['memberCount']} members · invited by ${info['invitedBy']}');
      }
    } catch (_) {
      if (mounted) setState(() => _joinPreview = null);
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _joinGroup() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _joining = true);
    try {
      final group = await ref.read(groupApiServiceProvider).joinViaInvite(code);
      ref.invalidate(groupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Joined "${group.name}" successfully!'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        title: Text(
          _joinOnly ? 'Join a Group' : 'Invite',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        bottom: _joinOnly
            ? null
            : TabBar(
                controller: _tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                tabs: const [Tab(text: 'Generate Code'), Tab(text: 'Join Group')],
              ),
      ),
      body: _joinOnly
          ? _JoinTab(
              isDark: isDark,
              controller: _codeController,
              preview: _joinPreview,
              loadingPreview: _loadingPreview,
              joining: _joining,
              onCodeChanged: _previewInvite,
              onJoin: _joinGroup,
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _GenerateTab(
                  isDark: isDark,
                  generatedCode: _generatedCode,
                  expiresAt: _expiresAt,
                  generating: _generating,
                  onGenerate: _generateCode,
                  onCopy: _copyCode,
                  onShare: _shareCode,
                ),
                _JoinTab(
                  isDark: isDark,
                  controller: _codeController,
                  preview: _joinPreview,
                  loadingPreview: _loadingPreview,
                  joining: _joining,
                  onCodeChanged: _previewInvite,
                  onJoin: _joinGroup,
                ),
              ],
            ),
    );
  }
}

// ── Generate Tab ─────────────────────────────────────────────

class _GenerateTab extends StatelessWidget {
  final bool isDark;
  final String? generatedCode;
  final DateTime? expiresAt;
  final bool generating;
  final VoidCallback onGenerate;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _GenerateTab({
    required this.isDark,
    required this.generatedCode,
    required this.expiresAt,
    required this.generating,
    required this.onGenerate,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'Generate a unique invite code and share it with anyone you want to add to this group. The code is valid for 7 days.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          if (generatedCode != null) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.secondary.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    generatedCode!,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      color: AppColors.primary,
                    ),
                  ),
                  if (expiresAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Expires ${_formatExpiry(expiresAt!)}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCopy,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy Code'),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onShare,
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Share'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Generate New Code'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ] else ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  Icon(Icons.link_rounded, size: 56, color: AppColors.primary.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Text('No active invite code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textLight)),
                  const SizedBox(height: 8),
                  Text('Tap below to generate one', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Spacer(),
            SpButton(label: 'Generate Invite Code', onTap: generating ? null : onGenerate, isLoading: generating, icon: Icons.add_link_rounded),
          ],
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
        ],
      ),
    );
  }

  String _formatExpiry(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inDays > 0) return 'in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours > 0) return 'in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    return 'soon';
  }
}

// ── Join Tab ─────────────────────────────────────────────────

class _JoinTab extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;
  final String? preview;
  final bool loadingPreview;
  final bool joining;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onJoin;

  const _JoinTab({
    required this.isDark,
    required this.controller,
    required this.preview,
    required this.loadingPreview,
    required this.joining,
    required this.onCodeChanged,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewPadding.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'Enter an invite code you received from a group admin to join their group.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6),
            maxLength: 8,
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.textSecondary.withValues(alpha: 0.4)),
              counterText: '',
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
            onChanged: onCodeChanged,
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: loadingPreview
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                : preview != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: AppColors.income, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(preview!, style: const TextStyle(fontSize: 13, color: AppColors.income))),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
          const Spacer(),
          SpButton(
            label: 'Join Group',
            onTap: (controller.text.trim().isNotEmpty && !joining) ? onJoin : null,
            isLoading: joining,
            icon: Icons.group_add_rounded,
          ),
        ],
      ),
    );
  }
}
