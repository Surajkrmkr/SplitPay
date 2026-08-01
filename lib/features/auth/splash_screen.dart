import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/biometric_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;
  bool _awaitingBiometric = false;
  bool _showUnlockButton = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), _checkAndNavigate);
  }

  void _checkAndNavigate() {
    if (_navigated || !mounted) return;
    final authState = ref.read(authProvider).valueOrNull;
    if (authState == null) return; // still loading
    _doNavigate(authState);
  }

  Future<void> _doNavigate(AuthState authState) async {
    if (_navigated || !mounted) return;

    if (authState.status == AuthStatus.authenticated) {
      final onboardingDone = ref.read(onboardingCompletedProvider);
      final biometricEnabled = ref.read(biometricLockProvider);

      if (biometricEnabled) {
        setState(() { _awaitingBiometric = true; _showUnlockButton = false; });
        final result = await BiometricService.instance.authenticate();
        if (!mounted) return;
        final ok = result == BiometricResult.success;
        setState(() { _awaitingBiometric = false; _showUnlockButton = !ok; });
        if (!ok) return;
      }

      _navigated = true;
      context.go(onboardingDone ? '/home' : '/onboarding');
    } else {
      _navigated = true;
      context.go('/login');
    }
  }

  Future<void> _retry() async {
    final authState = ref.read(authProvider).valueOrNull;
    if (authState == null) return;
    await _doNavigate(authState);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<AsyncValue<AuthState>>(authProvider, (_, next) {
      next.whenData((state) {
        if (state.status != AuthStatus.initial &&
            state.status != AuthStatus.loading) {
          Future.delayed(
            const Duration(milliseconds: 400),
            () => _doNavigate(state),
          );
        }
      });
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    AppColors.darkBg,
                    Color(0xFF0D1A14),
                    AppColors.darkBg,
                  ]
                : const [
                    AppColors.lightBg,
                    Color(0xFFE8F8F2),
                    AppColors.lightBg,
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo — icon already has its own background; render flat
                // with iOS-style ~22% corner radius.
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 96,
                    height: 96,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                      begin: 1.0,
                      end: 1.06,
                      duration: 1800.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.2, duration: 600.ms, curve: Curves.easeOut),

                const SizedBox(height: 28),

                // App name
                Text(
                  'SplitPay',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textLight,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.15, duration: 500.ms, curve: Curves.easeOut),

                const SizedBox(height: 10),

                // Tagline
                Text(
                  'Track smarter. Split better.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                )
                    .animate(delay: 350.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.15, duration: 500.ms, curve: Curves.easeOut),

                const SizedBox(height: 56),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.18), end: Offset.zero)
                          .animate(CurvedAnimation(
                              parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  ),
                  child: _showUnlockButton
                      ? _BiometricUnlockPanel(
                          onRetry: _retry, key: const ValueKey('unlock'))
                      : _awaitingBiometric
                          ? _BiometricScanningPanel(
                              key: const ValueKey('scanning'))
                          : SizedBox(
                              key: const ValueKey('loading'),
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary.withValues(alpha: 0.6),
                              ),
                            )
                              .animate(delay: 600.ms)
                              .fadeIn(duration: 400.ms),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Biometric unlock panel (shown when auth was cancelled / failed) ──────────

class _BiometricUnlockPanel extends StatelessWidget {
  final VoidCallback onRetry;
  const _BiometricUnlockPanel({required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Pulsing rings + icon
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scaleXY(
                      begin: 0.7,
                      end: 1.1,
                      duration: 1600.ms,
                      curve: Curves.easeOut)
                  .fadeOut(begin: 0.8, duration: 1600.ms),

              // Mid pulse ring
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scaleXY(
                      begin: 0.75,
                      end: 1.05,
                      duration: 1600.ms,
                      curve: Curves.easeOut,
                      delay: 200.ms)
                  .fadeOut(begin: 1.0, duration: 1600.ms, delay: 200.ms),

              // Icon container
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Verification Required',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Authentication was cancelled or failed.\nTap below to try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 28),

        // Try Again button
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(
                begin: 1.0,
                end: 1.03,
                duration: 1200.ms,
                curve: Curves.easeInOut),
      ],
    );
  }
}

// ─── Biometric scanning panel (shown while auth dialog is open) ───────────────

class _BiometricScanningPanel extends StatelessWidget {
  const _BiometricScanningPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.fingerprint_rounded,
            size: 34,
            color: AppColors.primary,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(
              duration: 1000.ms,
              color: AppColors.primaryLight.withValues(alpha: 0.5),
            )
            .scaleXY(
              begin: 0.95,
              end: 1.05,
              duration: 1000.ms,
              curve: Curves.easeInOut,
            ),

        const SizedBox(height: 16),

        Text(
          'Verifying identity…',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fadeIn(begin: 0.5, duration: 800.ms),
      ],
    );
  }
}
