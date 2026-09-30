import 'package:intl/intl.dart';
import '../../accounts/data/account_model.dart';
import '../../categories/data/category_model.dart';
import '../../loans/data/loan_models.dart';
import 'transaction_model.dart';

enum LedgerKind {
  income,
  expense,
  loanGiven,
  loanTaken,
  repaymentReceived,
  repaymentPaid,
}

extension LedgerKindLabel on LedgerKind {
  String get label => switch (this) {
    LedgerKind.income => 'Income',
    LedgerKind.expense => 'Expense',
    LedgerKind.loanGiven => 'Loan Given',
    LedgerKind.loanTaken => 'Loan Taken',
    LedgerKind.repaymentReceived => 'Loan Repayment Received',
    LedgerKind.repaymentPaid => 'Loan Repayment Paid',
  };
}

class LedgerEntry {
  final String id, accountId, accountName, categoryId, category, person, note;
  final DateTime date;
  final LedgerKind kind;
  final int amountMinor;
  const LedgerEntry({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.categoryId,
    required this.category,
    required this.person,
    required this.note,
    required this.date,
    required this.kind,
    required this.amountMinor,
  });
  int get signedMinor => switch (kind) {
    LedgerKind.income ||
    LedgerKind.loanTaken ||
    LedgerKind.repaymentReceived => amountMinor,
    _ => -amountMinor,
  };
}

class LedgerRow {
  final LedgerEntry entry;
  final int balanceMinor;
  const LedgerRow(this.entry, this.balanceMinor);
}

class LedgerResult {
  final List<LedgerRow> rows;
  final int openingMinor, closingMinor, incomeMinor, expenseMinor;
  const LedgerResult({
    required this.rows,
    required this.openingMinor,
    required this.closingMinor,
    required this.incomeMinor,
    required this.expenseMinor,
  });
}

class LedgerFilter {
  final DateTime? start, end;
  final String? accountId, categoryId;
  final Set<LedgerKind> kinds;
  final String query;
  const LedgerFilter({
    this.start,
    this.end,
    this.accountId,
    this.categoryId,
    required this.kinds,
    this.query = '',
  });
}

