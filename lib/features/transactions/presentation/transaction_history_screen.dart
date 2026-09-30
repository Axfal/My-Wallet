import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../loans/data/loan_models.dart';
import '../../loans/presentation/loans_screen.dart';
import '../data/transaction_model.dart';
import '../providers/transaction_provider.dart';
import 'add_edit_transaction_screen.dart';
import 'transaction_detail_screen.dart';
import 'ledger_export_screen.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  void _showFilterModal(BuildContext context, WidgetRef ref) {
    final transactionNotifier = ref.read(transactionProvider.notifier);
    final state = ref.watch(transactionProvider);
    final accountState = ref.watch(accountProvider);
    final categoryState = ref.watch(categoryProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter & Sort Transactions',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          transactionNotifier.resetFilters();
                          Navigator.of(ctx).pop();
                        },
                        child: Text(
                          'Reset',
                          style: GoogleFonts.inter(
                            color: AppColors.expense,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sort By
                  Text(
                    'Sort By',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: TransactionSortOption.values.map((sort) {
                      final isSelected = state.sortOption == sort;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          sort.label,
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        selectedColor: AppColors.primaryLight,
                        onSelected: (_) =>
                            transactionNotifier.setSortOption(sort),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Date Range Filter
                  Text(
                    'Date Range',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: DateRangeFilter.values.map((filter) {
                      final isSelected = state.dateFilter == filter;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          filter.label,
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        selectedColor: AppColors.primaryLight,
                        onSelected: (_) async {
                          if (filter == DateRangeFilter.custom) {
                            final range = await showDateRangePicker(
                              context: ctx,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (range != null) {
                              transactionNotifier.setDateFilter(
                                filter,
                                customRange: range,
                              );
                            }
                          } else {
                            transactionNotifier.setDateFilter(filter);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Category Filter
                  Text(
                    'Category',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: state.categoryFilterId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.cardBorder,
                        ),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ...categoryState.categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }),
                    ],
                    onChanged: (val) =>
                        transactionNotifier.setCategoryFilter(val),
                  ),
                  const SizedBox(height: 16),

                  // Account Filter
                  Text(
                    'Account',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: state.accountFilterId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.cardBorder,
                        ),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Accounts'),
                      ),
                      ...accountState.accounts.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        );
                      }),
                    ],
                    onChanged: (val) =>
                        transactionNotifier.setAccountFilter(val),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionState = ref.watch(transactionProvider);
    final categoryNotifier = ref.watch(categoryProvider);
    final accountNotifier = ref.watch(accountProvider);
    final settingsState = ref.watch(settingsProvider);
    ref.watch(loanRevisionProvider);
    final loanMovements =
        <
          ({
            String loanId,
            DateTime date,
            String label,
            int amount,
            String accountId,
          })
        >[
          for (final l in HiveService.loansBox.values)
            (
              loanId: l.id,
              date: l.issuedAt,
              label: l.type == LoanType.given ? 'Loan Given' : 'Loan Taken',
              amount: l.originalAmountMinor,
              accountId: l.accountId,
            ),
          for (final p in HiveService.repaymentsBox.values)
            if (HiveService.loansBox.get(p.loanId) case final Loan l)
              (
                loanId: l.id,
                date: p.paidAt,
                label: l.type == LoanType.given
                    ? 'Loan Repayment Received'
                    : 'Loan Repayment Paid',
                amount: p.amountMinor,
                accountId: p.accountId,
              ),
        ];
    final range = AppDateUtils.getRangeForFilter(
      transactionState.dateFilter,
      customRange: transactionState.customDateRange,
    );
    loanMovements.removeWhere((m) {
      if (!AppDateUtils.isDateInRange(m.date, range)) return true;
      if (transactionState.accountFilterId != null &&
          m.accountId != transactionState.accountFilterId)
        return true;
      final loan = HiveService.loansBox.get(m.loanId);
      final person = loan == null
          ? null
          : HiveService.peopleBox.get(loan.personId);
      final account = accountNotifier.accounts
          .where((a) => a.id == m.accountId)
          .firstOrNull;
      final query = transactionState.searchQuery?.toLowerCase().trim() ?? '';
      return query.isNotEmpty &&
          !'${m.label} ${m.amount / 100} ${person?.fullName} ${person?.phoneNumber} ${loan?.note} ${account?.name}'
              .toLowerCase()
              .contains(query);
    });
    switch (transactionState.sortOption) {
      case TransactionSortOption.newest:
        loanMovements.sort((a, b) => b.date.compareTo(a.date));
      case TransactionSortOption.oldest:
        loanMovements.sort((a, b) => a.date.compareTo(b.date));
      case TransactionSortOption.highestAmount:
        loanMovements.sort((a, b) => b.amount.compareTo(a.amount));
      case TransactionSortOption.lowestAmount:
        loanMovements.sort((a, b) => a.amount.compareTo(b.amount));
    }

    final filtered = transactionState.getFilteredTransactions(ref: ref);

    // Group transactions by day header
    final Map<String, List<TransactionModel>> grouped = {};
    for (final t in filtered) {
      final header = AppDateUtils.formatDayHeader(t.dateTime);
      grouped.putIfAbsent(header, () => []).add(t);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export ledger',
            icon: const Icon(Icons.download_rounded, color: AppColors.primary),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LedgerExportScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
            onPressed: () => _showFilterModal(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'history_add',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditTransactionScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Transaction',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Quick Type Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Column(
              children: [
                TextField(
                  onChanged: (q) =>
                      ref.read(transactionProvider.notifier).setSearchQuery(q),
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search note, category, account or amount...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.cardBorder,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Type Chips: All, Income, Expense
                Row(
                  children: [
                    FilterChip(
                      selected: transactionState.typeFilter == null,
                      label: Text(
                        'All',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      onSelected: (_) => ref
                          .read(transactionProvider.notifier)
                          .setTypeFilter(null),
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected:
                          transactionState.typeFilter == TransactionType.income,
                      label: Text(
                        'Income',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      onSelected: (_) => ref
                          .read(transactionProvider.notifier)
                          .setTypeFilter(
                            transactionState.typeFilter ==
                                    TransactionType.income
                                ? null
                                : TransactionType.income,
                          ),
                      selectedColor: AppColors.incomeBg,
                      checkmarkColor: AppColors.income,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected:
                          transactionState.typeFilter ==
                          TransactionType.expense,
                      label: Text(
                        'Expense',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      onSelected: (_) => ref
                          .read(transactionProvider.notifier)
                          .setTypeFilter(
                            transactionState.typeFilter ==
                                    TransactionType.expense
                                ? null
                                : TransactionType.expense,
                          ),
                      selectedColor: AppColors.expenseBg,
                      checkmarkColor: AppColors.expense,
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} items',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (loanMovements.isNotEmpty && transactionState.typeFilter == null)
            SizedBox(
              height: 170,
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'Loan movements',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...loanMovements.map((m) {
                    final l = HiveService.loansBox.get(m.loanId);
                    final p = l == null
                        ? null
                        : HiveService.peopleBox.get(l.personId);
                    final a = accountNotifier.accounts
                        .where((a) => a.id == m.accountId)
                        .firstOrNull;
                    return ListTile(
                      dense: true,
                      title: Text('${m.label} · ${p?.fullName ?? ''}'),
                      subtitle: Text(
                        '${a?.name ?? ''} · ${m.date.day}/${m.date.month}/${m.date.year}',
                      ),
                      trailing: Text(
                        CurrencyFormatter.formatMinor(
                          m.amount,
                          symbol: settingsState.currencySymbol,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoanDetailScreen(id: m.loanId),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Transactions Recorded',
                    subtitle:
                        'Tap the + button to add your first income or expense transaction.',
                    actionText: 'Add Transaction',
                    onAction: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddEditTransactionScreen(),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: 80,
                    ),
                    itemCount: grouped.keys.length,
                    itemBuilder: (context, groupIndex) {
                      final dayHeader = grouped.keys.elementAt(groupIndex);
                      final dayTransactions = grouped[dayHeader]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Text(
                              dayHeader,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          ...dayTransactions.map((t) {
                            final isIncome = t.type == TransactionType.income;

                            final cat = categoryNotifier.categories
                                .where((c) => c.id == t.categoryId)
                                .firstOrNull;

                            final acc = accountNotifier.accounts
                                .where((a) => a.id == t.accountId)
                                .firstOrNull;

                            final catColor = cat != null
                                ? Color(cat.colorValue)
                                : AppColors.primary;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.cardBorder),
                                boxShadow: AppColors.softShadow,
                              ),
                              child: ListTile(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TransactionDetailScreen(
                                        transaction: t,
                                      ),
                                    ),
                                  );
                                },
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    cat?.iconData ?? Icons.category_rounded,
                                    color: catColor,
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  cat?.name ?? 'Unknown Category',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    if (t.proofPath != null)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.attach_file,
                                          size: 14,
                                        ),
                                      ),
                                    Text(
                                      acc?.name ?? 'Unknown Account',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (t.note != null &&
                                        t.note!.isNotEmpty) ...[
                                      const Text(' • '),
                                      Expanded(
                                        child: Text(
                                          t.note!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isIncome ? '+' : '-'}${CurrencyFormatter.formatMinor(t.amountMinor, symbol: settingsState.currencySymbol)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isIncome
                                            ? AppColors.income
                                            : AppColors.expense,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppDateUtils.formatTime(t.dateTime),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
