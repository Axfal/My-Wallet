import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class LocalAuthService {
  final LocalAuthentication _auth;

  LocalAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Checks if device supports biometrics or device credentials.
  Future<bool> canCheckBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Returns available biometrics (e.g. fingerprint, face, iris).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Prompt native biometric / device authentication dialog.
  Future<bool> authenticate({String reason = 'Unlock My Wallet to access your financial data'}) async {
    try {
      final bool isSupported = await canCheckBiometrics();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
