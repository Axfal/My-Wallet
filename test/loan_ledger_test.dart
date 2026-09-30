import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_wallet/features/accounts/data/account_adapter.dart';
import 'package:my_wallet/features/accounts/data/account_model.dart';
import 'package:my_wallet/features/loans/data/loan_models.dart';
import 'package:my_wallet/features/loans/data/loan_repository.dart';
import 'package:my_wallet/features/transactions/data/transaction_adapter.dart';
import 'package:my_wallet/features/transactions/data/transaction_model.dart';

void main() {
  late Directory dir;
  late Box<AccountModel> accounts;
  late Box<TransactionModel> transactions;
  late Box<Person> people;
  late Box<Loan> loans;
  late Box<LoanRepayment> payments;
  late LoanRepository repo;
  final now = DateTime(2026, 9, 30);

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('wallet_loan_test');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PersonAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(LoanAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(LoanRepaymentAdapter());
  });
  tearDownAll(() async { await Hive.close(); await dir.delete(recursive: true); });
  setUp(() async {
    accounts = await Hive.openBox<AccountModel>('la');
    transactions = await Hive.openBox<TransactionModel>('lt');
    people = await Hive.openBox<Person>('lp');
    loans = await Hive.openBox<Loan>('ll');
    payments = await Hive.openBox<LoanRepayment>('lr');
    repo = LoanRepository(accounts: accounts, transactions: transactions,
      people: people, loans: loans, repayments: payments, allowNegative: () => false);
    await accounts.put('a', AccountModel(id: 'a', name: 'Cash', providerName: 'Cash',
      type: AccountType.cash, balanceMinor: 100000, openingBalanceMinor: 100000,
      iconCodePoint: 0, colorValue: 0, createdAt: now, updatedAt: now));
  });
  tearDown(() async {
    for (final b in [accounts, transactions, people, loans, payments]) { await b.clear(); await b.close(); }
  });
  Person person() => Person(id: 'p', fullName: 'Ali', phoneNumber: '123', createdAt: now, updatedAt: now);
  Loan loan(LoanType type) => Loan(id: 'l', personId: 'p', accountId: 'a', type: type,
    originalAmountMinor: 50000, outstandingAmountMinor: 50000,
    issuedAt: now, dueAt: now.add(const Duration(days: 30)), createdAt: now, updatedAt: now);
  LoanRepayment payment(String id, int amount) => LoanRepayment(id: id, loanId: 'l',
    accountId: 'a', amountMinor: amount, paidAt: now, createdAt: now);

  test('given loan and partial/full repayment update cash and receivable', () async {
    await repo.saveLoan(loan(LoanType.given), person());
    expect(accounts.get('a')!.balanceMinor, 50000);
    await repo.saveRepayment(payment('r1', 20000));
    expect(accounts.get('a')!.balanceMinor, 70000);
    expect(loans.get('l')!.outstandingAmountMinor, 30000);
    await repo.saveRepayment(payment('r2', 30000));
    expect(accounts.get('a')!.balanceMinor, 100000);
    expect(loans.get('l')!.status, 'Paid');
    await repo.deleteRepayment('r2');
    expect(accounts.get('a')!.balanceMinor, 70000);
    expect(loans.get('l')!.outstandingAmountMinor, 30000);
  });

  test('taken loan, repayments, and deletion reverse cash effects', () async {
    await repo.saveLoan(loan(LoanType.taken), person());
    expect(accounts.get('a')!.balanceMinor, 150000);
    await repo.saveRepayment(payment('r1', 20000));
    expect(accounts.get('a')!.balanceMinor, 130000);
    await repo.saveRepayment(payment('r2', 30000));
    expect(accounts.get('a')!.balanceMinor, 100000);
    expect(loans.get('l')!.outstandingAmountMinor, 0);
    await repo.deleteRepayment('r1');
    await repo.deleteRepayment('r2');
    await repo.deleteLoan('l');
    expect(accounts.get('a')!.balanceMinor, 100000);
  });

  test('overpayment and insufficient funds reject without partial record', () async {
    await repo.saveLoan(loan(LoanType.taken), person());
    await expectLater(repo.saveRepayment(payment('bad', 60000)), throwsStateError);
    expect(payments.get('bad'), isNull);
    await repo.deleteLoan('l');
    final tooLarge = Loan(id: 'big', personId: 'p', accountId: 'a', type: LoanType.given,
      originalAmountMinor: 200000, outstandingAmountMinor: 200000,
      issuedAt: now, dueAt: now, createdAt: now, updatedAt: now);
    await expectLater(repo.saveLoan(tooLarge, person()), throwsStateError);
    expect(loans.get('big'), isNull);
    expect(accounts.get('a')!.balanceMinor, 100000);
  });

  test('reconcile restores account balance after restart-like drift', () async {
    await repo.saveLoan(loan(LoanType.given), person());
    await accounts.put('a', accounts.get('a')!.copyWith(balanceMinor: 999999));
    await repo.reconcile();
    expect(accounts.get('a')!.balanceMinor, 50000);
  });

  test('write-off closes receivable without refunding cash', () async {
    await repo.saveLoan(loan(LoanType.given), person());
    await repo.writeOffLoan('l', 'The borrower cannot repay the amount');
    expect(loans.get('l')!.status, 'Cancelled');
    await repo.reconcile();
    expect(accounts.get('a')!.balanceMinor, 50000);
    expect(loans.get('l')!.writeOffReason, isNotEmpty);
  });

  test('editing repayment reverses its previous cash effect', () async {
    await repo.saveLoan(loan(LoanType.given), person());
    await repo.saveRepayment(payment('r1', 20000));
    await repo.saveRepayment(payment('r1', 30000));
    expect(accounts.get('a')!.balanceMinor, 80000);
    expect(loans.get('l')!.outstandingAmountMinor, 20000);
  });
}
