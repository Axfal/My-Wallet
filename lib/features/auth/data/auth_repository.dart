import '../../../core/services/local_auth_service.dart';
import '../../../core/services/secure_storage_service.dart';

class AuthRepository {
  final SecureStorageService _secureStorage;
  final LocalAuthService _localAuth;

  AuthRepository({
    SecureStorageService? secureStorage,
    LocalAuthService? localAuth,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _localAuth = localAuth ?? LocalAuthService();

  Future<String> getPassword() async {
    return await _secureStorage.getPassword();
  }

  Future<bool> validatePassword(String enteredPassword) async {
    return await _secureStorage.validatePassword(enteredPassword);
  }

  Future<void> changePassword(String newPassword) async {
    await _secureStorage.setPassword(newPassword);
  }

  Future<bool> isBiometricEnabled() async {
    return await _secureStorage.isBiometricEnabled();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.setBiometricEnabled(enabled);
  }

  Future<bool> canCheckBiometrics() async {
    return await _localAuth.canCheckBiometrics();
  }

  Future<bool> authenticateBiometrics() async {
    return await _localAuth.authenticate();
  }
}
