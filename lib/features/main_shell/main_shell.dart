import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../features/add_transaction/add_transaction_sheet.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _FloatingBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        onFabTap: () => _showAddTransaction(context),
      ),
    );
  }

  void _showAddTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    );
  }
}

// ─── Floating Nav Container ─────────────────────────────────────────────────

class _FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onFabTap;

  static const _items = [
    _NavData(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavData(Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'History'),
    _NavData(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Analytics'),
    _NavData(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  const _FloatingBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(20, 0, 20, (bottomPad > 0 ? bottomPad : 16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E2228).withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                  blurRadius: 40,
                  spreadRadius: -6,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _NavItem(
                  index: 0,
                  currentIndex: currentIndex,
                  data: _items[0],
                  onTap: onTap,
                  isDark: isDark,
                ),
                _NavItem(
                  index: 1,
                  currentIndex: currentIndex,
                  data: _items[1],
                  onTap: onTap,
                  isDark: isDark,
                ),
                _CenterFabButton(onTap: onFabTap),
                _NavItem(
                  index: 2,
                  currentIndex: currentIndex,
                  data: _items[2],
                  onTap: onTap,
                  isDark: isDark,
                ),
                _NavItem(
                  index: 3,
                  currentIndex: currentIndex,
                  data: _items[3],
                  onTap: onTap,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.4, end: 0, duration: 500.ms, delay: 200.ms, curve: Curves.easeOutCubic);
  }
}

// ─── Nav Item (with expanding label pill) ───────────────────────────────────

class _NavData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  const _NavData(this.activeIcon, this.inactiveIcon, this.label);
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final _NavData data;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.data,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            padding: isSelected
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                : const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: Icon(
                    isSelected ? data.activeIcon : data.inactiveIcon,
                    key: ValueKey(isSelected),
                    color: isSelected
                        ? AppColors.primary
                        : isDark
                            ? AppColors.textTertiary
                            : AppColors.textLightSecondary,
                    size: 20,
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

// ─── Center FAB Button ───────────────────────────────────────────────────────

class _CenterFabButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CenterFabButton({required this.onTap});

  @override
  State<_CenterFabButton> createState() => _CenterFabButtonState();
}

class _CenterFabButtonState extends State<_CenterFabButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.10,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _press.forward();
  void _onTapUp(_) => _press.reverse();
  void _onTapCancel() => _press.reverse();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _press,
          builder: (_, child) => Transform.scale(
            scale: 1.0 - _press.value,
            child: child,
          ),
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x6600D09C),
                  blurRadius: 18,
                  spreadRadius: -3,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(
          duration: 500.ms,
          delay: 400.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 300.ms, delay: 400.ms);
  }
}
