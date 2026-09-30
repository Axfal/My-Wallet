import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/custom_button.dart';
import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/transaction_model.dart';
import '../providers/transaction_provider.dart';
import 'add_edit_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  void _handleDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Delete Transaction',
        message: 'Are you sure you want to delete this transaction? The account balance will be restored automatically.',
        confirmText: 'Delete',
        onConfirm: () async {
          await ref
              .read(transactionProvider.notifier)
              .deleteTransaction(transaction.id);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction deleted.'),
                backgroundColor: AppColors.expense,
              ),
            );
          }
        },
      ),
    );
  }

  void _handleEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditTransactionScreen(transaction: transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountNotifier = ref.watch(accountProvider);
    final categoryNotifier = ref.watch(categoryProvider);
    final settingsState = ref.watch(settingsProvider);

    final account = accountNotifier.accounts
        .where((a) => a.id == transaction.accountId)
        .firstOrNull;

    final category = categoryNotifier.categories
        .where((c) => c.id == transaction.categoryId)
        .firstOrNull;

    final isIncome = transaction.type == TransactionType.income;
    final catColor = category != null ? Color(category.colorValue) : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Transaction Detail',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: AppColors.surface,
            onSelected: (value) {
              if (value == 'edit') {
                _handleEdit(context);
              } else if (value == 'delete') {
                _handleDelete(context, ref);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: AppColors.expense, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Amount & Type Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isIncome ? AppColors.incomeBg : AppColors.expenseBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isIncome ? 'INCOME' : 'EXPENSE',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isIncome ? AppColors.income : AppColors.expense,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${isIncome ? '+' : '-'}${CurrencyFormatter.formatMinor(transaction.amountMinor, symbol: settingsState.currencySymbol)}',
                      style: GoogleFonts.poppins(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: isIncome ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Metadata Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: category?.iconData ?? Icons.category_rounded,
                      iconColor: catColor,
                      label: 'Category',
                      value: category?.name ?? 'Unknown Category',
                    ),
                    const Divider(height: 24, color: AppColors.cardBorder),
                    _buildDetailRow(
                      icon: account != null
                          ? IconData(account.iconCodePoint, fontFamily: 'MaterialIcons')
                          : Icons.account_balance_rounded,
                      iconColor: account != null ? Color(account.colorValue) : AppColors.primary,
                      label: transaction.isSplitPayment ? 'Payment accounts' : 'Account / Wallet',
                      value: transaction.isSplitPayment
                        ? transaction.effectiveAllocations.map((part) {
                            final name = accountNotifier.accounts
                              .where((a) => a.id == part.accountId).firstOrNull?.name ?? 'Unknown account';
                            return '$name: ${CurrencyFormatter.formatMinor(part.amountMinor, symbol: settingsState.currencySymbol)}';
                          }).join('\n')
                        : account?.name ?? 'Unknown Account',
                    ),
                    const Divider(height: 24, color: AppColors.cardBorder),
                    _buildDetailRow(
                      icon: Icons.calendar_today_rounded,
                      iconColor: AppColors.textSecondary,
                      label: 'Date & Time',
                      value: AppDateUtils.formatDateTime(transaction.dateTime),
                    ),
                    if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                      const Divider(height: 24, color: AppColors.cardBorder),
                      _buildDetailRow(
                        icon: Icons.notes_rounded,
                        iconColor: AppColors.textSecondary,
                        label: 'Note',
                        value: transaction.note!,
                      ),
                    ],
                    if (transaction.proofPath != null && File(transaction.proofPath!).existsSync()) ...[
                      const Divider(height: 24, color: AppColors.cardBorder),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FullscreenImageViewer(
                                imagePath: transaction.proofPath!,
                                heroTag: 'proof-image-${transaction.id}',
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Receipt / Attachment',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Tap to expand',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Hero(
                              tag: 'proof-image-${transaction.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Image.file(
                                      File(transaction.proofPath!),
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Edit',
                      isOutlined: true,
                      icon: Icons.edit_outlined,
                      onPressed: () => _handleEdit(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Delete',
                      backgroundColor: AppColors.expense,
                      icon: Icons.delete_outline_rounded,
                      onPressed: () => _handleDelete(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FullscreenImageViewer extends StatelessWidget {
  final String imagePath;
  final String heroTag;

  const FullscreenImageViewer({
    super.key,
    required this.imagePath,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Attachment Preview',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                clipBehavior: Clip.none,
                child: Hero(
                  tag: heroTag,
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Pinch or double-tap to zoom in / out',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
