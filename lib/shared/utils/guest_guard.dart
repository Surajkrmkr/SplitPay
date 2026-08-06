import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../widgets/guest_login_prompt.dart';

/// Checks if the current user is a guest.
/// - If guest: shows the sign-in prompt bottom sheet.
/// - If authenticated: executes [onAuthenticated] immediately.
///
/// Usage:
/// ```dart
/// onTap: () => requireAuth(context, ref, _showAddTransaction),
/// ```
void requireAuth(
  BuildContext context,
  WidgetRef ref,
  VoidCallback onAuthenticated,
) {
  final authValue = ref.read(authProvider).valueOrNull;

  if (authValue?.isGuest == true) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GuestLoginPrompt(onSignedIn: onAuthenticated),
    );
  } else {
    onAuthenticated();
  }
}
