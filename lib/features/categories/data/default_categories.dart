import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'category_model.dart';

class DefaultCategories {
  static List<CategoryModel> getDefaultCategories() {
    final now = DateTime.now();
    const uuid = Uuid();

    final List<Map<String, dynamic>> expenses = [
      {'name': 'Food', 'icon': Icons.fastfood_rounded.codePoint, 'color': 0xFFF59E0B},
      {'name': 'Transport', 'icon': Icons.directions_bus_rounded.codePoint, 'color': 0xFF3B82F6},
      {'name': 'Shopping', 'icon': Icons.shopping_bag_rounded.codePoint, 'color': 0xFFEC4899},
      {'name': 'Bills', 'icon': Icons.receipt_long_rounded.codePoint, 'color': 0xFFEF4444},
      {'name': 'Mobile Load / Internet', 'icon': Icons.wifi_rounded.codePoint, 'color': 0xFF8B5CF6},
      {'name': 'Education', 'icon': Icons.school_rounded.codePoint, 'color': 0xFF06B6D4},
      {'name': 'Health', 'icon': Icons.medical_services_rounded.codePoint, 'color': 0xFF10B981},
      {'name': 'Entertainment', 'icon': Icons.movie_rounded.codePoint, 'color': 0xFFF97316},
      {'name': 'Rent', 'icon': Icons.home_rounded.codePoint, 'color': 0xFF6366F1},
      {'name': 'Family', 'icon': Icons.family_restroom_rounded.codePoint, 'color': 0xFF14B8A6},
      {'name': 'Travel', 'icon': Icons.flight_rounded.codePoint, 'color': 0xFF0EA5E9},
      {'name': 'Investment', 'icon': Icons.trending_up_rounded.codePoint, 'color': 0xFF84CC16},
      {'name': 'Other', 'icon': Icons.more_horiz_rounded.codePoint, 'color': 0xFF64748B},
    ];

    final List<Map<String, dynamic>> incomes = [
      {'name': 'Salary', 'icon': Icons.work_rounded.codePoint, 'color': 0xFF10B981},
      {'name': 'Freelancing', 'icon': Icons.laptop_rounded.codePoint, 'color': 0xFF06B6D4},
      {'name': 'Business', 'icon': Icons.store_rounded.codePoint, 'color': 0xFF3B82F6},
      {'name': 'Gift', 'icon': Icons.card_giftcard_rounded.codePoint, 'color': 0xFFEC4899},
      {'name': 'Investment Return', 'icon': Icons.show_chart_rounded.codePoint, 'color': 0xFF84CC16},
      {'name': 'Refund', 'icon': Icons.replay_rounded.codePoint, 'color': 0xFF8B5CF6},
      {'name': 'Other', 'icon': Icons.attach_money_rounded.codePoint, 'color': 0xFF64748B},
    ];

    final List<CategoryModel> list = [];

    for (final exp in expenses) {
      list.add(CategoryModel(
        id: uuid.v4(),
        name: exp['name'] as String,
        type: CategoryType.expense,
        iconCodePoint: exp['icon'] as int,
        colorValue: exp['color'] as int,
        isDefault: true,
        createdAt: now,
      ));
    }

    for (final inc in incomes) {
      list.add(CategoryModel(
        id: uuid.v4(),
        name: inc['name'] as String,
        type: CategoryType.income,
        iconCodePoint: inc['icon'] as int,
        colorValue: inc['color'] as int,
        isDefault: true,
        createdAt: now,
      ));
    }

    return list;
  }
}
