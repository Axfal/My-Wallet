import 'package:hive/hive.dart';
import '../../../core/services/hive_service.dart';
import 'category_model.dart';
import 'default_categories.dart';

class CategoryRepository {
  final Box<CategoryModel> _box;

  CategoryRepository({Box<CategoryModel>? box})
      : _box = box ?? HiveService.categoriesBox;

  Future<void> initDefaultCategoriesIfNeeded() async {
    if (_box.isEmpty) {
      final defaultList = DefaultCategories.getDefaultCategories();
      for (final cat in defaultList) {
        await _box.put(cat.id, cat);
      }
    }
  }

  List<CategoryModel> getAllCategories() {
    final list = _box.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<CategoryModel> getCategoriesByType(CategoryType type) {
    return getAllCategories().where((cat) => cat.type == type).toList();
  }

  CategoryModel? getCategoryById(String id) {
    try {
      return _box.values.firstWhere((cat) => cat.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCategory(CategoryModel category) async {
    await _box.put(category.id, category);
  }

  Future<void> deleteCategory(String id) async {
    if (HiveService.transactionsBox.values.any((t) => t.categoryId == id)) {
      throw StateError('Category has linked transactions');
    }
    await _box.delete(id);
  }
}
