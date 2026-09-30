import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:my_wallet/features/accounts/data/account_adapter.dart';
import 'package:my_wallet/features/accounts/data/account_model.dart';
import 'package:my_wallet/features/accounts/data/account_repository.dart';
import 'package:my_wallet/features/accounts/providers/account_provider.dart';
import 'package:my_wallet/features/categories/data/category_adapter.dart';
import 'package:my_wallet/features/categories/data/category_model.dart';
import 'package:my_wallet/features/categories/data/category_repository.dart';
import 'package:my_wallet/features/categories/providers/category_provider.dart';
import 'package:my_wallet/features/settings/data/settings_repository.dart';
import 'package:my_wallet/features/settings/providers/settings_provider.dart';
import 'package:my_wallet/features/transactions/data/transaction_adapter.dart';
import 'package:my_wallet/features/transactions/data/transaction_model.dart';
import 'package:my_wallet/features/transactions/data/transaction_repository.dart';
import 'package:my_wallet/features/transactions/presentation/add_edit_transaction_screen.dart';
import 'package:my_wallet/features/transactions/providers/transaction_provider.dart';

class _TestSettingsRepository extends SettingsRepository {
  _TestSettingsRepository(Box<dynamic> box) : super(box: box);
  @override Future<bool> isBiometricEnabled() async => false;
}

void main() {
  late Directory directory;
  late Box<AccountModel> accounts;
  late Box<TransactionModel> transactions;
  late Box<CategoryModel> categories;
  late Box<dynamic> settings;
  late AccountRepository accountRepo;
  late _TestSettingsRepository settingsRepo;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    directory = await Directory.systemTemp.createTemp('wallet_form_layout');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryAdapter());
    accounts = await Hive.openBox<AccountModel>('layout_accounts');
    transactions = await Hive.openBox<TransactionModel>('layout_transactions');
    categories = await Hive.openBox<CategoryModel>('layout_categories');
    settings = await Hive.openBox<dynamic>('layout_settings');
    final now = DateTime.now();
    await categories.put('salary', CategoryModel(id: 'salary', name: 'Salary',
      type: CategoryType.income, iconCodePoint: Icons.attach_money.codePoint,
      colorValue: 0xFF0F766E, createdAt: now));
    await accounts.put('cash', AccountModel(id: 'cash',
      name: 'Long Named Cash Account in Hand', providerName: 'Cash',
      type: AccountType.cash, balanceMinor: 100000,
      openingBalanceMinor: 100000, iconCodePoint: Icons.payments.codePoint,
      colorValue: 0xFF0F766E, createdAt: now, updatedAt: now));
    accountRepo = AccountRepository(box: accounts);
    settingsRepo = _TestSettingsRepository(settings);
  });

  testWidgets('transaction form lays out on narrow screen and saves income', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      accountRepositoryProvider.overrideWithValue(accountRepo),
      categoryRepositoryProvider.overrideWithValue(CategoryRepository(box: categories)),
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      transactionRepositoryProvider.overrideWithValue(TransactionRepository(
        box: transactions, accountRepo: accountRepo, settingsRepo: settingsRepo)),
    ], child: const MaterialApp(home: AddEditTransactionScreen(initialType: TransactionType.income))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Record Transaction'), findsOneWidget);
    expect(find.textContaining('Long Named Cash Account'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '25.50');
    await tester.ensureVisible(find.text('Save Transaction'));
    await tester.tap(find.text('Save Transaction'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Please select'), findsNothing);
    expect(transactions.length, 1);
    expect(accounts.get('cash')!.balanceMinor, 102550);
  });
}
