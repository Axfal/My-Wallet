import 'package:hive/hive.dart';
import '../../../core/services/hive_service.dart';
import '../../accounts/data/account_model.dart';
import '../../settings/data/settings_repository.dart';
import '../../transactions/data/transaction_model.dart';
import 'loan_models.dart';

/// Every balance is a projection of opening balance and persisted movements.
/// Rebuilding on startup repairs an interrupted multi-box Hive write.
class LoanRepository {
  final Box<AccountModel> accounts;
  final Box<TransactionModel> transactions;
  final Box<Person> people;
  final Box<Loan> loans;
  final Box<LoanRepayment> repayments;
  final bool Function() allowNegative;
  LoanRepository({Box<AccountModel>? accounts, Box<TransactionModel>? transactions,
    Box<Person>? people, Box<Loan>? loans, Box<LoanRepayment>? repayments,
    bool Function()? allowNegative})
      : accounts = accounts ?? HiveService.accountsBox,
        transactions = transactions ?? HiveService.transactionsBox,
        people = people ?? HiveService.peopleBox,
        loans = loans ?? HiveService.loansBox,
        repayments = repayments ?? HiveService.repaymentsBox,
        allowNegative = allowNegative ?? SettingsRepository().getAllowNegativeBalance;

  int projectedBalance(String accountId, {TransactionModel? replacementTransaction,
    String? removedTransactionId, Loan? replacementLoan,
    LoanRepayment? replacementRepayment, String? removedLoanId, String? removedRepaymentId}) {
    final account = accounts.get(accountId);
    if (account == null) throw StateError('Account no longer exists');
    var balance = account.openingBalanceMinor;
    for (final t in transactions.values) {
      if (t.id == removedTransactionId || t.id == replacementTransaction?.id) continue;
      for (final part in t.effectiveAllocations.where((a) => a.accountId == accountId)) {
        balance += t.type == TransactionType.income ? part.amountMinor : -part.amountMinor;
      }
    }
    if (replacementTransaction != null) {
      for (final part in replacementTransaction.effectiveAllocations.where((a) => a.accountId == accountId)) {
        balance += replacementTransaction.type == TransactionType.income
            ? part.amountMinor : -part.amountMinor;
      }
    }
    for (final loan in loans.values) {
      if (loan.id == removedLoanId || loan.id == replacementLoan?.id) continue;
      if (loan.accountId == accountId) {
        balance += loan.type == LoanType.taken ? loan.originalAmountMinor : -loan.originalAmountMinor;
      }
    }
    if (replacementLoan != null && replacementLoan.accountId == accountId) {
      balance += replacementLoan.type == LoanType.taken
          ? replacementLoan.originalAmountMinor : -replacementLoan.originalAmountMinor;
    }
    for (final payment in repayments.values) {
      if (payment.id == removedRepaymentId || payment.id == replacementRepayment?.id ||
          payment.loanId == removedLoanId) continue;
      final loan = payment.loanId == replacementLoan?.id ? replacementLoan : loans.get(payment.loanId);
      if (loan != null && payment.accountId == accountId) {
        balance += loan.type == LoanType.given ? payment.amountMinor : -payment.amountMinor;
      }
    }
    if (replacementRepayment != null && replacementRepayment.accountId == accountId) {
      final loan = replacementRepayment.loanId == replacementLoan?.id
          ? replacementLoan : loans.get(replacementRepayment.loanId);
      if (loan == null) throw StateError('Loan no longer exists');
      balance += loan.type == LoanType.given
          ? replacementRepayment.amountMinor : -replacementRepayment.amountMinor;
    }
    return balance;
  }

  Future<void> reconcile() async {
    for (final account in accounts.values.toList()) {
      final balance = projectedBalance(account.id);
      if (account.balanceMinor != balance) {
        await accounts.put(account.id, account.copyWith(balanceMinor: balance, updatedAt: DateTime.now()));
      }
    }
    for (final loan in loans.values.toList()) {
      final paid = repayments.values.where((p) => p.loanId == loan.id)
          .fold<int>(0, (sum, p) => sum + p.amountMinor);
      final outstanding = loan.originalAmountMinor - paid;
      if (outstanding != loan.outstandingAmountMinor) {
        await loans.put(loan.id, loan.copyWith(outstandingAmountMinor: outstanding, updatedAt: DateTime.now()));
      }
    }
  }

