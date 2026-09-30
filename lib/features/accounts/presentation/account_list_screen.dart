import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../data/account_model.dart';
import '../providers/account_provider.dart';
import 'account_card.dart';
import 'add_edit_account_dialog.dart';

class AccountListScreen extends ConsumerWidget {
  const AccountListScreen({super.key});

  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const AddEditAccountDialog(),
    );
  }

  void _showEditAccountDialog(BuildContext context, AccountModel account) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditAccountDialog(account: account),
    );
  }

  void _handleDeleteAccount(BuildContext context, WidgetRef ref, AccountModel account) {
    // Check if account has linked transactions
    final transactionNotifier = ref.read(transactionProvider);
    final hasLinkedTransactions = transactionNotifier.transactions
        .any((t) => t.accountId == account.id);

    if (hasLinkedTransactions ||
        HiveService.loansBox.values.any((l) => l.accountId == account.id) ||
        HiveService.repaymentsBox.values.any((p) => p.accountId == account.id)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.block_rounded, color: AppColors.warning, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cannot Delete Account',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Text(
            '${account.name} has linked transactions, loans, or repayments. Remove or reassign those records first.',
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
        title: 'Delete Account',
        message: 'Are you sure you want to delete ${account.name}? This action cannot be undone.',
        confirmText: 'Delete',
        onConfirm: () async {
          await ref.read(accountProvider.notifier).deleteAccount(account.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${account.name} deleted successfully.'),
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
    final accountState = ref.watch(accountProvider);
    final settingsState = ref.watch(settingsProvider);

    final filteredAccounts = accountState.filteredAccounts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Accounts & Wallets',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Account',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Total Balance Overview Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_rounded,
                                color: Colors.white70, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Total Available Balance',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          CurrencyFormatter.formatMinor(
                            accountState.totalBalanceMinor,
                            symbol: settingsState.currencySymbol,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Across ${accountState.accounts.length} active wallets and bank accounts',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    onChanged: (q) =>
                        ref.read(accountProvider.notifier).setSearchQuery(q),
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search account name or provider...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.cardBorder, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Account Type Chips Filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          selected: accountState.typeFilter == null,
                          label: Text('All Accounts',
                              style: GoogleFonts.inter(fontSize: 12)),
                          onSelected: (_) => ref
                              .read(accountProvider.notifier)
                              .setTypeFilter(null),
                          selectedColor: AppColors.primaryLight,
                          checkmarkColor: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        ...AccountType.values.map((t) {
                          final isSelected = accountState.typeFilter == t;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(t.label,
                                  style: GoogleFonts.inter(fontSize: 12)),
                              onSelected: (_) => ref
                                  .read(accountProvider.notifier)
                                  .setTypeFilter(isSelected ? null : t),
                              selectedColor: AppColors.primaryLight,
                              checkmarkColor: AppColors.primary,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (filteredAccounts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No Accounts Found',
                subtitle: accountState.accounts.isEmpty
                    ? 'Add your first bank account, cash in hand, or mobile wallet to start tracking.'
                    : 'No accounts match your current filter.',
                actionText: 'Add Account',
                onAction: () => _showAddAccountDialog(context),
              ),
            )
          else
            SliverPadding(
              padding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final acc = filteredAccounts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AccountCard(
                        account: acc,
                        currencySymbol: settingsState.currencySymbol,
                        onEdit: () => _showEditAccountDialog(context, acc),
                        onDelete: () =>
                            _handleDeleteAccount(context, ref, acc),
                      ),
                    );
                  },
                  childCount: filteredAccounts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
