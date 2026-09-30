import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../data/category_model.dart';
import '../providers/category_provider.dart';
import 'add_edit_category_dialog.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const AddEditCategoryDialog(),
    );
  }

  void _showEditCategoryDialog(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditCategoryDialog(category: category),
    );
  }

  void _handleDeleteCategory(BuildContext context, WidgetRef ref, CategoryModel category) {
    // Check if any transaction uses this category
    final transactionNotifier = ref.read(transactionProvider);
    final linkedTransactions = transactionNotifier.transactions
        .where((t) => t.categoryId == category.id)
        .toList();

    if (linkedTransactions.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Category In Use',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Text(
            'The category "${category.name}" is linked to ${linkedTransactions.length} transaction(s). To delete this category safely without corrupting your history, please reassign or delete those transactions first.',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Delete Category',
        message: 'Are you sure you want to delete category "${category.name}"?',
        confirmText: 'Delete',
        onConfirm: () async {
          await ref.read(categoryProvider.notifier).deleteCategory(category.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category "${category.name}" deleted.'),
                backgroundColor: AppColors.expense,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryState = ref.watch(categoryProvider);

    final expenseCategories = categoryState.expenseCategories;
    final incomeCategories = categoryState.incomeCategories;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Manage Categories',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [
              Tab(text: 'Expense Categories'),
              Tab(text: 'Income Categories'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddCategoryDialog(context),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Add Category',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildCategoryList(context, ref, expenseCategories),
            _buildCategoryList(context, ref, incomeCategories),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    WidgetRef ref,
    List<CategoryModel> list,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No categories found',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final cat = list[index];
        final catColor = Color(cat.colorValue);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: AppColors.softShadow,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(cat.iconData, color: catColor, size: 22),
            ),
            title: Text(
              cat.name,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: cat.isDefault
                ? Text(
                    'Default Category',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  )
                : Text(
                    'Custom Category',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                  onPressed: () => _showEditCategoryDialog(context, cat),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.expense),
                  onPressed: () => _handleDeleteCategory(context, ref, cat),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
