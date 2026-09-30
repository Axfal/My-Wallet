import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../data/account_model.dart';
import '../providers/account_provider.dart';

class AddEditAccountDialog extends ConsumerStatefulWidget {
  final AccountModel? account;

  const AddEditAccountDialog({super.key, this.account});

  @override
  ConsumerState<AddEditAccountDialog> createState() =>
      _AddEditAccountDialogState();
}

class _AddEditAccountDialogState extends ConsumerState<AddEditAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _providerController;
  late TextEditingController _balanceController;
  late TextEditingController _accountNumberController;
  late TextEditingController _noteController;

  late AccountType _selectedType;
  late int _selectedColor;
  late int _selectedIcon;
  bool _isLoading = false;

  final List<int> _colors = const [
    0xFF1E40AF, // Deep Blue
    0xFF0F766E, // Emerald
    0xFF7C3AED, // Purple
    0xFF059669, // Green
    0xFFEF4444, // Red
    0xFFF59E0B, // Amber
    0xFF0EA5E9, // Sky
    0xFFEC4899, // Pink
    0xFF475569, // Slate
  ];

  final List<IconData> _icons = const [
    Icons.account_balance_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.payments_rounded,
    Icons.credit_card_rounded,
    Icons.savings_rounded,
    Icons.monetization_on_rounded,
    Icons.store_rounded,
    Icons.shield_rounded,
  ];

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _nameController = TextEditingController(text: acc?.name ?? '');
    _providerController = TextEditingController(text: acc?.providerName ?? '');
    _balanceController = TextEditingController(
      text: acc != null ? CurrencyFormatter.minorToAmount(acc.openingBalanceMinor).toStringAsFixed(0) : '',
    );
    _accountNumberController = TextEditingController(text: acc?.accountNumber ?? '');
    _noteController = TextEditingController(text: acc?.note ?? '');

    _selectedType = acc?.type ?? AccountType.bank;
    _selectedColor = acc?.colorValue ?? _colors.first;
    _selectedIcon = acc?.iconCodePoint ?? Icons.account_balance_rounded.codePoint;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _balanceController.dispose();
    _accountNumberController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final balanceMinor = CurrencyFormatter.parseToMinor(_balanceController.text.trim()) ?? 0;
    final now = DateTime.now();

    final accountToSave = AccountModel(
      id: widget.account?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      providerName: _providerController.text.trim(),
      type: _selectedType,
      balanceMinor: widget.account == null ? balanceMinor :
          widget.account!.balanceMinor + balanceMinor - widget.account!.openingBalanceMinor,
      openingBalanceMinor: balanceMinor,
      accountNumber: _accountNumberController.text.trim().isEmpty
          ? null
          : _accountNumberController.text.trim(),
      iconCodePoint: _selectedIcon,
      colorValue: _selectedColor,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: widget.account?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() => _isLoading = true);

    await ref.read(accountProvider.notifier).addOrUpdateAccount(accountToSave);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.account == null
              ? 'Account created successfully!'
              : 'Account updated successfully!'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;

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
                        isEdit ? Icons.edit_rounded : Icons.add_card_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Edit Account' : 'Add New Account',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  label: 'Account Name',
                  hint: 'e.g. My Meezan Account',
                  controller: _nameController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Account name required' : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  label: 'Bank / Provider Name',
                  hint: 'e.g. Meezan Bank, JazzCash, Cash in Hand',
                  controller: _providerController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Provider required' : null,
                ),
                const SizedBox(height: 14),

                // Account Type Dropdown
                Text(
                  'Account Type',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<AccountType>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                    ),
                  ),
                  items: AccountType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(t.defaultIcon, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Text(t.label, style: GoogleFonts.inter(fontSize: 14)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  label: 'Opening Balance (PKR)',
                  hint: '0',
                  controller: _balanceController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Balance required';
                    if (double.tryParse(v.replaceAll(',', '')) == null) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  label: 'Account Number / Last 4 Digits (Optional)',
                  hint: 'e.g. 1234',
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),

                // Color Picker
                Text(
                  'Color Theme',
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
                const SizedBox(height: 14),

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
