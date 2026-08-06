import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../core/constants/app_colors.dart';
import '../../core/errors/app_exception.dart';
import '../../providers/auth_provider.dart';

import '../../core/services/app_logger.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

// Track which button is loading independently
enum _LoadingState { none, google, apple }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _LoadingState _loadingState = _LoadingState.none;

  bool get _isAnyLoading => _loadingState != _LoadingState.none;

  Future<void> _signIn() async {
    HapticFeedback.mediumImpact();
    setState(() => _loadingState = _LoadingState.google);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      final state = ref.read(authProvider).valueOrNull;
      if (state?.status == AuthStatus.error) {
        _showError(state?.error ?? 'Sign in failed');
      }
    } catch (e) {
      if (mounted) _showError(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loadingState = _LoadingState.none);
    }
  }

  Future<void> _signInWithApple() async {
    HapticFeedback.mediumImpact();
    setState(() => _loadingState = _LoadingState.apple);
    try {
      AppLogger.instance.i('User initiated Apple Sign In button press', tag: 'Auth');
      await ref.read(authProvider.notifier).signInWithApple();
      if (!mounted) return;
      final state = ref.read(authProvider).valueOrNull;
      if (state?.status == AuthStatus.error) {
        AppLogger.instance.e('Apple Sign In finished with state error: ${state?.error}', tag: 'Auth');
        _showError(state?.error ?? 'Sign in failed');
      }
    } on SignInWithAppleAuthorizationException catch (e, stack) {
      if (e.code == AuthorizationErrorCode.canceled) {
        AppLogger.instance.i('Apple Sign In cancelled by user', tag: 'Auth');
        return;
      }
      AppLogger.instance.e(
        'SignInWithAppleAuthorizationException [code=${e.code}]: ${e.message}',
        tag: 'Auth',
        extra: stack.toString(),
      );
      if (mounted) _showError(e.message);
    } catch (e, stack) {
      AppLogger.instance.e(
        'Unexpected Apple Sign In error: $e',
        tag: 'Auth',
        extra: stack.toString(),
      );
      if (mounted) _showError(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loadingState = _LoadingState.none);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final elevatedColor = isDark ? AppColors.darkElevated : AppColors.lightCard;
    final titleColor = isDark ? Colors.white : AppColors.textLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textLightSecondary;
    final tertiaryColor = isDark ? AppColors.textTertiary : AppColors.textLightSecondary;

    final gradientColors = isDark
        ? [
            AppColors.darkBg,
            const Color(0xFF0D1A14),
            AppColors.primary.withValues(alpha: 0.15),
          ]
        : [
            AppColors.lightBg,
            const Color(0xFFEAF7F3),
            AppColors.primary.withValues(alpha: 0.10),
          ];

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top hero section
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 88,
                            height: 88,
                          ),
                        ).animate().fadeIn(duration: 600.ms).slideY(
                            begin: -0.2,
                            duration: 600.ms,
                            curve: Curves.easeOut),

                        const SizedBox(height: 16),

                        Text(
                          'SplitPay',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        )
                            .animate(delay: 150.ms)
                            .fadeIn(duration: 500.ms)
                            .slideY(begin: 0.1, duration: 500.ms),

                        const SizedBox(height: 6),

                        Text(
                          'Track smarter. Split better.',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 15,
                          ),
                        ).animate(delay: 250.ms).fadeIn(duration: 500.ms),

                        const SizedBox(height: 24),

                        // Feature rows
                        ..._features.asMap().entries.map(
                              (e) => _FeatureRow(
                                icon: e.value.$1,
                                label: e.value.$2,
                                textColor: titleColor,
                              )
                                  .animate(delay: (350 + e.key * 80).ms)
                                  .fadeIn(duration: 400.ms)
                                  .slideX(begin: -0.1, duration: 400.ms),
                            ),
                      ],
                    ),
                  ),
                ),

                // Bottom sign-in card
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      border: Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 24,
                                offset: const Offset(0, -4),
                              ),
                            ],
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        24,
                        24,
                        16 + MediaQuery.of(context).padding.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Welcome to SplitPay',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in to start tracking and splitting expenses.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Icon Sign-In Buttons ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google
                              _SignInIconButton(
                                isLoading: _loadingState == _LoadingState.google,
                                disabled: _isAnyLoading,
                                isDark: isDark,
                                elevatedColor: elevatedColor,
                                borderColor: borderColor,
                                onTap: _isAnyLoading ? null : _signIn,
                                child: Image.asset(
                                  'assets/icon/google_logo.png',
                                  width: 26,
                                  height: 26,
                                ),
                              ),

                              if (Platform.isIOS) ...[
                                const SizedBox(width: 20),
                                // Apple
                                _SignInIconButton(
                                  isLoading: _loadingState == _LoadingState.apple,
                                  disabled: _isAnyLoading,
                                  isDark: isDark,
                                  elevatedColor: elevatedColor,
                                  borderColor: borderColor,
                                  onTap: _isAnyLoading ? null : _signInWithApple,
                                  child: Icon(
                                    Icons.apple_rounded,
                                    size: 30,
                                    color: isDark ? Colors.white : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Provider label
                          Text(
                            Platform.isIOS
                                ? 'Sign in with Google or Apple'
                                : 'Sign in with Google',
                            style: TextStyle(
                              color: tertiaryColor,
                              fontSize: 13,
                            ),
                          ),

                          // Continue as Guest — iOS only
                          if (Platform.isIOS) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isAnyLoading
                                  ? null
                                  : () => ref
                                      .read(authProvider.notifier)
                                      .continueAsGuest(),
                              style: TextButton.styleFrom(
                                foregroundColor: tertiaryColor,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text(
                                'Continue as Guest',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Terms
                          Text(
                            'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: tertiaryColor,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideY(
                      begin: 0.1, duration: 500.ms, curve: Curves.easeOut),
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
    (Icons.check_circle_rounded, 'Seamless in-app payments'),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.textColor,
  });

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
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular icon button used for social sign-in providers.
class _SignInIconButton extends StatelessWidget {
  final bool isLoading;
  final bool disabled;
  final bool isDark;
  final Color elevatedColor;
  final Color borderColor;
  final VoidCallback? onTap;
  final Widget child;

  const _SignInIconButton({
    required this.isLoading,
    required this.disabled,
    required this.isDark,
    required this.elevatedColor,
    required this.borderColor,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: disabled && !isLoading
              ? elevatedColor.withValues(alpha: 0.5)
              : elevatedColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isLoading
                ? AppColors.primary.withValues(alpha: 0.6)
                : borderColor,
            width: 1.5,
          ),
          boxShadow: isLoading
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              : Opacity(
                  opacity: disabled ? 0.4 : 1.0,
                  child: child,
                ),
        ),
      ),
    );
  }
}
