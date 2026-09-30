import 'package:flutter/material.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../accounts/data/account_model.dart';
import '../../categories/data/category_model.dart';
import '../../transactions/data/transaction_model.dart';

class CategorySummary {
  final CategoryModel category;
  final int totalAmountMinor;
  final double percentage;

  CategorySummary({
    required this.category,
    required this.totalAmountMinor,
    required this.percentage,
  });
}

class AccountDistributionSummary {
  final AccountModel account;
  final int balanceMinor;
  final double percentage;

  AccountDistributionSummary({
    required this.account,
    required this.balanceMinor,
    required this.percentage,
  });
}

class TimeSeriesPoint {
  final DateTime date;
  final String label;
  final int incomeMinor;
  final int expenseMinor;

  TimeSeriesPoint({
    required this.date,
    required this.label,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  int get netSavingsMinor => incomeMinor - expenseMinor;
}

class AnalyticsReportData {
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int netSavingsMinor;
  final double averageDailyIncome;
  final double averageDailyExpense;
  final double averageMonthlyIncome;
  final double averageMonthlyExpense;
  final List<CategorySummary> expenseByCategory;
  final List<CategorySummary> incomeByCategory;
  final List<AccountDistributionSummary> accountDistribution;
  final List<TimeSeriesPoint> timeSeriesData;

  AnalyticsReportData({
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.netSavingsMinor,
    required this.averageDailyIncome,
    required this.averageDailyExpense,
    required this.averageMonthlyIncome,
    required this.averageMonthlyExpense,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.accountDistribution,
    required this.timeSeriesData,
  });
}

class AnalyticsCalculator {
  static AnalyticsReportData calculateReport({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required DateRangeFilter filter,
    DateTimeRange? customRange,
  }) {
    final range = AppDateUtils.getRangeForFilter(filter, customRange: customRange);

    // Filter transactions within date range
    final filtered = transactions.where((t) => AppDateUtils.isDateInRange(t.dateTime, range)).toList();

    int totalIncomeMinor = 0;
    int totalExpenseMinor = 0;

    final Map<String, int> expenseCatTotals = {};
    final Map<String, int> incomeCatTotals = {};

    for (final t in filtered) {
      if (t.type == TransactionType.income) {
        totalIncomeMinor += t.amountMinor;
        incomeCatTotals[t.categoryId] = (incomeCatTotals[t.categoryId] ?? 0) + t.amountMinor;
      } else {
        totalExpenseMinor += t.amountMinor;
        expenseCatTotals[t.categoryId] = (expenseCatTotals[t.categoryId] ?? 0) + t.amountMinor;
      }
    }

    final netSavingsMinor = totalIncomeMinor - totalExpenseMinor;

    // Days count in range
    final totalDays = (range.end.difference(range.start).inHours / 24).ceil();
    final effectiveDays = totalDays > 0 ? totalDays : 1;
    final effectiveMonths = (effectiveDays / 30.0).clamp(1.0, 365.0);

    final double avgDailyIncome = (totalIncomeMinor / 100.0) / effectiveDays;
    final double avgDailyExpense = (totalExpenseMinor / 100.0) / effectiveDays;
    final double avgMonthlyIncome = (totalIncomeMinor / 100.0) / effectiveMonths;
    final double avgMonthlyExpense = (totalExpenseMinor / 100.0) / effectiveMonths;

    // Expense By Category List
    final List<CategorySummary> expenseByCatList = [];
    expenseCatTotals.forEach((catId, amountMinor) {
      final category = categories.where((c) => c.id == catId).firstOrNull;
      if (category != null) {
        final pct = totalExpenseMinor > 0 ? (amountMinor / totalExpenseMinor) * 100 : 0.0;
        expenseByCatList.add(CategorySummary(
          category: category,
          totalAmountMinor: amountMinor,
          percentage: pct,
        ));
      }
    });
    expenseByCatList.sort((a, b) => b.totalAmountMinor.compareTo(a.totalAmountMinor));

    // Income By Category List
    final List<CategorySummary> incomeByCatList = [];
    incomeCatTotals.forEach((catId, amountMinor) {
      final category = categories.where((c) => c.id == catId).firstOrNull;
      if (category != null) {
        final pct = totalIncomeMinor > 0 ? (amountMinor / totalIncomeMinor) * 100 : 0.0;
        incomeByCatList.add(CategorySummary(
          category: category,
          totalAmountMinor: amountMinor,
          percentage: pct,
        ));
      }
    });
    incomeByCatList.sort((a, b) => b.totalAmountMinor.compareTo(a.totalAmountMinor));

    // Account Distribution
    int totalAccountsBalance = 0;
    for (final acc in accounts) {
      if (acc.balanceMinor > 0) totalAccountsBalance += acc.balanceMinor;
    }

    final List<AccountDistributionSummary> accountDist = accounts.map((acc) {
      final pct = (totalAccountsBalance > 0 && acc.balanceMinor > 0)
          ? (acc.balanceMinor / totalAccountsBalance) * 100
          : 0.0;
      return AccountDistributionSummary(
        account: acc,
        balanceMinor: acc.balanceMinor,
        percentage: pct,
      );
    }).toList();

    // Time Series grouping
    final timeSeries = _generateTimeSeriesPoints(filtered, range, filter);

    return AnalyticsReportData(
      totalIncomeMinor: totalIncomeMinor,
      totalExpenseMinor: totalExpenseMinor,
      netSavingsMinor: netSavingsMinor,
      averageDailyIncome: avgDailyIncome,
      averageDailyExpense: avgDailyExpense,
      averageMonthlyIncome: avgMonthlyIncome,
      averageMonthlyExpense: avgMonthlyExpense,
      expenseByCategory: expenseByCatList,
      incomeByCategory: incomeByCatList,
      accountDistribution: accountDist,
      timeSeriesData: timeSeries,
    );
  }

  static List<TimeSeriesPoint> _generateTimeSeriesPoints(
    List<TransactionModel> transactions,
    DateTimeRange range,
    DateRangeFilter filter,
  ) {
    final List<TimeSeriesPoint> points = [];

    if (filter == DateRangeFilter.today || filter == DateRangeFilter.thisWeek) {
      // Group by day
      DateTime current = range.start;
      while (current.isBefore(range.end)) {
        final dayStart = DateTime(current.year, current.month, current.day);
        final dayEnd = DateTime(current.year, current.month, current.day, 23, 59, 59);

        int inc = 0;
        int exp = 0;

        for (final t in transactions) {
          if (t.dateTime.isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
              t.dateTime.isBefore(dayEnd.add(const Duration(milliseconds: 1)))) {
            if (t.type == TransactionType.income) {
              inc += t.amountMinor;
            } else {
              exp += t.amountMinor;
            }
          }
        }

        final label = AppDateUtils.formatDayHeader(current);
        points.add(TimeSeriesPoint(
          date: current,
          label: label,
          incomeMinor: inc,
          expenseMinor: exp,
        ));

        current = current.add(const Duration(days: 1));
      }
    } else {
      // Group by month
      DateTime current = DateTime(range.start.year, range.start.month, 1);
      final DateTime endMonth = DateTime(range.end.year, range.end.month, 1);

      while (!current.isAfter(endMonth)) {
        final monthStart = DateTime(current.year, current.month, 1);
        final monthEnd = DateTime(current.year, current.month + 1, 0, 23, 59, 59);

        int inc = 0;
        int exp = 0;

        for (final t in transactions) {
          if (t.dateTime.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) &&
              t.dateTime.isBefore(monthEnd.add(const Duration(milliseconds: 1)))) {
            if (t.type == TransactionType.income) {
              inc += t.amountMinor;
            } else {
              exp += t.amountMinor;
            }
          }
        }

        final label = AppDateUtils.formatMonthYear(current);
        points.add(TimeSeriesPoint(
          date: current,
          label: label,
          incomeMinor: inc,
          expenseMinor: exp,
        ));

        current = DateTime(current.year, current.month + 1, 1);
      }
    }

    return points;
  }
}
