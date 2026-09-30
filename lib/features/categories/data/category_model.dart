import 'package:flutter/material.dart';

enum CategoryType {
  income,
  expense,
}

extension CategoryTypeExtension on CategoryType {
  String get key => name;

  static CategoryType fromKey(String key) {
    return key == 'income' ? CategoryType.income : CategoryType.expense;
  }
}

class CategoryModel {
  final String id;
  final String name;
  final CategoryType type;
  final int iconCodePoint;
  final int colorValue;
  final bool isDefault;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.iconCodePoint,
    required this.colorValue,
    this.isDefault = false,
    required this.createdAt,
  });

  IconData get iconData => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  CategoryModel copyWith({
    String? id,
    String? name,
    CategoryType? type,
    int? iconCodePoint,
    int? colorValue,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
