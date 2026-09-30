import 'package:hive/hive.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/secure_storage_service.dart';
import 'app_settings_model.dart';

class SettingsRepository {
  final Box<dynamic> _box;
  final SecureStorageService _secureStorage;
  final Box<AppSettings>? _typedBox;

  static const String keyCurrencySymbol = 'currency_symbol';
  static const String keyAllowNegativeBalance = 'allow_negative_balance';

  SettingsRepository({
    Box<dynamic>? box,
    SecureStorageService? secureStorage,
  })  : _box = box ?? HiveService.settingsBox,
        _typedBox = box == null ? HiveService.appSettingsBox : null,
        _secureStorage = secureStorage ?? SecureStorageService();

  String getCurrencySymbol() {
    return _typedBox?.get('settings')?.currencySymbol ??
        _box.get(keyCurrencySymbol, defaultValue: '₨') as String;
  }

  Future<void> setCurrencySymbol(String symbol) async {
    if (_typedBox == null) { await _box.put(keyCurrencySymbol, symbol); return; }
    final settings = _typedBox.get('settings') ?? AppSettings(
      currencySymbol: getCurrencySymbol(), allowNegativeBalance: getAllowNegativeBalance(),
      updatedAt: DateTime.now());
    await _typedBox.put('settings', settings.copyWith(currencySymbol: symbol));
  }

  bool getAllowNegativeBalance() {
    return _typedBox?.get('settings')?.allowNegativeBalance ??
        _box.get(keyAllowNegativeBalance, defaultValue: false) as bool;
  }

  Future<void> setAllowNegativeBalance(bool allow) async {
    if (_typedBox == null) { await _box.put(keyAllowNegativeBalance, allow); return; }
    final settings = _typedBox.get('settings') ?? AppSettings(
      currencySymbol: getCurrencySymbol(), allowNegativeBalance: getAllowNegativeBalance(),
      updatedAt: DateTime.now());
    await _typedBox.put('settings', settings.copyWith(allowNegativeBalance: allow));
  }

  Future<bool> isBiometricEnabled() async {
    return await _secureStorage.isBiometricEnabled();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.setBiometricEnabled(enabled);
  }
}
