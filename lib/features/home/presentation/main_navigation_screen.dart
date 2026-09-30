import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../analytics/presentation/analytics_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../loans/presentation/loans_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../transactions/data/transaction_model.dart';
import '../../transactions/presentation/add_edit_transaction_screen.dart';
import '../../transactions/presentation/transaction_history_screen.dart';

/// Four destinations leave the center slot for a single, prominent add action.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;

  void _openTransaction(TransactionType type) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AddEditTransactionScreen(initialType: type),
    ));
  }

  void _showAddActions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add to your wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _actionTile(sheetContext, Icons.arrow_downward_rounded, 'Record income',
              'Money received into an account', AppColors.income,
              () => _openTransaction(TransactionType.income)),
            _actionTile(sheetContext, Icons.arrow_upward_rounded, 'Record expense',
              'Money spent from an account', AppColors.expense,
              () => _openTransaction(TransactionType.expense)),
            _actionTile(sheetContext, Icons.receipt_long_rounded, 'View transactions',
              'Search and review your history', AppColors.primary,
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const TransactionHistoryScreen()))),
          ]),
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext sheetContext, IconData icon, String title,
      String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.11),
        child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: () {
        Navigator.of(sheetContext).pop();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onNavigateTab: (index) => setState(() => _index = index)),
      const LoansScreen(),
      const AnalyticsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: 'wallet_center_add',
        tooltip: 'Add to wallet',
        elevation: 4,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: _showAddActions,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 72,
        padding: EdgeInsets.zero,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SafeArea(top: false, child: Row(children: [
          _destination(0, Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Home'),
          _destination(1, Icons.handshake_outlined, Icons.handshake_rounded, 'Loans'),
          const SizedBox(width: 76),
          _destination(2, Icons.insights_outlined, Icons.insights_rounded, 'Analytics'),
          _destination(3, Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
        ])),
      ),
    );
  }

  Widget _destination(int index, IconData icon, IconData selectedIcon, String label) {
    final selected = _index == index;
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Expanded(child: InkWell(
      onTap: () => setState(() => _index = index),
      borderRadius: BorderRadius.circular(14),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(selected ? selectedIcon : icon, color: color, size: 23),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    ));
  }
}
