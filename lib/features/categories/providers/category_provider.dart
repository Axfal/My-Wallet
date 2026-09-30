import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/category_model.dart';
import '../data/category_repository.dart';

class CategoryState {
  final List<CategoryModel> categories;
  final bool isLoading;

  CategoryState({
    required this.categories,
    this.isLoading = false,
  });

  List<CategoryModel> get incomeCategories =>
      categories.where((c) => c.type == CategoryType.income).toList();

  List<CategoryModel> get expenseCategories =>
      categories.where((c) => c.type == CategoryType.expense).toList();

  CategoryState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CategoryNotifier extends StateNotifier<CategoryState> {
  final CategoryRepository _repository;

  CategoryNotifier(this._repository)
      : super(CategoryState(categories: [], isLoading: true)) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    await _repository.initDefaultCategoriesIfNeeded();
    final list = _repository.getAllCategories();
    state = state.copyWith(categories: list, isLoading: false);
  }

  Future<void> addOrUpdateCategory(CategoryModel category) async {
    await _repository.saveCategory(category);
    await loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await _repository.deleteCategory(id);
    await loadCategories();
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

final categoryProvider =
    StateNotifierProvider<CategoryNotifier, CategoryState>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return CategoryNotifier(repo);
});
