import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      final state = ref.read(authProvider).valueOrNull;
      if (state?.status == AuthStatus.error && mounted) {
        _showError(state?.error ?? 'Sign in failed');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final isLoading = _loading || authAsync.isLoading;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.darkBg,
                    const Color(0xFF0D1A14),
                    AppColors.primary.withValues(alpha: 0.15),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top 60% — hero section
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo — icon ships with its own background.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 100,
                            height: 100,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideY(begin: -0.2, duration: 600.ms, curve: Curves.easeOut),

                        const SizedBox(height: 24),

                        const Text(
                          'SplitPay',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        )
                            .animate(delay: 150.ms)
                            .fadeIn(duration: 500.ms)
                            .slideY(begin: 0.1, duration: 500.ms),

                        const SizedBox(height: 8),

                        Text(
                          'Track smarter. Split better.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        )
                            .animate(delay: 250.ms)
                            .fadeIn(duration: 500.ms),

                        const SizedBox(height: 40),

                        // Feature rows
                        ..._features
                            .asMap()
                            .entries
                            .map(
                              (e) => _FeatureRow(
                                icon: e.value.$1,
                                label: e.value.$2,
                              )
                                  .animate(delay: (350 + e.key * 80).ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideX(begin: -0.1, duration: 400.ms),
                            ),
                      ],
                    ),
                  ),
                ),

                // Bottom 40% — glassmorphism card
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      border: Border.all(
                        color: AppColors.darkBorder,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome to SplitPay',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to start tracking and splitting expenses with ease.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Google Sign In button
                        _GoogleSignInButton(
                          isLoading: isLoading,
                          onTap: isLoading ? null : _signIn,
                        ),

                        const Spacer(),

                        // Terms
                        Center(
                          child: Text(
                            'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.1, duration: 500.ms, curve: Curves.easeOut),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _features = [
    (Icons.account_balance_wallet_rounded, 'Personal expense tracking'),
    (Icons.group_rounded, 'Group expense splitting'),
    (Icons.check_circle_rounded, 'Simplified debt settlement'),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _GoogleSignInButton({required this.isLoading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GoogleIcon(size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Google "G" logo ──────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon({this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: CustomPaint(painter: _GoogleGPainter()));
}

class _GoogleGPainter extends CustomPainter {
  static const _blue   = Color(0xFF4285F4);
  static const _red    = Color(0xFFDB4437);
  static const _yellow = Color(0xFFF4B400);
  static const _green  = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final cx  = size.width / 2;
    final cy  = size.height / 2;
    final r   = size.width * 0.44;
    final sw  = size.width * 0.22;
    final arc = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.butt
      ..strokeWidth = sw;

    final oval = Rect.fromCircle(center: Offset(cx, cy), radius: r - sw / 2);

    // Arcs clockwise from 0° (right). Gap from 0°→30° is where the bar sits.
    // Blue top:  300°→360°  (60°)
    arc.color = _blue;
    canvas.drawArc(oval, 5 * pi / 3, pi / 3, false, arc);
    // Red:       30°→120°  (90°)
    arc.color = _red;
    canvas.drawArc(oval, pi / 6, pi / 2, false, arc);
    // Yellow:    120°→195° (75°)
    arc.color = _yellow;
    canvas.drawArc(oval, 2 * pi / 3, 5 * pi / 12, false, arc);
    // Green:     195°→300° (105°)
    arc.color = _green;
    canvas.drawArc(oval, 13 * pi / 12, 7 * pi / 12, false, arc);

    // Blue horizontal bar (center → right edge, filling the gap)
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - sw / 2, cx + r, cy + sw / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
