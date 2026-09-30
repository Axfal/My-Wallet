import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../accounts/providers/account_provider.dart';
import '../../auth/presentation/change_password_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../categories/presentation/category_management_screen.dart';
import '../../categories/providers/category_provider.dart';
import '../../loans/presentation/loans_screen.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/presentation/ledger_export_screen.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const ChangePasswordDialog(),
    );
  }

  void _handleClearAllData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'CLEAR ALL DATA',
        message:
            'WARNING: This permanently deletes all accounts, transactions, loans, people, proof images, categories, and settings. This cannot be undone.',
        confirmText: 'PERMANENTLY CLEAR DATA',
        confirmColor: AppColors.expense,
        onConfirm: () async {
          for (final attachment in HiveService.attachmentsBox.values) {
            final file = File(attachment.localPath);
            if (await file.exists()) await file.delete();
          }
          await HiveService.accountsBox.clear();
          await HiveService.transactionsBox.clear();
          await HiveService.repaymentsBox.clear();
          await HiveService.loansBox.clear();
          await HiveService.peopleBox.clear();
          await HiveService.attachmentsBox.clear();
          await HiveService.categoriesBox.clear();
          await HiveService.settingsBox.clear();
          await HiveService.appSettingsBox.clear();
          await SecureStorageService().clearAll();

          // Refresh all state
          ref.read(accountProvider.notifier).loadAccounts();
          ref.read(transactionProvider.notifier).loadTransactions();
          ref.read(loanRevisionProvider.notifier).state++;
          await ref.read(categoryProvider.notifier).loadCategories();
          await ref.read(settingsProvider.notifier).loadSettings();

          // Lock app after clear
          ref.read(authProvider.notifier).lockApp();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All local app data has been erased.'),
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
    final settingsState = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);

    final List<String> currencies = ['₨', '\$', '€', '£', '₹', 'AED', 'SAR'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Section
            _buildSectionHeader('Security & Unlock'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    title: Text(
                      'Biometric / Device Unlock',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      authState.isBiometricAvailable
                          ? 'Use fingerprint or device lock to unlock app'
                          : 'Biometrics unavailable on this device',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: settingsState.biometricEnabled,
                    onChanged: authState.isBiometricAvailable
                        ? (val) => ref
                              .read(settingsProvider.notifier)
                              .toggleBiometricEnabled(val)
                        : null,
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  ListTile(
                    leading: const Icon(
                      Icons.key_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: Text(
                      'Change App Password',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Update your 6-digit or custom password',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Preferences Section
            _buildSectionHeader('Preferences'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.attach_money_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: Text(
                      'Currency Symbol',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Default is PKR (₨)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: DropdownButton<String>(
                      value: settingsState.currencySymbol,
                      underline: const SizedBox(),
                      items: currencies.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .updateCurrencySymbol(val);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    title: Text(
                      'Allow Negative Balance',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Permit expenses exceeding current account balance',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: settingsState.allowNegativeBalance,
                    onChanged: (val) => ref
                        .read(settingsProvider.notifier)
                        .toggleAllowNegativeBalance(val),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  ListTile(
                    leading: const Icon(
                      Icons.category_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: Text(
                      'Manage Categories',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Add or edit custom income and expense categories',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryManagementScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Data & Backup Section
            _buildSectionHeader('Data & System'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.download_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: Text(
                      'Download Transaction Ledger',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Customize and save your complete history as CSV',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LedgerExportScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  ListTile(
                    leading: const Icon(
                      Icons.upload_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    title: Text(
                      'Import Data (Restore)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Placeholder for future JSON restore',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: const Chip(
                      label: Text('Soon', style: TextStyle(fontSize: 10)),
                      backgroundColor: AppColors.primaryLight,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: AppColors.expense,
                      size: 20,
                    ),
                    title: Text(
                      'Clear All Data',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.expense,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently delete all accounts, transactions, and categories',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () => _handleClearAllData(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // App Info Section
            _buildSectionHeader('App Info'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Wallet v1.0.0',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Production Quality Offline-First Finance App',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Built with Flutter, Hive, and Riverpod. Completely private with local encrypted credentials.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
