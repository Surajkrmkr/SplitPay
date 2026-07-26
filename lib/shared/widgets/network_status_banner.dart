import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/connectivity_provider.dart';

/// Overlay listener widget that displays a top banner when the device
/// transitions to offline mode or recovers connection back online.
class NetworkStatusBannerListener extends ConsumerStatefulWidget {
  const NetworkStatusBannerListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NetworkStatusBannerListener> createState() =>
      _NetworkStatusBannerListenerState();
}

class _NetworkStatusBannerListenerState
    extends ConsumerState<NetworkStatusBannerListener> {
  OverlayEntry? _entry;
  Timer? _dismissTimer;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<bool>(isOfflineProvider, (previous, next) {
        final label = ref.read(connectionTypeLabelProvider);
        if (next) {
          _wasOffline = true;
          _showBanner(
            title: 'No Internet Connection',
            subtitle: 'You are currently offline. Changes will sync when reconnected.',
            isOffline: true,
            persistent: true,
          );
        } else if (_wasOffline) {
          _wasOffline = false;
          _showBanner(
            title: 'Back Online',
            subtitle: 'Connection restored via $label',
            isOffline: false,
            persistent: false,
          );
        }
      });
    });
  }

  void _showBanner({
    required String title,
    required String subtitle,
    required bool isOffline,
    required bool persistent,
  }) {
    _dismissTimer?.cancel();
    _entry?.remove();
    _entry = null;

    if (!mounted) return;

    _entry = OverlayEntry(
      builder: (_) => _BannerWidget(
        title: title,
        subtitle: subtitle,
        isOffline: isOffline,
        onDismiss: _dismiss,
      ),
    );

    Overlay.of(context).insert(_entry!);

    if (!persistent) {
      _dismissTimer = Timer(const Duration(seconds: 3), _dismiss);
    }
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BannerWidget extends StatefulWidget {
  const _BannerWidget({
    required this.title,
    required this.subtitle,
    required this.isOffline,
    required this.onDismiss,
  });

  final String title;
  final String subtitle;
  final bool isOffline;
  final VoidCallback onDismiss;

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final color = widget.isOffline ? AppColors.expense : AppColors.income;
    final icon = widget.isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded;

    return Positioned(
      top: topPad + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: widget.onDismiss,
            onVerticalDragEnd: (d) {
              if (d.primaryVelocity != null && d.primaryVelocity! < 0) {
                widget.onDismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2228),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
