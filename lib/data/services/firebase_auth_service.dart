import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/services/app_logger.dart';

class FirebaseAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Forces the returned idToken's `aud` to be this web client ID (client_type 3
    // in google-services.json) instead of the platform-specific client ID, since
    // the backend verifies GOOGLE_CLIENT_ID against the web client.
    serverClientId:
        '127223843872-sou5unj9eitknesrlidsqg5tjclnio1o.apps.googleusercontent.com',
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

      var googleAuth = await googleAccount.authentication;

      // Right after a recent signOut(), Play Services can hand back this
      // account before its tokens are minted, so idToken comes back null on
      // the first call. Re-request a few times before giving up — this is
      // what previously showed up as needing 2-3 manual login taps.
      for (var attempt = 1; attempt <= 3 && googleAuth.idToken == null; attempt++) {
        await Future.delayed(Duration(milliseconds: 250 * attempt));
        googleAuth = await googleAccount.authentication;
      }

      if (googleAuth.idToken == null) {
        throw StateError(
          'Google account selected but ID token was null. Try signing in again.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Return the Firebase ID token so the backend can verify it via Firebase Admin SDK
      final firebaseIdToken = await userCredential.user?.getIdToken();
      return firebaseIdToken ?? googleAuth.idToken;
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

  /// Silently re-authenticates the previously signed-in Google account.
  /// Returns the Google OAuth2 ID token (not Firebase token) without showing
  /// any UI. Returns null if silent sign-in is not available.
  Future<String?> getSilentGoogleIdToken() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.idToken;
    } catch (_) {
      return null;
    }
  }

  /// Helper to generate a random nonce for Apple Sign In.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// SHA-256 hash helper
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Performs Sign in with Apple using raw nonce & SHA256 hashed nonce
  /// with [OAuthProvider("apple.com")].
  /// Returns [UserCredential] on success, or null if cancelled.
  Future<UserCredential?> signInWithApple() async {
    try {
      AppLogger.instance.i('Starting Apple Sign In (generating nonce)...', tag: 'Auth');
      final rawNonce = _generateNonce();
      final sha256Nonce = _sha256ofString(rawNonce);

      AppLogger.instance.i('Requesting Apple ID Credential...', tag: 'Auth');
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256Nonce,
      );

      AppLogger.instance.i(
        'Apple ID Credential received: email=${credential.email}, givenName=${credential.givenName}, identityTokenPresent=${credential.identityToken != null}',
        tag: 'Auth',
      );

      if (credential.identityToken == null) {
        throw StateError('Apple ID credential returned null identityToken.');
      }

      final oauthProvider = OAuthProvider('apple.com');
      final authCredential = oauthProvider.credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
        accessToken: credential.authorizationCode,
      );

      AppLogger.instance.i('Signing into Firebase with Apple OAuth credential...', tag: 'Auth');
      final userCred = await FirebaseAuth.instance.signInWithCredential(authCredential);
      AppLogger.instance.i('Successfully authenticated with Firebase: uid=${userCred.user?.uid}, email=${userCred.user?.email}', tag: 'Auth');
      return userCred;
    } catch (e, stack) {
      AppLogger.instance.e(
        'Apple Sign In error in FirebaseAuthService: $e',
        tag: 'Auth',
        extra: stack.toString(),
      );
      rethrow;
    }
  }
}

final firebaseAuthServiceProvider =
    Provider<FirebaseAuthService>((_) => FirebaseAuthService());
