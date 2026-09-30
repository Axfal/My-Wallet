import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/account_model.dart';
import '../data/account_repository.dart';

class AccountState {
  final List<AccountModel> accounts;
  final bool isLoading;
  final String? searchQuery;
  final AccountType? typeFilter;

  AccountState({
    required this.accounts,
    this.isLoading = false,
    this.searchQuery,
    this.typeFilter,
  });

  List<AccountModel> get filteredAccounts {
    return accounts.where((acc) {
      if (typeFilter != null && acc.type != typeFilter) {
        return false;
      }
      if (searchQuery != null && searchQuery!.isNotEmpty) {
        final query = searchQuery!.toLowerCase();
        final matchesName = acc.name.toLowerCase().contains(query);
        final matchesProvider = acc.providerName.toLowerCase().contains(query);
        final matchesNumber = acc.accountNumber?.toLowerCase().contains(query) ?? false;
        return matchesName || matchesProvider || matchesNumber;
      }
      return true;
    }).toList();
  }

  int get totalBalanceMinor {
    int total = 0;
    for (final acc in accounts) {
      total += acc.balanceMinor;
    }
    return total;
  }

  AccountState copyWith({
    List<AccountModel>? accounts,
    bool? isLoading,
    String? searchQuery,
    bool clearSearchQuery = false,
    AccountType? typeFilter,
    bool clearTypeFilter = false,
  }) {
    return AccountState(
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
    );
  }
}

class AccountNotifier extends StateNotifier<AccountState> {
  final AccountRepository _repository;

  AccountNotifier(this._repository)
      : super(AccountState(accounts: [], isLoading: true)) {
    loadAccounts();
  }

  void loadAccounts() {
    final list = _repository.getAllAccounts();
    state = state.copyWith(accounts: list, isLoading: false);
  }

  Future<void> addOrUpdateAccount(AccountModel account) async {
    await _repository.saveAccount(account);
    loadAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await _repository.deleteAccount(id);
    loadAccounts();
  }

  Future<void> adjustBalance(String accountId, int deltaMinor) async {
    await _repository.adjustAccountBalance(accountId, deltaMinor);
    loadAccounts();
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(
      searchQuery: query,
      clearSearchQuery: query == null || query.isEmpty,
    );
  }

  void setTypeFilter(AccountType? type) {
    state = state.copyWith(
      typeFilter: type,
      clearTypeFilter: type == null,
    );
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository();
});

final accountProvider =
    StateNotifierProvider<AccountNotifier, AccountState>((ref) {
  final repo = ref.watch(accountRepositoryProvider);
  return AccountNotifier(repo);
});
