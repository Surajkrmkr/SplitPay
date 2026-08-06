import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../core/constants/app_colors.dart';
import '../../core/errors/app_exception.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/app_logger.dart';

/// Bottom sheet shown to guest users when they attempt a protected action.
/// After successful sign-in, [onSignedIn] is called so the action completes.
class GuestLoginPrompt extends ConsumerStatefulWidget {
  /// Called after the user successfully signs in from this prompt.
  final VoidCallback? onSignedIn;

  const GuestLoginPrompt({super.key, this.onSignedIn});

  @override
  ConsumerState<GuestLoginPrompt> createState() => _GuestLoginPromptState();
}

enum _LoadingState { none, google, apple }

class _GuestLoginPromptState extends ConsumerState<GuestLoginPrompt> {
  _LoadingState _loading = _LoadingState.none;
  bool get _isAnyLoading => _loading != _LoadingState.none;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = _LoadingState.google);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      final state = ref.read(authProvider).valueOrNull;
      if (state?.isAuthenticated == true) {
        Navigator.of(context, rootNavigator: true).pop();
        widget.onSignedIn?.call();
      } else if (state?.status == AuthStatus.error) {
        _showError(state?.error ?? 'Sign in failed');
      }
    } catch (e) {
      if (mounted) _showError(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = _LoadingState.none);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loading = _LoadingState.apple);
    try {
      AppLogger.instance.i('Apple Sign In from guest prompt', tag: 'Auth');
      await ref.read(authProvider.notifier).signInWithApple();
      if (!mounted) return;
      final state = ref.read(authProvider).valueOrNull;
      if (state?.isAuthenticated == true) {
        Navigator.of(context, rootNavigator: true).pop();
        widget.onSignedIn?.call();
      } else if (state?.status == AuthStatus.error) {
        _showError(state?.error ?? 'Sign in failed');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = _LoadingState.none);
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
    final bg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final titleColor = isDark ? Colors.white : AppColors.textLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textLightSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final buttonBg = isDark ? AppColors.darkElevated : AppColors.lightCard;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        24,
        28,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Sign in to continue',
            style: TextStyle(
              color: titleColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Create a free account to save your data,\nsync across devices and use all features.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Sign-in buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google
              _PromptSignInButton(
                isLoading: _loading == _LoadingState.google,
                disabled: _isAnyLoading,
                isDark: isDark,
                buttonBg: buttonBg,
                borderColor: borderColor,
                onTap: _isAnyLoading ? null : _signInWithGoogle,
                child: Image.asset(
                  'assets/icon/google_logo.png',
                  width: 26,
                  height: 26,
                ),
              ),

              if (Platform.isIOS) ...[
                const SizedBox(width: 16),
                _PromptSignInButton(
                  isLoading: _loading == _LoadingState.apple,
                  disabled: _isAnyLoading,
                  isDark: isDark,
                  buttonBg: buttonBg,
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
          const SizedBox(height: 20),

          // Skip
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text(
              'Not now',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptSignInButton extends StatelessWidget {
  final bool isLoading;
  final bool disabled;
  final bool isDark;
  final Color buttonBg;
  final Color borderColor;
  final VoidCallback? onTap;
  final Widget child;

  const _PromptSignInButton({
    required this.isLoading,
    required this.disabled,
    required this.isDark,
    required this.buttonBg,
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
              ? buttonBg.withValues(alpha: 0.5)
              : buttonBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: isLoading
                ? AppColors.primary.withValues(alpha: 0.6)
                : borderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isLoading
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: isLoading ? 16 : 10,
              spreadRadius: isLoading ? 2 : 0,
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
              : Opacity(
                  opacity: disabled ? 0.4 : 1.0,
                  child: child,
                ),
        ),
      ),
    );
  }
}
