import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counter bumped by [AuthInterceptor] whenever the session becomes invalid —
/// refresh token missing, refresh request failed, or refresh endpoint 401'd.
/// [AuthNotifier] listens to this and resets auth state to unauthenticated,
/// which triggers the router redirect to /login.
final sessionExpiredProvider = StateProvider<int>((_) => 0);
