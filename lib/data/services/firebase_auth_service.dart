import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Signs in with Google and returns the Google OAuth2 ID token.
  /// Returns null if the user cancels the sign-in.
  ///
  /// NOTE: We return googleAuth.idToken (Google OAuth2 token, aud = web client ID)
  /// NOT userCredential.user.getIdToken() (Firebase token, aud = Firebase project ID).
  /// The backend verifies against GOOGLE_CLIENT_ID which is the OAuth2 web client ID.
  Future<String?> signInWithGoogle() async {
    try {
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) return null;

      final googleAuth = await googleAccount.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Maintain Firebase session (needed for Firebase features)
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Return the Google OAuth2 ID token — its `aud` matches GOOGLE_CLIENT_ID
      return googleAuth.idToken;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _googleSignIn.signOut(),
      FirebaseAuth.instance.signOut(),
    ]);
  }

  Future<String?> getCurrentIdToken({bool forceRefresh = false}) async {
    return FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
  }
}

final firebaseAuthServiceProvider =
    Provider<FirebaseAuthService>((_) => FirebaseAuthService());
