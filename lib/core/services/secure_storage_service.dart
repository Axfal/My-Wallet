import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  static const String _keyPassword = 'app_password';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyIsInitialized = 'app_initialized';

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Reads stored password or returns default '123456' on first launch.
  Future<String> getPassword() async {
    final password = await _storage.read(key: _keyPassword);
    if (password == null || password.isEmpty) {
      const defaultPassword = '123456';
      await _storage.write(key: _keyPassword, value: defaultPassword);
      return defaultPassword;
    }
    return password;
  }

  /// Saves updated app password securely.
  Future<void> setPassword(String newPassword) async {
    await _storage.write(key: _keyPassword, value: newPassword);
  }

  /// Validates entered password against stored password.
  Future<bool> validatePassword(String enteredPassword) async {
    final stored = await getPassword();
    return stored == enteredPassword;
  }

  /// Checks if biometric unlock is enabled by user.
  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }

  /// Updates biometric unlock preference.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
  }

  /// Checks if first run has occurred.
  Future<bool> isAppInitialized() async {
    final val = await _storage.read(key: _keyIsInitialized);
    return val == 'true';
  }

  /// Sets app initialized flag.
  Future<void> setAppInitialized() async {
    await _storage.write(key: _keyIsInitialized, value: 'true');
  }

  /// Clears all secure storage data (used in Clear Data setting).
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
