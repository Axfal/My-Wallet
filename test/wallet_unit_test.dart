import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_wallet/core/services/hive_service.dart';
import 'package:my_wallet/features/accounts/data/account_adapter.dart';
import 'package:my_wallet/features/accounts/data/account_model.dart';
import 'package:my_wallet/features/accounts/data/account_repository.dart';
import 'package:my_wallet/features/categories/data/category_adapter.dart';
import 'package:my_wallet/features/categories/data/category_model.dart';
import 'package:my_wallet/features/categories/data/category_repository.dart';
import 'package:my_wallet/features/settings/data/settings_repository.dart';
import 'package:my_wallet/features/transactions/data/transaction_adapter.dart';
import 'package:my_wallet/features/transactions/data/transaction_model.dart';
import 'package:my_wallet/features/transactions/data/transaction_repository.dart';

void main() {
  late Directory tempDir;
  late Box<AccountModel> accountsBox;
  late Box<TransactionModel> transactionsBox;
  late Box<CategoryModel> categoriesBox;
  late Box<dynamic> settingsBox;

  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late CategoryRepository categoryRepo;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_wallet');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    accountsBox = await Hive.openBox<AccountModel>('accounts_test_${DateTime.now().millisecondsSinceEpoch}');
    transactionsBox = await Hive.openBox<TransactionModel>('transactions_test_${DateTime.now().millisecondsSinceEpoch}');
    categoriesBox = await Hive.openBox<CategoryModel>('categories_test_${DateTime.now().millisecondsSinceEpoch}');
    settingsBox = await Hive.openBox<dynamic>('settings_test_${DateTime.now().millisecondsSinceEpoch}');

    accountRepo = AccountRepository(box: accountsBox);
    final settingsRepo = SettingsRepository(box: settingsBox);
    transactionRepo = TransactionRepository(
      box: transactionsBox,
      accountRepo: accountRepo,
      settingsRepo: settingsRepo,
    );
    categoryRepo = CategoryRepository(box: categoriesBox);
  });

  tearDown(() async {
    await accountsBox.clear();
    await accountsBox.close();
    await transactionsBox.clear();
    await transactionsBox.close();
    await categoriesBox.clear();
    await categoriesBox.close();
    await settingsBox.clear();
    await settingsBox.close();
  });

  test('1. Income increases account balance correctly', () async {
    final now = DateTime.now();
    final account = AccountModel(
      id: 'acc-1',
      name: 'Meezan Bank',
      providerName: 'Meezan Bank',
      type: AccountType.bank,
      balanceMinor: 500000, // 5,000 PKR
      openingBalanceMinor: 500000,
      iconCodePoint: 0,
      colorValue: 0xFF10B981,
      createdAt: now,
      updatedAt: now,
    );
    await accountRepo.saveAccount(account);

    final incomeTx = TransactionModel(
      id: 'tx-1',
      type: TransactionType.income,
      amountMinor: 200000, // 2,000 PKR
      categoryId: 'cat-salary',
      accountId: 'acc-1',
      dateTime: now,
      createdAt: now,
      updatedAt: now,
    );

    await transactionRepo.addTransaction(incomeTx);

    final updatedAccount = accountRepo.getAccountById('acc-1');
    expect(updatedAccount, isNotNull);
    expect(updatedAccount!.balanceMinor, equals(700000)); // 5,000 + 2,000 = 7,000 PKR
  });

  test('2. Expense deducts account balance correctly', () async {
    final now = DateTime.now();
    final account = AccountModel(
      id: 'acc-2',
      name: 'Easypaisa',
      providerName: 'Easypaisa',
      type: AccountType.mobileWallet,
      balanceMinor: 1000000, // 10,000 PKR
      openingBalanceMinor: 1000000,
      iconCodePoint: 0,
      colorValue: 0xFF10B981,
      createdAt: now,
      updatedAt: now,
    );
    await accountRepo.saveAccount(account);

    final expenseTx = TransactionModel(
      id: 'tx-2',
      type: TransactionType.expense,
      amountMinor: 300000, // 3,000 PKR
      categoryId: 'cat-food',
      accountId: 'acc-2',
      dateTime: now,
      createdAt: now,
      updatedAt: now,
    );

    await transactionRepo.addTransaction(expenseTx);

    final updatedAccount = accountRepo.getAccountById('acc-2');
    expect(updatedAccount, isNotNull);
    expect(updatedAccount!.balanceMinor, equals(700000)); // 10,000 - 3,000 = 7,000 PKR
  });

  test('3. Editing transaction recalculates balance correctly', () async {
    final now = DateTime.now();
    final account = AccountModel(
      id: 'acc-3',
      name: 'Cash in Hand',
      providerName: 'Cash',
      type: AccountType.cash,
      balanceMinor: 1000000, // 10,000 PKR
      openingBalanceMinor: 1000000,
      iconCodePoint: 0,
      colorValue: 0xFF10B981,
      createdAt: now,
      updatedAt: now,
    );
    await accountRepo.saveAccount(account);

    // Initial expense: 2,000 PKR -> balance becomes 8,000 PKR
    final initialExpense = TransactionModel(
      id: 'tx-3',
      type: TransactionType.expense,
      amountMinor: 200000,
      categoryId: 'cat-bills',
      accountId: 'acc-3',
      dateTime: now,
      createdAt: now,
      updatedAt: now,
    );
    await transactionRepo.addTransaction(initialExpense);

    expect(accountRepo.getAccountById('acc-3')!.balanceMinor, equals(800000));

    // Edit transaction: change expense amount to 4,000 PKR
    final updatedExpense = initialExpense.copyWith(amountMinor: 400000);
    await transactionRepo.updateTransaction(updatedExpense);

    // Balance should be reverted (+2,000) then re-applied (-4,000) = 6,000 PKR
    expect(accountRepo.getAccountById('acc-3')!.balanceMinor, equals(600000));
  });

  test('4. Deleting transaction restores balance correctly', () async {
    final now = DateTime.now();
    final account = AccountModel(
      id: 'acc-4',
      name: 'HBL Account',
      providerName: 'HBL',
      type: AccountType.bank,
      balanceMinor: 500000, // 5,000 PKR
      openingBalanceMinor: 500000,
      iconCodePoint: 0,
      colorValue: 0xFF10B981,
      createdAt: now,
      updatedAt: now,
    );
    await accountRepo.saveAccount(account);

    final expenseTx = TransactionModel(
      id: 'tx-4',
      type: TransactionType.expense,
      amountMinor: 150000, // 1,500 PKR
      categoryId: 'cat-shopping',
      accountId: 'acc-4',
      dateTime: now,
      createdAt: now,
      updatedAt: now,
    );
    await transactionRepo.addTransaction(expenseTx);

    expect(accountRepo.getAccountById('acc-4')!.balanceMinor, equals(350000));

    // Delete transaction
    await transactionRepo.deleteTransaction('tx-4');

    // Balance restored back to 5,000 PKR (500000 minor)
    expect(accountRepo.getAccountById('acc-4')!.balanceMinor, equals(500000));
  });
}
