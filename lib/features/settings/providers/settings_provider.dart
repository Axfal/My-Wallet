import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_repository.dart';

class SettingsState {
  final String currencySymbol;
  final bool allowNegativeBalance;
  final bool biometricEnabled;
  final bool isLoading;

  SettingsState({
    required this.currencySymbol,
    required this.allowNegativeBalance,
    required this.biometricEnabled,
    this.isLoading = false,
  });

  SettingsState copyWith({
    String? currencySymbol,
    bool? allowNegativeBalance,
    bool? biometricEnabled,
    bool? isLoading,
  }) {
    return SettingsState(
      currencySymbol: currencySymbol ?? this.currencySymbol,
      allowNegativeBalance: allowNegativeBalance ?? this.allowNegativeBalance,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository)
      : super(SettingsState(
          currencySymbol: '₨',
          allowNegativeBalance: false,
          biometricEnabled: false,
          isLoading: true,
        )) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final symbol = _repository.getCurrencySymbol();
    final allowNeg = _repository.getAllowNegativeBalance();
    final bioEnabled = await _repository.isBiometricEnabled();

    state = SettingsState(
      currencySymbol: symbol,
      allowNegativeBalance: allowNeg,
      biometricEnabled: bioEnabled,
      isLoading: false,
    );
  }

  Future<void> updateCurrencySymbol(String symbol) async {
    await _repository.setCurrencySymbol(symbol);
    state = state.copyWith(currencySymbol: symbol);
  }

  Future<void> toggleAllowNegativeBalance(bool allow) async {
    await _repository.setAllowNegativeBalance(allow);
    state = state.copyWith(allowNegativeBalance: allow);
  }

  Future<void> toggleBiometricEnabled(bool enabled) async {
    await _repository.setBiometricEnabled(enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});
