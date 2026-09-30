import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../data/transaction_model.dart';
import '../data/transaction_repository.dart';

enum TransactionSortOption {
  newest,
  oldest,
  highestAmount,
  lowestAmount,
}

extension TransactionSortOptionExtension on TransactionSortOption {
  String get label {
    switch (this) {
      case TransactionSortOption.newest:
        return 'Newest First';
      case TransactionSortOption.oldest:
        return 'Oldest First';
      case TransactionSortOption.highestAmount:
        return 'Highest Amount';
      case TransactionSortOption.lowestAmount:
        return 'Lowest Amount';
    }
  }
}

class TransactionState {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? searchQuery;
  final TransactionType? typeFilter;
  final DateRangeFilter dateFilter;
  final DateTimeRange? customDateRange;
  final String? categoryFilterId;
  final String? accountFilterId;
  final TransactionSortOption sortOption;

  TransactionState({
    required this.transactions,
    this.isLoading = false,
    this.searchQuery,
    this.typeFilter,
    this.dateFilter = DateRangeFilter.thisMonth,
    this.customDateRange,
    this.categoryFilterId,
    this.accountFilterId,
    this.sortOption = TransactionSortOption.newest,
  });

  List<TransactionModel> getFilteredTransactions({
    required WidgetRef ref,
  }) {
    final accountNotifier = ref.watch(accountProvider);
    final categoryNotifier = ref.watch(categoryProvider);

    final range = AppDateUtils.getRangeForFilter(dateFilter, customRange: customDateRange);

    final list = transactions.where((t) {
      // Type Filter
      if (typeFilter != null && t.type != typeFilter) return false;

      // Account Filter
      if (accountFilterId != null &&
          !t.effectiveAllocations.any((a) => a.accountId == accountFilterId)) return false;

      // Category Filter
      if (categoryFilterId != null && t.categoryId != categoryFilterId) return false;

      // Date Range Filter
      if (!AppDateUtils.isDateInRange(t.dateTime, range)) return false;

      // Search Query Filter
      if (searchQuery != null && searchQuery!.isNotEmpty) {
        final query = searchQuery!.toLowerCase();
        final noteMatch = t.note?.toLowerCase().contains(query) ?? false;
        final amountMatch = CurrencyFormatter.minorToAmount(t.amountMinor)
            .toString()
            .contains(query);

        // Account Name match
        final accountMatch = t.effectiveAllocations.any((part) => accountNotifier.accounts
            .any((a) => a.id == part.accountId && a.name.toLowerCase().contains(query)));

        // Category Name match
        final category = categoryNotifier.categories
            .where((c) => c.id == t.categoryId)
            .firstOrNull;
        final categoryMatch = category?.name.toLowerCase().contains(query) ?? false;

        return noteMatch || amountMatch || accountMatch || categoryMatch;
      }

      return true;
    }).toList();

    // Sorting
    switch (sortOption) {
      case TransactionSortOption.newest:
        list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        break;
      case TransactionSortOption.oldest:
        list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        break;
      case TransactionSortOption.highestAmount:
        list.sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
        break;
      case TransactionSortOption.lowestAmount:
        list.sort((a, b) => a.amountMinor.compareTo(b.amountMinor));
        break;
    }

    return list;
  }

  TransactionState copyWith({
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? searchQuery,
    bool clearSearchQuery = false,
    TransactionType? typeFilter,
    bool clearTypeFilter = false,
    DateRangeFilter? dateFilter,
    DateTimeRange? customDateRange,
    bool clearCustomDateRange = false,
    String? categoryFilterId,
    bool clearCategoryFilterId = false,
    String? accountFilterId,
    bool clearAccountFilterId = false,
    TransactionSortOption? sortOption,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      dateFilter: dateFilter ?? this.dateFilter,
      customDateRange: clearCustomDateRange ? null : (customDateRange ?? this.customDateRange),
      categoryFilterId: clearCategoryFilterId ? null : (categoryFilterId ?? this.categoryFilterId),
      accountFilterId: clearAccountFilterId ? null : (accountFilterId ?? this.accountFilterId),
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  final TransactionRepository _repository;
  final Ref _ref;

  TransactionNotifier(this._repository, this._ref)
      : super(TransactionState(transactions: [], isLoading: true)) {
    loadTransactions();
  }

  void loadTransactions() {
    final list = _repository.getAllTransactions();
    state = state.copyWith(transactions: list, isLoading: false);
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await _repository.addTransaction(transaction);
    loadTransactions();
    // Refresh Account balance provider
    _ref.read(accountProvider.notifier).loadAccounts();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await _repository.updateTransaction(transaction);
    loadTransactions();
    // Refresh Account balance provider
    _ref.read(accountProvider.notifier).loadAccounts();
  }

  Future<void> deleteTransaction(String id) async {
    await _repository.deleteTransaction(id);
    loadTransactions();
    // Refresh Account balance provider
    _ref.read(accountProvider.notifier).loadAccounts();
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(
      searchQuery: query,
      clearSearchQuery: query == null || query.isEmpty,
    );
  }

  void setTypeFilter(TransactionType? type) {
    state = state.copyWith(
      typeFilter: type,
      clearTypeFilter: type == null,
    );
  }

  void setDateFilter(DateRangeFilter filter, {DateTimeRange? customRange}) {
    state = state.copyWith(
      dateFilter: filter,
      customDateRange: customRange,
      clearCustomDateRange: filter != DateRangeFilter.custom,
    );
  }

  void setCategoryFilter(String? categoryId) {
    state = state.copyWith(
      categoryFilterId: categoryId,
      clearCategoryFilterId: categoryId == null,
    );
  }

  void setAccountFilter(String? accountId) {
    state = state.copyWith(
      accountFilterId: accountId,
      clearAccountFilterId: accountId == null,
    );
  }

  void setSortOption(TransactionSortOption sort) {
    state = state.copyWith(sortOption: sort);
  }

  void resetFilters() {
    state = TransactionState(
      transactions: state.transactions,
      isLoading: false,
    );
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return TransactionNotifier(repo, ref);
});
