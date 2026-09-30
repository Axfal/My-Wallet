import 'package:hive/hive.dart';
import '../../../core/services/hive_service.dart';
import 'account_model.dart';

class AccountRepository {
  final Box<AccountModel> _box;

  AccountRepository({Box<AccountModel>? box})
      : _box = box ?? HiveService.accountsBox;

  List<AccountModel> getAllAccounts() {
    final list = _box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  AccountModel? getAccountById(String id) {
    try {
      return _box.values.firstWhere((acc) => acc.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAccount(AccountModel account) async {
    await _box.put(account.id, account);
  }

  Future<void> deleteAccount(String id) async {
    if (HiveService.transactionsBox.values.any((t) => t.effectiveAllocations.any((a) => a.accountId == id)) ||
        HiveService.loansBox.values.any((l) => l.accountId == id) ||
        HiveService.repaymentsBox.values.any((p) => p.accountId == id)) {
      throw StateError('Account has linked transactions or loans');
    }
    await _box.delete(id);
  }

  int getTotalBalanceMinor() {
    int total = 0;
    for (final acc in _box.values) {
      total += acc.balanceMinor;
    }
    return total;
  }

  /// Adjusts the balance of an account safely by deltaMinor (positive for add, negative for subtract).
  Future<AccountModel?> adjustAccountBalance(String id, int deltaMinor) async {
    final account = getAccountById(id);
    if (account == null) throw StateError('Account no longer exists');

    final updatedAccount = account.copyWith(
      balanceMinor: account.balanceMinor + deltaMinor,
      updatedAt: DateTime.now(),
    );

    await saveAccount(updatedAccount);
    return updatedAccount;
  }
}
