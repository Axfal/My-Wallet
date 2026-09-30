import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/presentation/account_list_screen.dart';
import '../../accounts/data/account_model.dart';
import '../../accounts/providers/account_provider.dart';
import '../../analytics/services/analytics_calculator.dart';
import '../../loans/data/loan_models.dart';
import '../../loans/presentation/loans_screen.dart';
import '../../categories/providers/category_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/data/transaction_model.dart';
import '../../transactions/presentation/add_edit_transaction_screen.dart';
import '../../transactions/presentation/transaction_detail_screen.dart';
import '../../transactions/presentation/transaction_history_screen.dart';
import '../../transactions/providers/transaction_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final void Function(int index)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateRangeFilter _selectedPeriod = DateRangeFilter.thisMonth;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);
    final transactionState = ref.watch(transactionProvider);
    final categoryState = ref.watch(categoryProvider);
    final settingsState = ref.watch(settingsProvider);
    ref.watch(loanRevisionProvider);
    final loans = HiveService.loansBox.values
        .where((l) => !l.cancelled)
        .toList();
    final receivableMinor = loans
        .where((l) => l.type == LoanType.given)
        .fold<int>(0, (sum, l) => sum + l.outstandingAmountMinor);
    final payableMinor = loans
        .where((l) => l.type == LoanType.taken)
        .fold<int>(0, (sum, l) => sum + l.outstandingAmountMinor);
    final overdueCount = loans.where((l) => l.status == 'Overdue').length;
    final upcomingCount = loans
        .where(
          (l) =>
              l.outstandingAmountMinor > 0 &&
              l.dueAt.isAfter(DateTime.now()) &&
              l.dueAt.isBefore(DateTime.now().add(const Duration(days: 7))),
        )
        .length;

    // Calculate Analytics Report for selected period
    final report = AnalyticsCalculator.calculateReport(
      transactions: transactionState.transactions,
      accounts: accountState.accounts,
      categories: categoryState.categories,
      filter: _selectedPeriod,
      customRange: _customRange,
    );

    // Calculate This Month totals specifically
    final thisMonthReport = AnalyticsCalculator.calculateReport(
      transactions: transactionState.transactions,
      accounts: accountState.accounts,
      categories: categoryState.categories,
      filter: DateRangeFilter.thisMonth,
    );

    // Recent Transactions (top 5)
    final recentTransactions = transactionState.transactions.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'My Wallet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_balance_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Accounts & Wallets',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountListScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(accountProvider.notifier).loadAccounts();
          ref.read(transactionProvider.notifier).loadTransactions();
          ref.read(categoryProvider.notifier).loadCategories();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Range Filter Selector Header
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: DateRangeFilter.values.map((filter) {
                    final isSelected = _selectedPeriod == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          filter.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onSelected: (selected) async {
                          if (selected) {
                            if (filter == DateRangeFilter.custom) {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (range != null) {
                                setState(() {
                                  _selectedPeriod = filter;
                                  _customRange = range;
                                });
                              }
                            } else {
                              setState(() => _selectedPeriod = filter);
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Total Available Balance Banner
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Available Balance',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'OFFLINE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatMinor(
                        accountState.totalBalanceMinor,
                        symbol: settingsState.currencySymbol,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBalanceSummaryItem(
                            label: 'This Month Income',
                            amountMinor: thisMonthReport.totalIncomeMinor,
                            color: AppColors.incomeBg,
                            textColor: Colors.white,
                            currencySymbol: settingsState.currencySymbol,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildBalanceSummaryItem(
                            label: 'This Month Expense',
                            amountMinor: thisMonthReport.totalExpenseMinor,
                            color: AppColors.expenseBg,
                            textColor: Colors.white,
                            currencySymbol: settingsState.currencySymbol,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Selected Period Summary Grid (Income, Expense, Savings)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary (${_selectedPeriod.label})',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Income',
                            amountMinor: report.totalIncomeMinor,
                            icon: Icons.arrow_downward_rounded,
                            color: AppColors.income,
                            bgColor: AppColors.incomeBg,
                            currencySymbol: settingsState.currencySymbol,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Expenses',
                            amountMinor: report.totalExpenseMinor,
                            icon: Icons.arrow_upward_rounded,
                            color: AppColors.expense,
                            bgColor: AppColors.expenseBg,
                            currencySymbol: settingsState.currencySymbol,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Net Savings',
                            amountMinor: report.netSavingsMinor,
                            icon: Icons.savings_rounded,
                            color: report.netSavingsMinor >= 0
                                ? AppColors.primary
                                : AppColors.expense,
                            bgColor: AppColors.primaryLight,
                            currencySymbol: settingsState.currencySymbol,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Actions Bar
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.add_rounded,
                      label: 'Add Income',
                      color: AppColors.income,
                      bgColor: AppColors.incomeBg,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddEditTransactionScreen(
                              initialType: TransactionType.income,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.remove_rounded,
                      label: 'Add Expense',
                      color: AppColors.expense,
                      bgColor: AppColors.expenseBg,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddEditTransactionScreen(
                              initialType: TransactionType.expense,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.account_balance_rounded,
                      label: 'Add Account',
                      color: AppColors.primary,
                      bgColor: AppColors.primaryLight,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AccountListScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Income vs Expense Chart Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loans & people',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'People owe me: ${CurrencyFormatter.formatMinor(receivableMinor, symbol: settingsState.currencySymbol)}',
                      ),
                      Text(
                        'I owe others: ${CurrencyFormatter.formatMinor(payableMinor, symbol: settingsState.currencySymbol)}',
                      ),
                      Text('$overdueCount overdue loans'),
                      Text('$upcomingCount due in the next 7 days'),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoanFormScreen(),
                              ),
                            ),
                            child: const Text('Give / take loan'),
                          ),
                          TextButton(
                            onPressed: () => widget.onNavigateTab?.call(1),
                            child: const Text('View loans'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Income vs Expenses',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            _buildLegendItem('Income', AppColors.income),
                            const SizedBox(width: 12),
                            _buildLegendItem('Expense', AppColors.expense),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 180,
                      child: report.timeSeriesData.isEmpty
                          ? Center(
                              child: Text(
                                'No chart data for selected range',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          : BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: _calculateMaxY(report.timeSeriesData),
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, meta) {
                                        final index = val.toInt();
                                        if (index >= 0 &&
                                            index <
                                                report.timeSeriesData.length) {
                                          final label = report
                                              .timeSeriesData[index]
                                              .label;
                                          // Short label
                                          final parts = label.split(' ');
                                          final shortLabel = parts.length > 1
                                              ? parts[0]
                                              : label;
                                          return Text(
                                            shortLabel,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: report.timeSeriesData
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      final i = entry.key;
                                      final p = entry.value;
                                      final incVal = p.incomeMinor / 100.0;
                                      final expVal = p.expenseMinor / 100.0;

                                      return BarChartGroupData(
                                        x: i,
                                        barRods: [
                                          BarChartRodData(
                                            toY: incVal,
                                            color: AppColors.income,
                                            width: 10,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          BarChartRodData(
                                            toY: expVal,
                                            color: AppColors.expense,
                                            width: 10,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ],
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Accounts Overview Header & Cards Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Accounts & Wallets',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountListScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'View All (${accountState.accounts.length})',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (accountState.accounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Center(
                    child: Text(
                      'No accounts created yet. Tap + Add Account above.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 156,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: accountState.accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final acc = accountState.accounts[index];
                      final accColor = Color.lerp(
                        AppColors.primary,
                        Color(acc.colorValue),
                        0.18,
                      )!;

                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AccountListScreen(),
                          ),
                        ),
                        child: Container(
                          width: 242,
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accColor,
                                AppColors.primary.withValues(alpha: 0.94),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.17,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      IconData(
                                        acc.iconCodePoint,
                                        fontFamily: 'MaterialIcons',
                                      ),
                                      color: Colors.white,
                                      size: 21,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      acc.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_outward_rounded,
                                    size: 17,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AVAILABLE BALANCE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      letterSpacing: 1.1,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    CurrencyFormatter.formatMinor(
                                      acc.balanceMinor,
                                      symbol: settingsState.currencySymbol,
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    acc.providerName.isEmpty
                                        ? acc.type.label
                                        : acc.providerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),

              // Recent Transactions Header & List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TransactionHistoryScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (recentTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Center(
                    child: Text(
                      'No transactions yet. Record your first transaction.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTransactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final t = recentTransactions[index];
                    final isIncome = t.type == TransactionType.income;

                    final cat = categoryState.categories
                        .where((c) => c.id == t.categoryId)
                        .firstOrNull;

                    final acc = accountState.accounts
                        .where((a) => a.id == t.accountId)
                        .firstOrNull;

                    final catColor = cat != null
                        ? Color(cat.colorValue)
                        : AppColors.primary;

                    return Container(
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
                              builder: (_) =>
                                  TransactionDetailScreen(transaction: t),
                            ),
                          );
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            cat?.iconData ?? Icons.category_rounded,
                            color: catColor,
                            size: 20,
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
                        subtitle: Text(
                          t.isSplitPayment ? '${t.effectiveAllocations.length} accounts'
                              : acc?.name ?? 'Unknown Account',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isIncome ? '+' : '-'}${CurrencyFormatter.formatMinor(t.amountMinor, symbol: settingsState.currencySymbol)}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isIncome
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                            Text(
                              AppDateUtils.formatDate(t.dateTime),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSummaryItem({
    required String label,
    required int amountMinor,
    required Color color,
    required Color textColor,
    required String currencySymbol,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.formatMinor(amountMinor, symbol: currencySymbol),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int amountMinor,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String currencySymbol,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatMinor(amountMinor, symbol: currencySymbol),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  double _calculateMaxY(List<TimeSeriesPoint> points) {
    double max = 100.0;
    for (final p in points) {
      if (p.incomeMinor / 100.0 > max) max = p.incomeMinor / 100.0;
      if (p.expenseMinor / 100.0 > max) max = p.expenseMinor / 100.0;
    }
    return max * 1.2;
  }
}
