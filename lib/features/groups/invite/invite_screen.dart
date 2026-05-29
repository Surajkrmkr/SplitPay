import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../shared/widgets/sp_button.dart';

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.splitpay.expensetracker';

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
      final result =
          await ref.read(groupApiServiceProvider).generateInvite(widget.groupId!);
      setState(() {
        _generatedCode = result['code'] as String?;
        final expiresStr = result['expiresAt'] as String?;
        _expiresAt =
            expiresStr != null ? DateTime.parse(expiresStr) : null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _shareCode() async {
    if (_generatedCode == null) return;
    final message =
        'Join my SplitPay group with invite code: $_generatedCode\n\n'
        'Download the app: $_playStoreUrl';
    await Share.share(message, subject: 'Join my SplitPay group');
  }

  Future<void> _shareQrCode() async {
    if (_generatedCode == null) return;
    const qrSize   = 400.0;
    const padding  = 40.0;
    const total    = qrSize + padding * 2;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    // White background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, total, total),
      Paint()..color = Colors.white,
    );

    final painter = QrPainter(
      data: 'dimeflow://join/$_generatedCode',
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.primary,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF1A1A2E),
      ),
    );

    canvas.save();
    canvas.translate(padding, padding);
    painter.paint(canvas, const Size(qrSize, qrSize));
    canvas.restore();

    final picture  = recorder.endRecording();
    final image    = await picture.toImage(total.toInt(), total.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes    = byteData!.buffer.asUint8List();

    final file = File('${Directory.systemTemp.path}/splitpay_invite_$_generatedCode.png');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: 'Join my SplitPay group!\nCode: $_generatedCode',
      subject: 'SplitPay Group Invite',
    );
  }

  // ── Join ────────────────────────────────────────────────────

  Future<void> _previewInvite(String code) async {
    if (code.length < 6) return;
    setState(() {
      _loadingPreview = true;
      _joinPreview = null;
    });
    try {
      final info = await ref
          .read(groupApiServiceProvider)
          .getInviteInfo(code.trim().toUpperCase());
      if (mounted) {
        setState(() => _joinPreview =
            '${info['groupName']} · ${info['memberCount']} members · invited by ${info['invitedBy']}');
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
      final group =
          await ref.read(groupApiServiceProvider).joinViaInvite(code);
      ref.invalidate(groupsProvider);
      ref.invalidate(groupDetailProvider(group.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Joined "${group.name}" successfully!'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _openQrScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _QrScannerSheet(
        onCodeDetected: (code) {
          _codeController.text = code;
          _previewInvite(code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Only admins can generate invite codes — derived from the group's member roster.
    bool isAdmin = false;
    if (!_joinOnly) {
      final groupAsync = ref.watch(groupDetailProvider(widget.groupId!));
      final currentUserId = ref.watch(currentUserProvider)?.id;
      final group = groupAsync.valueOrNull;
      if (group != null && currentUserId != null) {
        final me = group.members
            .where((m) => m.userId == currentUserId)
            .firstOrNull;
        isAdmin = me?.isAdmin ?? false;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        leadingWidth: 56,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Center(child: AppBackButton()),
        ),
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
                dividerColor:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder,
                tabs: const [
                  Tab(text: 'Generate Code'),
                  Tab(text: 'Join Group')
                ],
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
              onScanQr: _openQrScanner,
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _GenerateTab(
                  isDark: isDark,
                  isAdmin: isAdmin,
                  generatedCode: _generatedCode,
                  expiresAt: _expiresAt,
                  generating: _generating,
                  onGenerate: _generateCode,
                  onCopy: _copyCode,
                  onShare: _shareCode,
                  onShareQr: _shareQrCode,
                ),
                _JoinTab(
                  isDark: isDark,
                  controller: _codeController,
                  preview: _joinPreview,
                  loadingPreview: _loadingPreview,
                  joining: _joining,
                  onCodeChanged: _previewInvite,
                  onJoin: _joinGroup,
                  onScanQr: _openQrScanner,
                ),
              ],
            ),
    );
  }
}

// ── Generate Tab ─────────────────────────────────────────────

class _GenerateTab extends StatelessWidget {
  final bool isDark;
  final bool isAdmin;
  final String? generatedCode;
  final DateTime? expiresAt;
  final bool generating;
  final VoidCallback onGenerate;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onShareQr;

  const _GenerateTab({
    required this.isDark,
    required this.isAdmin,
    required this.generatedCode,
    required this.expiresAt,
    required this.generating,
    required this.onGenerate,
    required this.onCopy,
    required this.onShare,
    required this.onShareQr,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewPadding.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Generate a unique invite code and share it with anyone you want to add to this group. The code is valid for 7 days.',
            style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 28),
          if (generatedCode != null) ...[
            // Code card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.secondary.withValues(alpha: 0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    generatedCode!,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      color: AppColors.primary,
                    ),
                  ),
                  if (expiresAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Expires ${_formatExpiry(expiresAt!)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: 'dimeflow://join/$generatedCode',
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.primary,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 6),
                  Text(
                    'Scan to join',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCopy,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onShare,
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Share'),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onShareQr,
                      icon: const Icon(Icons.qr_code_rounded, size: 16),
                      label: const Text('Share QR Code'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Generate New Code'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary),
            ),
          ] else ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  Icon(
                    isAdmin
                        ? Icons.qr_code_2_rounded
                        : Icons.lock_outline_rounded,
                    size: 64,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAdmin
                        ? 'No active invite code'
                        : 'Admin permission required',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textLight),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAdmin
                        ? 'Tap below to generate a code + QR'
                        : 'Only group admins can generate invite codes. Ask an admin to share an invite with you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Tooltip(
              message: isAdmin
                  ? ''
                  : 'Only admins can create invite codes for this group',
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 3),
              child: SpButton(
                label: 'Generate Invite Code',
                onTap: (isAdmin && !generating) ? onGenerate : null,
                isLoading: generating,
                icon: isAdmin
                    ? Icons.add_link_rounded
                    : Icons.lock_outline_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatExpiry(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inDays > 0) {
      return 'in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    }
    if (diff.inHours > 0) {
      return 'in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    }
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
  final VoidCallback onScanQr;

  const _JoinTab({
    required this.isDark,
    required this.controller,
    required this.preview,
    required this.loadingPreview,
    required this.joining,
    required this.onCodeChanged,
    required this.onJoin,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewPadding.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter an invite code or scan a QR code to join a group.',
            style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6),
            maxLength: 8,
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: AppColors.textSecondary.withValues(alpha: 0.4)),
              counterText: '',
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
            onChanged: onCodeChanged,
          ),
          const SizedBox(height: 12),
          // QR scan button
          OutlinedButton.icon(
            onPressed: onScanQr,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: const Text('Scan QR Code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: loadingPreview
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)))
                : preview != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppColors.income.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                color: AppColors.income, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(preview!,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.income))),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
          const Spacer(),
          SpButton(
            label: 'Join Group',
            onTap: (controller.text.trim().isNotEmpty && !joining)
                ? onJoin
                : null,
            isLoading: joining,
            icon: Icons.group_add_rounded,
          ),
        ],
      ),
    );
  }
}

