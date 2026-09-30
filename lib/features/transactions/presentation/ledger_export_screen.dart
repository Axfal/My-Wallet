import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/account_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/ledger_export.dart';
import '../providers/transaction_provider.dart';

class LedgerExportScreen extends ConsumerStatefulWidget {
  const LedgerExportScreen({super.key});
  @override
  ConsumerState<LedgerExportScreen> createState() => _LedgerExportScreenState();
}

class _LedgerExportScreenState extends ConsumerState<LedgerExportScreen> {
  DateTimeRange? _range;
  String? _accountId, _categoryId;
  final Set<LedgerKind> _kinds = LedgerKind.values.toSet();
  final _search = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _selectDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (range != null) setState(() => _range = range);
  }

  Future<void> _export(LedgerResult ledger, String symbol) async {
    if (_saving || ledger.rows.isEmpty) return;
    setState(() => _saving = true);
    try {
      final name =
          'my_wallet_ledger_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final scope = _range == null
          ? 'All time'
          : '${DateFormat('yyyy-MM-dd').format(_range!.start)} to ${DateFormat('yyyy-MM-dd').format(_range!.end)}';
      final bytes = utf8.encode(
        LedgerExport.csv(ledger, currency: symbol, scope: scope),
      );
      if (Platform.isAndroid) {
        final saved =
            await const MethodChannel(
              'com.mywallet.app/ledger_export',
            ).invokeMethod<bool>('saveCsv', {
              'name': name,
              'bytes': Uint8List.fromList(bytes),
            });
        if (saved == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ledger saved to the selected location.'),
            ),
          );
        }
      } else {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}${Platform.pathSeparator}$name');
        await file.writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'text/csv')],
            fileNameOverrides: [name],
            subject: 'My Wallet ledger',
            sharePositionOrigin: Rect.fromLTWH(
              0,
              0,
              MediaQuery.sizeOf(context).width,
              1,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export ledger: $error')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    final categories = ref.watch(categoryProvider).categories;
    final transactions = ref.watch(transactionProvider).transactions;
    final symbol = ref.watch(settingsProvider).currencySymbol;
    final entries = LedgerExport.entries(
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      loans: HiveService.loansBox.values,
      people: HiveService.peopleBox.values,
      repayments: HiveService.repaymentsBox.values,
    );
    final ledger = LedgerExport.build(
      accounts: accounts,
      entries: entries,
      filter: LedgerFilter(
        start: _range?.start,
        end: _range == null
            ? null
            : DateTime(
                _range!.end.year,
                _range!.end.month,
                _range!.end.day,
                23,
                59,
                59,
                999,
              ),
        accountId: _accountId,
        categoryId: _categoryId,
        kinds: _kinds,
        query: _search.text,
      ),
    );
    String money(int value) =>
        CurrencyFormatter.formatMinor(value, symbol: symbol);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export ledger'),
        backgroundColor: AppColors.surface,
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Choose what to include',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Export a CSV ledger you can save to your device or open in a spreadsheet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _selectDates,
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(
                        _range == null
                            ? 'All dates'
                            : '${DateFormat.yMMMd().format(_range!.start)} – ${DateFormat.yMMMd().format(_range!.end)}',
                      ),
                    ),
                    if (_range != null)
                      TextButton(
                        onPressed: () => setState(() => _range = null),
                        child: const Text('Use all dates'),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: _accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All accounts'),
                        ),
                        ...accounts.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All categories'),
                        ),
                        ...categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _categoryId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Search notes, people, accounts or amounts',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Movement types',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final kind in LedgerKind.values)
                          FilterChip(
                            label: Text(kind.label),
                            selected: _kinds.contains(kind),
                            selectedColor: AppColors.primaryLight,
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _kinds.add(kind);
                              } else {
                                _kinds.remove(kind);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ledger.rows.length} ledger entries',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _summary('Opening balance', money(ledger.openingMinor)),
                    _summary('Income', money(ledger.incomeMinor)),
                    _summary('Expenses', money(ledger.expenseMinor)),
                    const Divider(),
                    _summary('Closing balance', money(ledger.closingMinor)),
                    const SizedBox(height: 8),
                    const Text(
                      'Balances include all movements in the selected period, even when a type, category or search filter hides a row.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving || ledger.rows.isEmpty
                  ? null
                  : () => _export(ledger, symbol),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                _saving ? 'Preparing ledger…' : 'Download CSV ledger',
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _summary(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
