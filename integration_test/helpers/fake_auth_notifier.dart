import 'package:splitpay/data/models/auth_user_model.dart';
import 'package:splitpay/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _fakeUser = AuthUserModel(
  id: 'test-uid-001',
  email: 'tester@dimeflow.test',
  name: 'Test User',
  createdAt: DateTime.utc(2024, 1, 1),
);

class FakeAuthNotifier extends AuthNotifier {
  final bool initiallyAuthenticated;

  FakeAuthNotifier({this.initiallyAuthenticated = false});

  @override
  Future<AuthState> build() async {
    if (initiallyAuthenticated) {
      return AuthState(
        status: AuthStatus.authenticated,
        user: _fakeUser,
      );
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  Future<void> signInWithGoogle() async {
    state = AsyncValue.data(
      AuthState(status: AuthStatus.authenticated, user: _fakeUser),
    );
  }

  @override
  Future<void> signOut() async {
    state = const AsyncValue.data(
      AuthState(status: AuthStatus.unauthenticated),
    );
  }
}
