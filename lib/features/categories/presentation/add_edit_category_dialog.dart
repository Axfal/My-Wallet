import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../data/category_model.dart';
import '../providers/category_provider.dart';

class AddEditCategoryDialog extends ConsumerStatefulWidget {
  final CategoryModel? category;

  const AddEditCategoryDialog({super.key, this.category});

  @override
  ConsumerState<AddEditCategoryDialog> createState() =>
      _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends ConsumerState<AddEditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late CategoryType _selectedType;
  late int _selectedColor;
  late int _selectedIcon;
  bool _isLoading = false;

  final List<int> _colors = const [
    0xFF10B981, // Emerald
    0xFF3B82F6, // Blue
    0xFFF59E0B, // Amber
    0xFFEF4444, // Red
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
    0xFFF97316, // Orange
    0xFF6366F1, // Indigo
    0xFF14B8A6, // Teal
    0xFF64748B, // Slate
  ];

  final List<IconData> _icons = const [
    Icons.fastfood_rounded,
    Icons.directions_bus_rounded,
    Icons.shopping_bag_rounded,
    Icons.receipt_long_rounded,
    Icons.wifi_rounded,
    Icons.school_rounded,
    Icons.medical_services_rounded,
    Icons.movie_rounded,
    Icons.home_rounded,
    Icons.family_restroom_rounded,
    Icons.flight_rounded,
    Icons.trending_up_rounded,
    Icons.work_rounded,
    Icons.laptop_rounded,
    Icons.store_rounded,
    Icons.card_giftcard_rounded,
    Icons.show_chart_rounded,
    Icons.replay_rounded,
    Icons.attach_money_rounded,
    Icons.fitness_center_rounded,
    Icons.sports_esports_rounded,
    Icons.pets_rounded,
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _selectedType = cat?.type ?? CategoryType.expense;
    _selectedColor = cat?.colorValue ?? _colors.first;
    _selectedIcon = cat?.iconCodePoint ?? _icons.first.codePoint;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();

    final categoryToSave = CategoryModel(
      id: widget.category?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      type: _selectedType,
      iconCodePoint: _selectedIcon,
      colorValue: _selectedColor,
      isDefault: widget.category?.isDefault ?? false,
      createdAt: widget.category?.createdAt ?? now,
    );

    setState(() => _isLoading = true);

    await ref.read(categoryProvider.notifier).addOrUpdateCategory(categoryToSave);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.category == null
              ? 'Category created successfully!'
              : 'Category updated successfully!'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_rounded : Icons.category_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Edit Category' : 'Add Custom Category',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Type Segmented Switch
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        selected: _selectedType == CategoryType.expense,
                        label: Center(
                          child: Text(
                            'Expense',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _selectedType == CategoryType.expense
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        selectedColor: AppColors.expense,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedType = CategoryType.expense);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        selected: _selectedType == CategoryType.income,
                        label: Center(
                          child: Text(
                            'Income',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _selectedType == CategoryType.income
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        selectedColor: AppColors.income,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedType = CategoryType.income);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Category Name',
                  hint: 'e.g. Groceries, Gym, Hobbies',
                  controller: _nameController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 16),

                // Color Picker
                Text(
                  'Color',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colors.map((c) {
                    final isSelected = c == _selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: AppColors.textPrimary, width: 2.5)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Icon Picker
                Text(
                  'Icon',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _icons.map((ic) {
                    final isSelected = ic.codePoint == _selectedIcon;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = ic.codePoint),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(_selectedColor).withOpacity(0.15)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Color(_selectedColor) : AppColors.cardBorder,
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: Icon(ic, size: 22, color: Color(_selectedColor)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Cancel',
                        isOutlined: true,
                        height: 46,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: isEdit ? 'Update' : 'Create',
                        isLoading: _isLoading,
                        height: 46,
                        onPressed: _handleSave,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
