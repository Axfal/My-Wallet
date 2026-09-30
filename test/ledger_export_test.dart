import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/features/accounts/data/account_model.dart';
import 'package:my_wallet/features/transactions/data/ledger_export.dart';

void main() {
  final day1 = DateTime(2026, 1, 1, 10);
  final day2 = DateTime(2026, 1, 2, 10);
  final day3 = DateTime(2026, 1, 3, 10);
  final account = AccountModel(
    id: 'a',
    name: 'Cash',
    providerName: 'Cash',
    type: AccountType.cash,
    openingBalanceMinor: 100000,
    balanceMinor: 105000,
    iconCodePoint: 0xe3c2,
    colorValue: 0xff0f766e,
    createdAt: day1,
    updatedAt: day3,
  );
  final entries = [
    LedgerEntry(
      id: '1',
      accountId: 'a',
      accountName: 'Cash',
      categoryId: 'salary',
      category: 'Salary',
      person: '',
      note: '',
      date: day1,
      kind: LedgerKind.income,
      amountMinor: 20000,
    ),
    LedgerEntry(
      id: '2',
      accountId: 'a',
      accountName: 'Cash',
      categoryId: '',
      category: 'Loan principal',
      person: 'Ali',
      note: '',
      date: day2,
      kind: LedgerKind.loanGiven,
      amountMinor: 10000,
    ),
    LedgerEntry(
      id: '3',
      accountId: 'a',
      accountName: 'Cash',
      categoryId: '',
      category: 'Loan repayment',
      person: 'Ali',
      note: '=SUM(1,2)',
      date: day3,
      kind: LedgerKind.repaymentReceived,
      amountMinor: 5000,
    ),
    LedgerEntry(
      id: '4',
      accountId: 'a',
      accountName: 'Cash',
      categoryId: 'food',
      category: 'Food',
      person: '',
      note: '',
      date: day3.add(const Duration(hours: 1)),
      kind: LedgerKind.expense,
      amountMinor: 10000,
    ),
  ];

  test(
    'ledger reconciles cash movements and excludes loan amounts from income',
    () {
      final result = LedgerExport.build(
        accounts: [account],
        entries: entries,
        filter: LedgerFilter(kinds: LedgerKind.values.toSet()),
      );
      expect(result.openingMinor, 100000);
      expect(result.rows.map((r) => r.balanceMinor), [
        120000,
        110000,
        115000,
        105000,
      ]);
      expect(result.closingMinor, account.balanceMinor);
      expect(result.incomeMinor, 20000);
      expect(result.expenseMinor, 10000);
      final csv = LedgerExport.csv(result, currency: 'PKR', scope: 'All time');
      expect(csv, contains("'=SUM(1,2)"));
      expect(csv, contains('Loan Repayment Received'));
    },
  );

  test('date and type filters retain real running balance', () {
    final result = LedgerExport.build(
      accounts: [account],
      entries: entries,
      filter: LedgerFilter(
        start: day2,
        end: day3.add(const Duration(days: 1)),
        kinds: {LedgerKind.expense},
      ),
    );
    expect(result.openingMinor, 120000);
    expect(result.rows.length, 1);
    expect(result.rows.single.balanceMinor, 105000);
    expect(result.closingMinor, 105000);
  });
}