/// A journal of all cash movements. Loan principal and repayments stay
/// separate from income and expense totals.
class LedgerExport {
  static List<LedgerEntry> entries({
    required Iterable<AccountModel> accounts,
    required Iterable<CategoryModel> categories,
    required Iterable<TransactionModel> transactions,
    required Iterable<Loan> loans,
    required Iterable<Person> people,
    required Iterable<LoanRepayment> repayments,
  }) {
    final accountNames = {for (final a in accounts) a.id: a.name};
    final categoryNames = {for (final c in categories) c.id: c.name};
    final peopleNames = {for (final p in people) p.id: p.fullName};
    final loanMap = {for (final l in loans) l.id: l};
    final result = <LedgerEntry>[
      for (final t in transactions)
        for (final part in t.effectiveAllocations)
        LedgerEntry(
          id: '${t.id}:${part.accountId}',
          accountId: part.accountId,
          accountName: accountNames[part.accountId] ?? 'Deleted account',
          categoryId: t.categoryId,
          category: categoryNames[t.categoryId] ?? 'Deleted category',
          person: '',
          note: t.note ?? '',
          date: t.dateTime,
          kind: t.type == TransactionType.income
              ? LedgerKind.income
              : LedgerKind.expense,
          amountMinor: part.amountMinor,
        ),
      for (final l in loans)
        LedgerEntry(
          id: l.id,
          accountId: l.accountId,
          accountName: accountNames[l.accountId] ?? 'Deleted account',
          categoryId: '',
          category: 'Loan principal',
          person: peopleNames[l.personId] ?? 'Unknown person',
          note: l.note ?? '',
          date: l.issuedAt,
          kind: l.type == LoanType.given
              ? LedgerKind.loanGiven
              : LedgerKind.loanTaken,
          amountMinor: l.originalAmountMinor,
        ),
      for (final p in repayments)
        if (loanMap[p.loanId] case final Loan l)
          LedgerEntry(
            id: p.id,
            accountId: p.accountId,
            accountName: accountNames[p.accountId] ?? 'Deleted account',
            categoryId: '',
            category: 'Loan repayment',
            person: peopleNames[l.personId] ?? 'Unknown person',
            note: p.note ?? '',
            date: p.paidAt,
            kind: l.type == LoanType.given
                ? LedgerKind.repaymentReceived
                : LedgerKind.repaymentPaid,
            amountMinor: p.amountMinor,
          ),
    ];
    result.sort((a, b) {
      final date = a.date.compareTo(b.date);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
    return result;
  }

  /// Unwinds saved balances, then applies all movements in date order. Hidden
  /// rows still affect the running balance, so every visible balance is real.
  static LedgerResult build({
    required Iterable<AccountModel> accounts,
    required List<LedgerEntry> entries,
    required LedgerFilter filter,
  }) {
    final selected = accounts
        .where((a) => filter.accountId == null || a.id == filter.accountId)
        .toList();
    final ids = selected.map((a) => a.id).toSet();
    final movements = entries.where((e) => ids.contains(e.accountId)).toList()
      ..sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date == 0 ? a.id.compareTo(b.id) : date;
      });
    var running =
        selected.fold<int>(0, (sum, a) => sum + a.balanceMinor) -
        movements.fold<int>(0, (sum, e) => sum + e.signedMinor);
    for (final e in movements) {
      if (filter.start != null && e.date.isBefore(filter.start!))
        running += e.signedMinor;
    }
    final opening = running;
    final rows = <LedgerRow>[];
    var income = 0, expense = 0;
    final search = filter.query.trim().toLowerCase();
    for (final e in movements) {
      if (filter.start != null && e.date.isBefore(filter.start!)) continue;
      if (filter.end != null && e.date.isAfter(filter.end!)) break;
      running += e.signedMinor;
      if (!filter.kinds.contains(e.kind) ||
          (filter.categoryId != null && e.categoryId != filter.categoryId) ||
          (search.isNotEmpty &&
              !'${e.kind.label} ${e.accountName} ${e.category} ${e.person} ${e.note} ${e.amountMinor / 100}'
                  .toLowerCase()
                  .contains(search)))
        continue;
      rows.add(LedgerRow(e, running));
      if (e.kind == LedgerKind.income) income += e.amountMinor;
      if (e.kind == LedgerKind.expense) expense += e.amountMinor;
    }
    return LedgerResult(
      rows: rows,
      openingMinor: opening,
      closingMinor: running,
      incomeMinor: income,
      expenseMinor: expense,
    );
  }

  static String csv(
    LedgerResult result, {
    required String currency,
    required String scope,
  }) {
    String money(int minor) =>
        '${minor < 0 ? '-' : ''}${minor.abs() ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}';
    String cell(String value) {
      // Keep spreadsheet apps from executing user-entered formulas.
      final safe = RegExp(r'^\s*[=+@-]').hasMatch(value) ? "'$value" : value;
      return '"${safe.replaceAll('"', '""')}"';
    }

    final lines = <String>[
      [cell('My Wallet Ledger'), cell(scope), cell(currency)].join(','),
      [cell('Opening balance'), cell(money(result.openingMinor))].join(','),
      'Date,Time,Type,Category,Account,Person,Note,Money In,Money Out,Running Balance',
      for (final row in result.rows)
        [
          cell(DateFormat('yyyy-MM-dd').format(row.entry.date)),
          cell(DateFormat('HH:mm').format(row.entry.date)),
          cell(row.entry.kind.label),
          cell(row.entry.category),
          cell(row.entry.accountName),
          cell(row.entry.person),
          cell(row.entry.note),
          cell(row.entry.signedMinor > 0 ? money(row.entry.amountMinor) : ''),
          cell(row.entry.signedMinor < 0 ? money(row.entry.amountMinor) : ''),
          cell(money(row.balanceMinor)),
        ].join(','),
      [cell('Closing balance'), cell(money(result.closingMinor))].join(','),
      [
        cell('Total income'),
        cell(money(result.incomeMinor)),
        cell('Total expenses'),
        cell(money(result.expenseMinor)),
      ].join(','),
    ];
    return '\uFEFF${lines.join('\r\n')}\r\n';
  }
}
