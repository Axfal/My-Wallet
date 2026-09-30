import 'package:flutter/material.dart';
import '../../../core/utils/currency_formatter.dart';

enum AccountType {
  bank,
  mobileWallet,
  cash,
  other,
}

extension AccountTypeExtension on AccountType {
  String get label {
    switch (this) {
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.mobileWallet:
        return 'Mobile Wallet';
      case AccountType.cash:
        return 'Cash';
      case AccountType.other:
        return 'Other';
    }
  }

  String get key {
    switch (this) {
      case AccountType.bank:
        return 'bank';
      case AccountType.mobileWallet:
        return 'mobile_wallet';
      case AccountType.cash:
        return 'cash';
      case AccountType.other:
        return 'other';
    }
  }

  static AccountType fromKey(String key) {
    switch (key) {
      case 'bank':
        return AccountType.bank;
      case 'mobile_wallet':
        return AccountType.mobileWallet;
      case 'cash':
        return AccountType.cash;
      default:
        return AccountType.other;
    }
  }

  IconData get defaultIcon {
    switch (this) {
      case AccountType.bank:
        return Icons.account_balance_rounded;
      case AccountType.mobileWallet:
        return Icons.account_balance_wallet_rounded;
      case AccountType.cash:
        return Icons.payments_rounded;
      case AccountType.other:
        return Icons.credit_card_rounded;
    }
  }
}

class AccountModel {
  final String id;
  final String name;
  final String providerName;
  final AccountType type;
  final int balanceMinor;
  final int openingBalanceMinor;
  final String? accountNumber;
  final int iconCodePoint;
  final int colorValue;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  AccountModel({
    required this.id,
    required this.name,
    required this.providerName,
    required this.type,
    required this.balanceMinor,
    required this.openingBalanceMinor,
    this.accountNumber,
    required this.iconCodePoint,
    required this.colorValue,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  double get balance => CurrencyFormatter.minorToAmount(balanceMinor);
  double get openingBalance => CurrencyFormatter.minorToAmount(openingBalanceMinor);

  AccountModel copyWith({
    String? id,
    String? name,
    String? providerName,
    AccountType? type,
    int? balanceMinor,
    int? openingBalanceMinor,
    String? accountNumber,
    int? iconCodePoint,
    int? colorValue,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      providerName: providerName ?? this.providerName,
      type: type ?? this.type,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
      accountNumber: accountNumber ?? this.accountNumber,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