// ── QR Scanner Sheet ─────────────────────────────────────────

class _QrScannerSheet extends StatefulWidget {
  final ValueChanged<String> onCodeDetected;
  const _QrScannerSheet({required this.onCodeDetected});

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  bool _scanned = false;
  final MobileScannerController _controller = MobileScannerController();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _scanned = true;
    _controller.stop();
    _handleRaw(raw);
  }

  void _handleRaw(String raw) {
    final code = raw.startsWith('dimeflow://join/')
        ? raw.substring('dimeflow://join/'.length)
        : raw;
    Navigator.of(context).pop();
    widget.onCodeDetected(code.toUpperCase());
  }

  Future<void> _pickFromGallery() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final capture = await _controller.analyzeImage(file.path);
    if (!mounted) return;
    final raw = capture?.barcodes.firstOrNull?.rawValue;
    if (raw != null && raw.isNotEmpty) {
      _scanned = true;
      _handleRaw(raw);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No QR code found in the selected image'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * 0.72,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          children: [
            // Camera
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
            // Dark overlay with cutout
            _ScannerOverlay(),
            // Drag handle
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
            // Bottom controls
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Point camera at a QR code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Pick from Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  static const double _cutoutSize = 220;
  static const double _cornerRadius = 16;
  static const double _cornerLength = 28;
  static const double _cornerWidth = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 20;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: _cutoutSize,
      height: _cutoutSize,
    );

    // Semi-transparent overlay
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(_cornerRadius)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Corner accents
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = _cornerWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    const cr = _cornerRadius;
    const cl = _cornerLength;

    // Top-left
    canvas.drawLine(Offset(l + cr, t), Offset(l + cr + cl, t), cornerPaint);
    canvas.drawLine(Offset(l, t + cr), Offset(l, t + cr + cl), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(l, t, cr * 2, cr * 2), 3.14, 1.57, false,
        cornerPaint);
    // Top-right
    canvas.drawLine(Offset(r - cr - cl, t), Offset(r - cr, t), cornerPaint);
    canvas.drawLine(Offset(r, t + cr), Offset(r, t + cr + cl), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(r - cr * 2, t, cr * 2, cr * 2), -1.57, 1.57,
        false, cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(l + cr, b), Offset(l + cr + cl, b), cornerPaint);
    canvas.drawLine(Offset(l, b - cr - cl), Offset(l, b - cr), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(l, b - cr * 2, cr * 2, cr * 2), 1.57, 1.57,
        false, cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(r - cr - cl, b), Offset(r - cr, b), cornerPaint);
    canvas.drawLine(Offset(r, b - cr - cl), Offset(r, b - cr), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(r - cr * 2, b - cr * 2, cr * 2, cr * 2), 0,
        1.57, false, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
