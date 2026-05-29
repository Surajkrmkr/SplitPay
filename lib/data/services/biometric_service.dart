import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import '../../core/services/app_logger.dart';

enum BiometricResult {
  success,
  cancelled,
  notEnrolled,
  notAvailable,
  lockedOut,
  failed,
}

class BiometricService {
  static final BiometricService instance = BiometricService._();
  BiometricService._();

  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<BiometricResult> authenticate({
    String reason = 'Authenticate to access SplitPay',
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return ok ? BiometricResult.success : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      AppLogger.instance.e(
        'Biometric error — code: ${e.code} | msg: ${e.message}',
        tag: 'Biometric',
      );
      switch (e.code) {
        case auth_error.notEnrolled:
          return BiometricResult.notEnrolled;
        case auth_error.notAvailable:
        case auth_error.passcodeNotSet:
          return BiometricResult.notAvailable;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return BiometricResult.lockedOut;
        default:
          return BiometricResult.failed;
      }
    } catch (e) {
      AppLogger.instance.e('Biometric unknown error: $e', tag: 'Biometric');
      return BiometricResult.failed;
    }
  }
}
