import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_constants.dart';
import '../core/network/auth_events.dart';
import '../core/storage/token_storage.dart';
import '../data/models/auth_user_model.dart';
import '../data/repositories/notification_repository.dart';
import '../data/services/firebase_auth_service.dart';
import '../core/storage/preferences_service.dart';
import '../data/services/notification_service.dart';
import 'transaction_provider.dart';
import 'budget_provider.dart';
import 'notification_provider.dart';
import 'group_provider.dart';
import 'settings_provider.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final AuthUserModel? user;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  const AuthState.initial() : this(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    AuthUserModel? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading =>
      status == AuthStatus.loading || status == AuthStatus.initial;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final tokenStorage = ref.watch(tokenStorageProvider);
    final firebaseAuth = ref.watch(firebaseAuthServiceProvider);

    // Reset auth state when the API client signals an invalid session
    // (refresh token expired/missing or refresh request failed).
    ref.listen(sessionExpiredProvider, (prev, next) {
      if (prev != null && next > prev) {
        _handleSessionExpired();
      }
    });

    final hasTokens = await tokenStorage.hasTokens();
    if (!hasTokens) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    // Try to fetch current user from backend
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.usersMe);
      final user = AuthUserModel.fromJson(
        res.data['data'] as Map<String, dynamic>,
      );
      return AuthState(status: AuthStatus.authenticated, user: user);
    } on DioException catch (_) {
      // Backend unreachable — fall back to Firebase user
      final firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser != null) {
        final user = AuthUserModel.fromFirebaseUser(firebaseUser);
        return AuthState(status: AuthStatus.authenticated, user: user);
      }
      await tokenStorage.clearTokens();
      return const AuthState(status: AuthStatus.unauthenticated);
    } catch (_) {
      await tokenStorage.clearTokens();
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signInWithGoogle() async {
    // Do NOT set AsyncValue.loading() here — it would cause the router to
    // redirect away from /login to /splash during the Google account picker flow.
    // Loading UI is managed locally inside LoginScreen.
    try {
      final firebaseAuth = ref.read(firebaseAuthServiceProvider);
      final tokenStorage = ref.read(tokenStorageProvider);
      final dio = ref.read(dioProvider);

      final idToken = await firebaseAuth.signInWithGoogle();
      if (idToken == null) {
        state = AsyncValue.data(
          const AuthState(status: AuthStatus.unauthenticated),
        );
        return;
      }

      // Exchange Firebase token for backend JWT
      final res = await dio.post(
        ApiConstants.authGoogle,
        data: {'idToken': idToken},
      );

      final accessToken = res.data['data']?['accessToken'] as String?;
      final refreshToken = res.data['data']?['refreshToken'] as String?;
      final userData = res.data['data']?['user'] as Map<String, dynamic>?;

      if (accessToken != null && refreshToken != null) {
        await tokenStorage.saveTokens(
          access: accessToken,
          refresh: refreshToken,
        );
      }

      AuthUserModel user;
      if (userData != null) {
        user = AuthUserModel.fromJson(userData);
      } else {
        final firebaseUser = firebaseAuth.currentUser!;
        user = AuthUserModel.fromFirebaseUser(firebaseUser);
      }

      state = AsyncValue.data(
        AuthState(status: AuthStatus.authenticated, user: user),
      );

      // Register FCM token with backend
      await _registerFcmToken(user.id);
    } on DioException catch (e) {
      // Backend not available — use Firebase user directly (mock mode)
      final firebaseAuth = ref.read(firebaseAuthServiceProvider);
      final firebaseUser = firebaseAuth.currentUser;
      if (firebaseUser != null) {
        final user = AuthUserModel.fromFirebaseUser(firebaseUser);
        state = AsyncValue.data(
          AuthState(status: AuthStatus.authenticated, user: user),
        );
        await _registerFcmToken(user.id);
      } else {
        state = AsyncValue.data(
          AuthState(
            status: AuthStatus.error,
            error: friendlyErrorMessage(e),
          ),
        );
      }
    } catch (e) {
      state = AsyncValue.data(
        AuthState(
          status: AuthStatus.error,
          error: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final tokenStorage = ref.read(tokenStorageProvider);
      final firebaseAuth = ref.read(firebaseAuthServiceProvider);
      final dio = ref.read(dioProvider);

      // Unregister FCM token before logout
      await ref.read(notificationRepositoryProvider).unregisterToken();
      await NotificationService.instance.deleteToken();

      try {
        final refreshToken = await tokenStorage.getRefreshToken();
        await dio.post(
          ApiConstants.authLogout,
          data: {'refreshToken': refreshToken},
        );
      } catch (_) {
        // Best-effort logout on server
      }

      await Future.wait([
        tokenStorage.clearTokens(),
        firebaseAuth.signOut(),
        PreferencesService.clearUserData(),
      ]);

      _clearCache();

      state = AsyncValue.data(
        const AuthState(status: AuthStatus.unauthenticated),
      );
    } catch (e) {
      state = AsyncValue.data(
        AuthState(status: AuthStatus.error, error: friendlyErrorMessage(e)),
      );
    }
  }

  void _clearCache() {
    ref.invalidate(transactionProvider);
    ref.invalidate(budgetProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(groupsProvider);
    ref.invalidate(customCategoriesProvider);
  }

  Future<void> _handleSessionExpired() async {
    // Tokens are already cleared by AuthInterceptor; sign out of Firebase,
    // delete notification token, and wipe local DB so stale data can't bleed
    // into the next user's session.
    try {
      await Future.wait([
        NotificationService.instance.deleteToken(),
        ref.read(firebaseAuthServiceProvider).signOut(),
        PreferencesService.clearUserData(),
      ]);
    } catch (_) {}
    _clearCache();
    state = AsyncValue.data(
      const AuthState(status: AuthStatus.unauthenticated),
    );
  }

  Future<void> _registerFcmToken(String userId) async {
    try {
      final token = await NotificationService.instance.getToken();
      if (token == null) return;
      await ref.read(notificationRepositoryProvider).registerToken(
            userId: userId,
            fcmToken: token,
          );
      // Re-register if token rotates
      NotificationService.instance.onTokenRefresh.listen((newToken) {
        ref.read(notificationRepositoryProvider).registerToken(
              userId: userId,
              fcmToken: newToken,
            );
      });
    } catch (_) {}
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());

final currentUserProvider = Provider<AuthUserModel?>((ref) {
  return ref.watch(authProvider).valueOrNull?.user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final state = ref.watch(authProvider).valueOrNull;
  return state?.status == AuthStatus.authenticated;
});