  void _checkAccounts(Set<String> ids, {Loan? loan, LoanRepayment? payment,
      String? removeLoan, String? removePayment}) {
    for (final id in ids) {
      if (!allowNegative() && projectedBalance(id, replacementLoan: loan,
          replacementRepayment: payment, removedLoanId: removeLoan,
          removedRepaymentId: removePayment) < 0) {
        throw StateError('Insufficient funds in the selected account');
      }
    }
  }

  Future<void> saveLoan(Loan loan, Person person) async {
    if (loan.originalAmountMinor <= 0 || person.fullName.trim().isEmpty) {
      throw ArgumentError('Enter a person and a positive amount');
    }
    final old = loans.get(loan.id);
    final paid = repayments.values.where((p) => p.loanId == loan.id)
        .fold<int>(0, (sum, p) => sum + p.amountMinor);
    if (paid > loan.originalAmountMinor) throw StateError('Amount is below recorded repayments');
    final updated = loan.copyWith(outstandingAmountMinor: loan.originalAmountMinor - paid);
    _checkAccounts({loan.accountId, if (old != null) old.accountId,
      ...repayments.values.where((p) => p.loanId == loan.id).map((p) => p.accountId)}, loan: updated);
    final oldPerson = people.get(person.id);
    try {
      await people.put(person.id, person);
      await loans.put(loan.id, updated);
      await reconcile();
    } catch (_) {
      if (old == null) { await loans.delete(loan.id); } else { await loans.put(old.id, old); }
      if (oldPerson == null) { await people.delete(person.id); } else { await people.put(person.id, oldPerson); }
      await reconcile();
      rethrow;
    }
  }

  Future<void> saveRepayment(LoanRepayment payment) async {
    final loan = loans.get(payment.loanId);
    if (loan == null || loan.cancelled) throw StateError('Active loan not found');
    if (payment.amountMinor <= 0) throw ArgumentError('Enter a positive repayment');
    final old = repayments.get(payment.id);
    final alreadyPaid = repayments.values.where((p) => p.loanId == loan.id && p.id != payment.id)
        .fold<int>(0, (sum, p) => sum + p.amountMinor);
    if (alreadyPaid + payment.amountMinor > loan.originalAmountMinor) {
      throw StateError('Repayment exceeds the outstanding amount');
    }
    _checkAccounts({payment.accountId, if (old != null) old.accountId}, payment: payment);
    try {
      await repayments.put(payment.id, payment);
      await reconcile();
    } catch (_) {
      if (old == null) { await repayments.delete(payment.id); } else { await repayments.put(old.id, old); }
      await reconcile();
      rethrow;
    }
  }

  Future<void> deleteRepayment(String id) async {
    final old = repayments.get(id);
    if (old == null) return;
    _checkAccounts({old.accountId}, removePayment: id);
    try {
      await repayments.delete(id);
      await reconcile();
    } catch (_) {
      await repayments.put(id, old);
      await reconcile();
      rethrow;
    }
  }

  Future<void> deleteLoan(String id) async {
    final old = loans.get(id);
    if (old == null) return;
    if (repayments.values.any((p) => p.loanId == id)) {
      throw StateError('Remove repayments before deleting this loan');
    }
    _checkAccounts({old.accountId}, removeLoan: id);
    try {
      await loans.delete(id);
      await reconcile();
    } catch (_) {
      await loans.put(id, old);
      await reconcile();
      rethrow;
    }
  }

  /// Writing off a loan closes the receivable/liability while preserving every cash movement.
  Future<void> writeOffLoan(String id, String reason) async {
    final loan = loans.get(id);
    if (loan == null) throw StateError('Loan not found');
    if (loan.cancelled || loan.outstandingAmountMinor == 0) throw StateError('Loan is already closed');
    if (reason.trim().length < 10) throw ArgumentError('Explain the write-off in at least 10 characters');
    await loans.put(id, loan.copyWith(cancelled: true,
      writeOffReason: reason.trim(), updatedAt: DateTime.now()));
  }
}
