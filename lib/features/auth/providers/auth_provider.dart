import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isBiometricAvailable;
  final bool isBiometricEnabled;
  final String? errorMessage;
  final bool isProcessing;

  AuthState({
    required this.isAuthenticated,
    required this.isBiometricAvailable,
    required this.isBiometricEnabled,
    this.errorMessage,
    this.isProcessing = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isBiometricAvailable,
    bool? isBiometricEnabled,
    String? errorMessage,
    bool clearError = false,
    bool? isProcessing,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository)
      : super(AuthState(
          isAuthenticated: false,
          isBiometricAvailable: false,
          isBiometricEnabled: false,
        )) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isProcessing: true);
    final bioAvailable = await _repository.canCheckBiometrics();
    final bioEnabled = await _repository.isBiometricEnabled();

    state = state.copyWith(
      isBiometricAvailable: bioAvailable,
      isBiometricEnabled: bioEnabled,
      isProcessing: false,
    );

    // If biometric unlock is enabled and available, prompt automatically
    if (bioAvailable && bioEnabled) {
      authenticateBiometrics();
    }
  }

  Future<bool> unlockWithPassword(String password) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    final isValid = await _repository.validatePassword(password);
    if (isValid) {
      state = state.copyWith(
        isAuthenticated: true,
        isProcessing: false,
        clearError: true,
      );
      return true;
    } else {
      state = state.copyWith(
        isAuthenticated: false,
        errorMessage: 'Incorrect password. Please try again.',
        isProcessing: false,
      );
      return false;
    }
  }

  Future<bool> authenticateBiometrics() async {
    state = state.copyWith(isProcessing: true, clearError: true);
    final success = await _repository.authenticateBiometrics();
    if (success) {
      state = state.copyWith(
        isAuthenticated: true,
        isProcessing: false,
        clearError: true,
      );
      return true;
    } else {
      state = state.copyWith(
        isAuthenticated: false,
        errorMessage: 'Biometric verification failed or cancelled. Use password unlock.',
        isProcessing: false,
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final isValid = await _repository.validatePassword(currentPassword);
    if (!isValid) return false;
    await _repository.changePassword(newPassword);
    return true;
  }

  void lockApp() {
    state = state.copyWith(isAuthenticated: false, clearError: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
