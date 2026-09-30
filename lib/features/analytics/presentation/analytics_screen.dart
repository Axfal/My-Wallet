import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../accounts/providers/account_provider.dart';
import '../../analytics/services/analytics_calculator.dart';
import '../../categories/providers/category_provider.dart';
import '../../loans/data/loan_models.dart';
import '../../loans/presentation/loans_screen.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/providers/transaction_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  DateRangeFilter _selectedPeriod = DateRangeFilter.thisMonth;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);
    final transactionState = ref.watch(transactionProvider);
    final categoryState = ref.watch(categoryProvider);
    final settingsState = ref.watch(settingsProvider);
    ref.watch(loanRevisionProvider);
    final openLoans = HiveService.loansBox.values.where((l) => !l.cancelled);
    final receivable = openLoans.where((l) => l.type == LoanType.given)
        .fold<int>(0, (sum,l) => sum + l.outstandingAmountMinor);
    final payable = openLoans.where((l) => l.type == LoanType.taken)
        .fold<int>(0, (sum,l) => sum + l.outstandingAmountMinor);

    final report = AnalyticsCalculator.calculateReport(
      transactions: transactionState.transactions,
      accounts: accountState.accounts,
      categories: categoryState.categories,
      filter: _selectedPeriod,
      customRange: _customRange,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Analytics & Reports',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Financial position', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Receivables: ${CurrencyFormatter.formatMinor(receivable, symbol: settingsState.currencySymbol)}'),
                Text('Payables: ${CurrencyFormatter.formatMinor(payable, symbol: settingsState.currencySymbol)}'),
              ]))),
            // Date Filter Selector
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
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
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

            // Top Key Metrics Overview
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Total Income',
                          amountMinor: report.totalIncomeMinor,
                          color: AppColors.income,
                          symbol: settingsState.currencySymbol,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Total Expense',
                          amountMinor: report.totalExpenseMinor,
                          color: AppColors.expense,
                          symbol: settingsState.currencySymbol,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Net Savings',
                          amountMinor: report.netSavingsMinor,
                          color: report.netSavingsMinor >= 0
                              ? AppColors.primary
                              : AppColors.expense,
                          symbol: settingsState.currencySymbol,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.cardBorder),

                  // Daily & Monthly Averages
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAvgColumn('Avg Daily Income', report.averageDailyIncome, settingsState.currencySymbol),
                      _buildAvgColumn('Avg Daily Expense', report.averageDailyExpense, settingsState.currencySymbol),
                      _buildAvgColumn('Avg Monthly Expense', report.averageMonthlyExpense, settingsState.currencySymbol),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Income & Expense Trend Line Chart
            if (report.totalIncomeMinor != 0 || report.totalExpenseMinor != 0) ...[
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Income vs expense', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(height: 145, child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                        getTitlesWidget: (value, meta) => Text(value == 0 ? 'Income' : 'Expense',
                          style: const TextStyle(fontSize: 11)))),
                    ),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: report.totalIncomeMinor.toDouble(), color: AppColors.income, width: 30)]),
                      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: report.totalExpenseMinor.toDouble(), color: AppColors.expense, width: 30)]),
                    ],
                  ))),
                ]))),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(18),
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
                    'Income vs Expense Trend',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monthly and daily financial trajectory',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: report.timeSeriesData.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.show_chart_rounded,
                            title: 'No Data',
                            subtitle: 'No trend data available for this range.',
                          )
                        : LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: FlTitlesData(
                                show: true,
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (val, meta) {
                                      final idx = val.toInt();
                                      if (idx >= 0 && idx < report.timeSeriesData.length) {
                                        final label = report.timeSeriesData[idx].label;
                                        final parts = label.split(' ');
                                        return Text(
                                          parts[0],
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                // Income Line
                                LineChartBarData(
                                  spots: report.timeSeriesData
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(e.key.toDouble(), e.value.incomeMinor / 100.0))
                                      .toList(),
                                  isCurved: true,
                                  color: AppColors.income,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                ),
                                // Expense Line
                                LineChartBarData(
                                  spots: report.timeSeriesData
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(e.key.toDouble(), e.value.expenseMinor / 100.0))
                                      .toList(),
                                  isCurved: true,
                                  color: AppColors.expense,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Expense Breakdown by Category
            Container(
              padding: const EdgeInsets.all(18),
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
                    'Expenses by Category',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (report.expenseByCategory.isEmpty)
                    const EmptyStateWidget(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'No Expenses',
                      subtitle: 'No expense transactions recorded in this period.',
                    )
                  else
                    Column(
                      children: [
                        SizedBox(height: 180, child: PieChart(PieChartData(
                          centerSpaceRadius: 48,
                          sectionsSpace: 2,
                          sections: report.expenseByCategory.map((item) => PieChartSectionData(
                            value: item.totalAmountMinor.toDouble(),
                            color: Color(item.category.colorValue),
                            radius: 28,
                            showTitle: false,
                          )).toList(),
                        ))),
                        const SizedBox(height: 12),
                        ...report.expenseByCategory.map((catSummary) {
                        final catColor = Color(catSummary.category.colorValue);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(catSummary.category.iconData, size: 18, color: catColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    catSummary.category.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${CurrencyFormatter.formatMinor(catSummary.totalAmountMinor, symbol: settingsState.currencySymbol)} (${catSummary.percentage.toStringAsFixed(1)}%)',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (catSummary.percentage / 100.0).clamp(0.0, 1.0),
                                  backgroundColor: AppColors.cardBorder,
                                  valueColor: AlwaysStoppedAnimation<Color>(catColor),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Account Balance Distribution
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Income by category', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (report.incomeByCategory.isEmpty) const Text('No income in this period'),
                ...report.incomeByCategory.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 9), child: Row(children: [
                    Expanded(child: Text(item.category.name)),
                    Text(CurrencyFormatter.formatMinor(item.totalAmountMinor,
                      symbol: settingsState.currencySymbol)),
                  ]))),
              ]))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
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
                    'Account Balance Distribution',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (report.accountDistribution.isEmpty)
                    const EmptyStateWidget(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No Accounts',
                      subtitle: 'No accounts available.',
                    )
                  else
                    Column(
                      children: report.accountDistribution.map((accDist) {
                        final accColor = Color(accDist.account.colorValue);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    IconData(accDist.account.iconCodePoint, fontFamily: 'MaterialIcons'),
                                    size: 18,
                                    color: accColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    accDist.account.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${CurrencyFormatter.formatMinor(accDist.balanceMinor, symbol: settingsState.currencySymbol)} (${accDist.percentage.toStringAsFixed(1)}%)',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (accDist.percentage / 100.0).clamp(0.0, 1.0),
                                  backgroundColor: AppColors.cardBorder,
                                  valueColor: AlwaysStoppedAnimation<Color>(accColor),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int amountMinor,
    required Color color,
    required String symbol,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.formatMinor(amountMinor, symbol: symbol),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAvgColumn(String label, double amount, String symbol) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.formatAmount(amount, symbol: symbol),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
