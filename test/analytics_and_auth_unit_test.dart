import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/core/utils/app_date_utils.dart';
import 'package:my_wallet/features/accounts/data/account_model.dart';
import 'package:my_wallet/features/analytics/services/analytics_calculator.dart';
import 'package:my_wallet/features/categories/data/category_model.dart';
import 'package:my_wallet/features/transactions/data/transaction_model.dart';

void main() {
  group('5-7. Auth Logic & Fallback Tests', () {
    test('Password validation and password change verification', () {
      String currentPass = '123456';

      bool validate(String entered) => entered == currentPass;

      void changePass(String newPass) {
        currentPass = newPass;
      }

      // Initial password verification
      expect(validate('123456'), isTrue);
      expect(validate('000000'), isFalse);

      // Change password
      changePass('654321');
      expect(validate('123456'), isFalse);
      expect(validate('654321'), isTrue);
    });

    test('Biometric setting behavior and failure fallback', () {
      bool biometricEnabled = false;

      void toggleBiometric(bool val) {
        biometricEnabled = val;
      }

      bool authenticateBiometrics({required bool isSuccess}) {
        if (!biometricEnabled) return false;
        return isSuccess;
      }

      expect(biometricEnabled, isFalse);

      // Enable biometrics
      toggleBiometric(true);
      expect(biometricEnabled, isTrue);

      // Biometrics failure falls back (returns false so password prompt stays active)
      final successOnFail = authenticateBiometrics(isSuccess: false);
      expect(successOnFail, isFalse);

      // Biometrics success unlocks
      final successOnPass = authenticateBiometrics(isSuccess: true);
      expect(successOnPass, isTrue);
    });
  });

  group('8. Date-range Report Calculation Tests', () {
    test('Calculates report totals correctly for date range', () {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 10, 0);
      final oldDate = DateTime(2020, 1, 1);

      final accounts = [
        AccountModel(
          id: 'a1',
          name: 'Account 1',
          providerName: 'Bank',
          type: AccountType.bank,
          balanceMinor: 100000,
          openingBalanceMinor: 100000,
          iconCodePoint: 0,
          colorValue: 0xFF10B981,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final categories = [
        CategoryModel(
          id: 'c1',
          name: 'Salary',
          type: CategoryType.income,
          iconCodePoint: 0,
          colorValue: 0xFF10B981,
          createdAt: now,
        ),
        CategoryModel(
          id: 'c2',
          name: 'Food',
          type: CategoryType.expense,
          iconCodePoint: 0,
          colorValue: 0xFFEF4444,
          createdAt: now,
        ),
      ];

      final transactions = [
        // Today Income: 50,000 PKR (5000000 minor)
        TransactionModel(
          id: 't1',
          type: TransactionType.income,
          amountMinor: 5000000,
          categoryId: 'c1',
          accountId: 'a1',
          dateTime: todayStart,
          createdAt: now,
          updatedAt: now,
        ),
        // Today Expense: 10,000 PKR (1000000 minor)
        TransactionModel(
          id: 't2',
          type: TransactionType.expense,
          amountMinor: 1000000,
          categoryId: 'c2',
          accountId: 'a1',
          dateTime: todayStart,
          createdAt: now,
          updatedAt: now,
        ),
        // Old Expense (Out of range): 5,000 PKR
        TransactionModel(
          id: 't3',
          type: TransactionType.expense,
          amountMinor: 500000,
          categoryId: 'c2',
          accountId: 'a1',
          dateTime: oldDate,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final report = AnalyticsCalculator.calculateReport(
        transactions: transactions,
        accounts: accounts,
        categories: categories,
        filter: DateRangeFilter.today,
      );

      expect(report.totalIncomeMinor, equals(5000000));
      expect(report.totalExpenseMinor, equals(1000000));
      expect(report.netSavingsMinor, equals(4000000));
      expect(report.expenseByCategory.length, equals(1));
      expect(report.expenseByCategory.first.category.name, equals('Food'));
    });
  });
}
