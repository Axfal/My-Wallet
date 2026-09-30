import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/attachment_service.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/transaction_model.dart';
import '../providers/transaction_provider.dart';

class AddEditTransactionScreen extends ConsumerStatefulWidget {
  final TransactionModel? transaction;
  final TransactionType initialType;

  const AddEditTransactionScreen({
    super.key,
    this.transaction,
    this.initialType = TransactionType.expense,
  });

  @override
  ConsumerState<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _PaymentDraft {
  String? accountId;
  final TextEditingController amount;
  _PaymentDraft({this.accountId, String initialAmount = ''})
      : amount = TextEditingController(text: initialAmount);
  void dispose() => amount.dispose();
}

class _AddEditTransactionScreenState
    extends ConsumerState<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  late TransactionType _selectedType;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  late DateTime _selectedDateTime;
  bool _isLoading = false;
  String? _errorMessage;
  String? _proofPath;
  bool _splitPayment = false;
  final List<_PaymentDraft> _paymentDrafts = [];

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _selectedType = t?.type ?? widget.initialType;
    _amountController = TextEditingController(
      text: t != null
          ? '${t.amountMinor ~/ 100}${t.amountMinor % 100 == 0 ? '' : '.${(t.amountMinor % 100).toString().padLeft(2, '0')}'}'
          : '',
    );
    _noteController = TextEditingController(text: t?.note ?? '');
    _selectedAccountId = t?.accountId;
    _selectedCategoryId = t?.categoryId;
    _selectedDateTime = t?.dateTime ?? DateTime.now();
    _proofPath = t?.proofPath;
    _splitPayment = t?.isSplitPayment ?? false;
    if (_splitPayment) {
      for (final part in t!.effectiveAllocations) {
        _paymentDrafts.add(_PaymentDraft(accountId: part.accountId,
          initialAmount: CurrencyFormatter.minorToAmount(part.amountMinor).toStringAsFixed(2)));
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    for (final draft in _paymentDrafts) { draft.dispose(); }
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_splitPayment && _selectedAccountId == null) {
      setState(() => _errorMessage = 'Please select an account.');
      return;
    }

    if (_selectedCategoryId == null) {
      setState(() => _errorMessage = 'Please select a category.');
      return;
    }

    final amountMinor = CurrencyFormatter.parseToMinor(_amountController.text.trim());
    if (amountMinor == null || amountMinor <= 0) {
      setState(() => _errorMessage = 'Please enter a valid positive amount.');
      return;
    }

    final allocations = <PaymentAllocation>[];
    if (_splitPayment) {
      for (final draft in _paymentDrafts) {
        final part = CurrencyFormatter.parseToMinor(draft.amount.text.trim());
        if (draft.accountId == null || part == null || part <= 0) {
          setState(() => _errorMessage = 'Choose an account and a positive amount for each payment part.');
          return;
        }
        allocations.add(PaymentAllocation(accountId: draft.accountId!, amountMinor: part));
      }
      if (allocations.length < 2 ||
          allocations.map((p) => p.accountId).toSet().length != allocations.length ||
          allocations.fold<int>(0, (sum, p) => sum + p.amountMinor) != amountMinor) {
        setState(() => _errorMessage = 'Use two or more different accounts. Their amounts must equal the transaction total.');
        return;
      }
    } else {
      allocations.add(PaymentAllocation(accountId: _selectedAccountId!, amountMinor: amountMinor));
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    final isEdit = widget.transaction != null;

    final transactionToSave = TransactionModel(
      id: widget.transaction?.id ?? const Uuid().v4(),
      type: _selectedType,
      amountMinor: amountMinor,
      categoryId: _selectedCategoryId!,
      accountId: allocations.first.accountId,
      allocations: _splitPayment ? allocations : const [],
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      proofPath: _proofPath,
      dateTime: _selectedDateTime,
      createdAt: widget.transaction?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (isEdit) {
        await ref
            .read(transactionProvider.notifier)
            .updateTransaction(transactionToSave);
      } else {
        await ref
            .read(transactionProvider.notifier)
            .addTransaction(transactionToSave);
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Transaction updated successfully!'
                : 'Transaction recorded successfully!'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null;
    final accountState = ref.watch(accountProvider);
    final categoryState = ref.watch(categoryProvider);
    final settingsState = ref.watch(settingsProvider);

    // Select default account and category if not set
    if (!accountState.accounts.any((a) => a.id == _selectedAccountId) &&
        accountState.accounts.isNotEmpty) {
      _selectedAccountId = accountState.accounts.first.id;
    }

    final availableCategories = _selectedType == TransactionType.income
        ? categoryState.incomeCategories
        : categoryState.expenseCategories;

    if (!availableCategories.any((c) => c.id == _selectedCategoryId) &&
        availableCategories.isNotEmpty) {
      _selectedCategoryId = availableCategories.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Transaction' : 'Record Transaction',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type Selector Chips
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        selected: _selectedType == TransactionType.expense,
                        showCheckmark: false,
                        label: Center(
                          child: Text(
                            'Expense',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _selectedType == TransactionType.expense
                                  ? Colors.white
                                  : AppColors.expense,
                            ),
                          ),
                        ),
                        selectedColor: AppColors.expense,
                        backgroundColor: AppColors.expenseBg,
                        side: BorderSide(
                          color: _selectedType == TransactionType.expense
                              ? AppColors.expense
                              : AppColors.cardBorder,
                          width: 1.2,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedType = TransactionType.expense;
                              _selectedCategoryId = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        selected: _selectedType == TransactionType.income,
                        showCheckmark: false,
                        label: Center(
                          child: Text(
                            'Income',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _selectedType == TransactionType.income
                                  ? Colors.white
                                  : AppColors.income,
                            ),
                          ),
                        ),
                        selectedColor: AppColors.income,
                        backgroundColor: AppColors.incomeBg,
                        side: BorderSide(
                          color: _selectedType == TransactionType.income
                              ? AppColors.income
                              : AppColors.cardBorder,
                          width: 1.2,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedType = TransactionType.income;
                              _selectedCategoryId = null;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.expenseBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.expense, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.expense,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Amount Input
              CustomTextField(
                label: 'Amount (${settingsState.currencySymbol})',
                hint: '0',
                controller: _amountController,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Text(
                    settingsState.currencySymbol,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final parsed = CurrencyFormatter.parseToMinor(val);
                  if (parsed == null || parsed <= 0) return 'Enter a positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Text('Payment method', style: GoogleFonts.inter(fontSize: 13,
                fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Full payment')),
                  ButtonSegment(value: true, label: Text('Split payment')),
                ],
                selected: {_splitPayment},
                onSelectionChanged: (selection) => setState(() {
                  _splitPayment = selection.first;
                  if (_splitPayment && _paymentDrafts.isEmpty) {
                    _paymentDrafts.addAll([
                      _PaymentDraft(accountId: _selectedAccountId), _PaymentDraft(),
                    ]);
                  }
                }),
              ),
              const SizedBox(height: 8),
              Text(_splitPayment ? 'Split the total across bank accounts, wallets or cash.'
                  : 'Use one account for the full amount.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              if (_splitPayment) ...[
                for (var i = 0; i < _paymentDrafts.length; i++)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Payment ${i + 1}', style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, color: AppColors.primary)),
                        const Spacer(),
                        if (_paymentDrafts.length > 2) IconButton(
                          tooltip: 'Remove payment', icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _paymentDrafts.removeAt(i).dispose())),
                      ]),
                      DropdownButtonFormField<String>(
                        key: ValueKey('split-account-$i-${_paymentDrafts[i].accountId}'),
                        initialValue: _paymentDrafts[i].accountId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Account / cash',
                          border: OutlineInputBorder()),
                        items: accountState.accounts.map((a) => DropdownMenuItem(
                          value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (value) => setState(() => _paymentDrafts[i].accountId = value)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _paymentDrafts[i].amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Amount (${settingsState.currencySymbol})',
                          border: const OutlineInputBorder()),
                        onChanged: (_) => setState(() {})),
                    ]),
                  )),
                OutlinedButton.icon(onPressed: accountState.accounts.length > _paymentDrafts.length
                    ? () => setState(() => _paymentDrafts.add(_PaymentDraft())) : null,
                  icon: const Icon(Icons.add_rounded), label: const Text('Add another account')),
                const SizedBox(height: 6),
                Builder(builder: (_) {
                  final total = CurrencyFormatter.parseToMinor(_amountController.text) ?? 0;
                  final allocated = _paymentDrafts.fold<int>(0, (sum, draft) =>
                    sum + (CurrencyFormatter.parseToMinor(draft.amount.text) ?? 0));
                  return Text('Allocated: ${CurrencyFormatter.formatMinor(allocated, symbol: settingsState.currencySymbol)}'
                    ' / ${CurrencyFormatter.formatMinor(total, symbol: settingsState.currencySymbol)}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                      color: allocated == total ? AppColors.primary : AppColors.warning));
                }),
                const SizedBox(height: 16),
              ] else ...[
              // Account Selector
              Text(
                'Select Account / Wallet',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              if (accountState.accounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'No accounts available. Please add an account first.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.warning),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('account-$_selectedAccountId'),
                  initialValue: _selectedAccountId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                    ),
                  ),
                  items: accountState.accounts.map((acc) {
                    return DropdownMenuItem<String>(
                      value: acc.id,
                      child: Text(
                        '${acc.name}  ·  ${CurrencyFormatter.formatMinor(acc.balanceMinor, symbol: settingsState.currencySymbol)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  selectedItemBuilder: (context) => accountState.accounts.map((acc) =>
                    Align(alignment: Alignment.centerLeft, child: Text(acc.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600))),
                  ).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAccountId = val);
                  },
                ),
              const SizedBox(height: 16),

              ],
              // Category Selector
              Text(
                'Select Category',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: ValueKey('category-${_selectedType.name}-$_selectedCategoryId'),
                initialValue: _selectedCategoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                ),
                items: availableCategories.map((cat) {
                  final catColor = Color(cat.colorValue);
                  return DropdownMenuItem<String>(
                    value: cat.id,
                    child: Row(
                      children: [
                        Icon(cat.iconData, size: 20, color: catColor),
                        const SizedBox(width: 10),
                        Text(
                          cat.name,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategoryId = val);
                },
              ),
              const SizedBox(height: 16),

              // Date & Time Selector
              Text(
                'Date & Time',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppDateUtils.formatDateTime(_selectedDateTime),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note Field
              CustomTextField(
                label: 'Note (Optional)',
                hint: 'e.g. Grocery items, Monthly wifi bill',
                controller: _noteController,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(_proofPath == null ? 'Attach receipt image' : 'Receipt image attached'),
                onPressed: () async {
                  try {
                    final path = await AttachmentService().pickAndSaveImage();
                    if (path != null) setState(() => _proofPath = path);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
              ),
              const SizedBox(height: 28),

              CustomButton(
                text: isEdit ? 'Update Transaction' : 'Save Transaction',
                isLoading: _isLoading,
                onPressed: accountState.accounts.isEmpty ? null : _handleSave,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
