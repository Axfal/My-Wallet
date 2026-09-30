import '../../../core/utils/currency_formatter.dart';

enum TransactionType {
  income,
  expense,
}

extension TransactionTypeExtension on TransactionType {
  String get key => name;

  static TransactionType fromKey(String key) {
    return key == 'income' ? TransactionType.income : TransactionType.expense;
  }
}

class PaymentAllocation {
  final String accountId;
  final int amountMinor;
  const PaymentAllocation({required this.accountId, required this.amountMinor});
  Map<String, dynamic> toMap() => {'account': accountId, 'amount': amountMinor};
  factory PaymentAllocation.fromMap(Map value) => PaymentAllocation(
    accountId: value['account'] as String, amountMinor: value['amount'] as int);
}

class TransactionModel {
  final String id;
  final TransactionType type;
  final int amountMinor;
  final String categoryId;
  final String accountId;
  final List<PaymentAllocation> allocations;
  final String? note;
  final String? proofPath;
  final DateTime dateTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.categoryId,
    required this.accountId,
    this.allocations = const [],
    this.note,
    this.proofPath,
    required this.dateTime,
    required this.createdAt,
    required this.updatedAt,
  });

  double get amount => CurrencyFormatter.minorToAmount(amountMinor);
  List<PaymentAllocation> get effectiveAllocations => allocations.isEmpty
      ? [PaymentAllocation(accountId: accountId, amountMinor: amountMinor)] : allocations;
  bool get isSplitPayment => effectiveAllocations.length > 1;

  TransactionModel copyWith({
    String? id,
    TransactionType? type,
    int? amountMinor,
    String? categoryId,
    String? accountId,
    List<PaymentAllocation>? allocations,
    String? note,
    String? proofPath,
    DateTime? dateTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      allocations: allocations ?? this.allocations,
      note: note ?? this.note,
      proofPath: proofPath ?? this.proofPath,
      dateTime: dateTime ?? this.dateTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
