import 'package:hive/hive.dart';
import '../../../core/services/hive_service.dart';
import '../../accounts/data/account_repository.dart';
import '../../settings/data/settings_repository.dart';
import 'transaction_model.dart';

class TransactionRepository {
  final Box<TransactionModel> _box;
  final AccountRepository _accounts;
  final SettingsRepository _settings;

  TransactionRepository({Box<TransactionModel>? box, AccountRepository? accountRepo,
    SettingsRepository? settingsRepo})
      : _box = box ?? HiveService.transactionsBox,
        _accounts = accountRepo ?? AccountRepository(),
        _settings = settingsRepo ?? SettingsRepository();

  List<TransactionModel> getAllTransactions() => _box.values.toList()
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  TransactionModel? getTransactionById(String id) => _box.get(id);
  List<TransactionModel> getTransactionsForAccount(String accountId) =>
    getAllTransactions().where((t) => t.effectiveAllocations.any((a) => a.accountId == accountId)).toList();
  List<TransactionModel> getTransactionsForCategory(String categoryId) =>
    getAllTransactions().where((t) => t.categoryId == categoryId).toList();

  void _validate(TransactionModel transaction) {
    if (transaction.amountMinor <= 0) throw ArgumentError('Amount must be positive');
    final parts = transaction.effectiveAllocations;
    if (parts.any((p) => p.amountMinor <= 0) ||
        parts.map((p) => p.accountId).toSet().length != parts.length ||
        parts.fold<int>(0, (sum, p) => sum + p.amountMinor) != transaction.amountMinor ||
        transaction.accountId != parts.first.accountId) {
      throw ArgumentError('Payment parts must use different accounts and add up to the transaction amount');
    }
    for (final p in parts) {
      if (_accounts.getAccountById(p.accountId) == null) {
        throw StateError('Selected account no longer exists');
      }
    }
  }

  Map<String, int> _deltas(TransactionModel? old, TransactionModel? replacement) {
    final deltas = <String, int>{};
    void add(TransactionModel? t, int direction) {
      if (t == null) return;
      for (final part in t.effectiveAllocations) {
        final effect = t.type == TransactionType.income ? part.amountMinor : -part.amountMinor;
        deltas.update(part.accountId, (v) => v + effect * direction,
          ifAbsent: () => effect * direction);
      }
    }
    add(old, -1);
    add(replacement, 1);
    for (final entry in deltas.entries) {
      final account = _accounts.getAccountById(entry.key);
      if (account == null) throw StateError('Selected account no longer exists');
      if (!_settings.getAllowNegativeBalance() && account.balanceMinor + entry.value < 0) {
        throw StateError('Insufficient funds in ${account.name}');
      }
    }
    return deltas;
  }

  /// Validate every allocation before writing; restore both boxes on failure.
  /// Startup reconciliation repairs a process interrupted between box writes.
  Future<void> _save(TransactionModel transaction, {required bool editing}) async {
    _validate(transaction);
    final old = _box.get(transaction.id);
    if (editing && old == null) throw StateError('Transaction not found');
    if (!editing && old != null) throw StateError('Transaction already exists');
    final deltas = _deltas(old, transaction);
    final snapshots = {for (final id in deltas.keys) id: _accounts.getAccountById(id)!};
    try {
      await _box.put(transaction.id, transaction);
      for (final entry in deltas.entries) {
        final account = snapshots[entry.key]!;
        await _accounts.saveAccount(account.copyWith(
          balanceMinor: account.balanceMinor + entry.value, updatedAt: DateTime.now()));
      }
    } catch (_) {
      if (old == null) { await _box.delete(transaction.id); }
      else { await _box.put(old.id, old); }
      for (final account in snapshots.values) { await _accounts.saveAccount(account); }
      rethrow;
    }
  }

  Future<void> addTransaction(TransactionModel transaction) => _save(transaction, editing: false);
  Future<void> updateTransaction(TransactionModel transaction) => _save(transaction, editing: true);

  Future<void> deleteTransaction(String id) async {
    final old = _box.get(id);
    if (old == null) return;
    final deltas = _deltas(old, null);
    final snapshots = {for (final accountId in deltas.keys) accountId: _accounts.getAccountById(accountId)!};
    try {
      await _box.delete(id);
      for (final entry in deltas.entries) {
        final account = snapshots[entry.key]!;
        await _accounts.saveAccount(account.copyWith(
          balanceMinor: account.balanceMinor + entry.value, updatedAt: DateTime.now()));
      }
    } catch (_) {
      await _box.put(id, old);
      for (final account in snapshots.values) { await _accounts.saveAccount(account); }
      rethrow;
    }
  }
}
