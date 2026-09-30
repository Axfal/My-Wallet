import 'package:hive_flutter/hive_flutter.dart';
import '../../features/accounts/data/account_adapter.dart';
import '../../features/accounts/data/account_model.dart';
import '../../features/categories/data/category_adapter.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/transactions/data/transaction_adapter.dart';
import '../../features/transactions/data/transaction_model.dart';
import '../../features/loans/data/loan_models.dart';
import '../../features/settings/data/app_settings_model.dart';

class HiveService {
  static const String accountsBoxName = 'accounts';
  static const String transactionsBoxName = 'transactions';
  static const String categoriesBoxName = 'categories';
  static const String settingsBoxName = 'settings';
  static const String peopleBoxName = 'people';
  static const String loansBoxName = 'loans';
  static const String repaymentsBoxName = 'repayments';
  static const String attachmentsBoxName = 'attachments';
  static const String appSettingsBoxName = 'app_settings';

  static Future<void> initHive() async {
    await Hive.initFlutter();

    // Register Hive Adapters safely
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AccountAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PersonAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(LoanAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(LoanRepaymentAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(AttachmentMetadataAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(AppSettingsAdapter());

    // Open Boxes
    await Hive.openBox<AccountModel>(accountsBoxName);
    await Hive.openBox<TransactionModel>(transactionsBoxName);
    await Hive.openBox<CategoryModel>(categoriesBoxName);
    await Hive.openBox<dynamic>(settingsBoxName);
    await Hive.openBox<Person>(peopleBoxName);
    await Hive.openBox<Loan>(loansBoxName);
    await Hive.openBox<LoanRepayment>(repaymentsBoxName);
    await Hive.openBox<AttachmentMetadata>(attachmentsBoxName);
    await Hive.openBox<AppSettings>(appSettingsBoxName);
  }

  static Box<AccountModel> get accountsBox =>
      Hive.box<AccountModel>(accountsBoxName);

  static Box<TransactionModel> get transactionsBox =>
      Hive.box<TransactionModel>(transactionsBoxName);

  static Box<CategoryModel> get categoriesBox =>
      Hive.box<CategoryModel>(categoriesBoxName);

  static Box<dynamic> get settingsBox =>
      Hive.box<dynamic>(settingsBoxName);
  static Box<Person> get peopleBox => Hive.box<Person>(peopleBoxName);
  static Box<Loan> get loansBox => Hive.box<Loan>(loansBoxName);
  static Box<LoanRepayment> get repaymentsBox => Hive.box<LoanRepayment>(repaymentsBoxName);
  static Box<AttachmentMetadata> get attachmentsBox => Hive.box<AttachmentMetadata>(attachmentsBoxName);
  static Box<AppSettings> get appSettingsBox => Hive.box<AppSettings>(appSettingsBoxName);
}
