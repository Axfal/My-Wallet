import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/attachment_service.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/account_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/loan_models.dart';
import '../data/loan_repository.dart';

final loanRevisionProvider = StateProvider<int>((ref) => 0);

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});
  @override ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  String query = '';
  String filter = 'All';
  @override Widget build(BuildContext context) {
    ref.watch(loanRevisionProvider);
    final loans = HiveService.loansBox.values.toList()..sort((a,b) => b.issuedAt.compareTo(a.issuedAt));
    final people = {for (final p in HiveService.peopleBox.values) p.id: p};
    final symbol = ref.watch(settingsProvider).currencySymbol;
    final receivable = loans.where((l) => !l.cancelled && l.type == LoanType.given)
        .fold<int>(0, (n,l) => n + l.outstandingAmountMinor);
    final payable = loans.where((l) => !l.cancelled && l.type == LoanType.taken)
        .fold<int>(0, (n,l) => n + l.outstandingAmountMinor);
    final overdueGiven = loans.where((l) => l.type == LoanType.given && l.status == 'Overdue').length;
    final overdueTaken = loans.where((l) => l.type == LoanType.taken && l.status == 'Overdue').length;
    final shown = loans.where((l) {
      final p = people[l.personId];
      final text = '${p?.fullName} ${p?.phoneNumber} ${l.note} ${l.originalAmountMinor / 100}'.toLowerCase();
      return text.contains(query.toLowerCase()) && (filter == 'All' ||
        (filter == 'Given' && l.type == LoanType.given) ||
        (filter == 'Taken' && l.type == LoanType.taken) || filter == l.status);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Loans & People')),
      floatingActionButton: FloatingActionButton.extended(heroTag: 'loan_add', onPressed: () => _openLoan(),
        icon: const Icon(Icons.add), label: const Text('New loan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [Expanded(child: _summary('People owe me', receivable, symbol)),
          const SizedBox(width: 10), Expanded(child: _summary('I owe', payable, symbol))]),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Overdue: $overdueGiven receivable · $overdueTaken payable',
            style: const TextStyle(color: Colors.deepOrange))),
        const SizedBox(height: 12),
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, phone, note or amount', border: OutlineInputBorder()),
          onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:
          ['All','Given','Taken','Active','Partially Paid','Paid','Overdue','Cancelled'].map((v) =>
            Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(v),
              selected: filter == v, onSelected: (_) => setState(() => filter = v)))).toList())),
        const SizedBox(height: 12),
        if (shown.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No loans here yet'))),
        ...shown.map((l) {
          final p = people[l.personId];
          return Card(child: ListTile(
            leading: CircleAvatar(child: Icon(l.type == LoanType.given ? Icons.arrow_outward : Icons.south_west)),
            title: Text(p?.fullName ?? 'Unknown person'),
            subtitle: Text('${l.type == LoanType.given ? 'Given' : 'Taken'} · ${l.status} · Due ${l.dueAt.day}/${l.dueAt.month}/${l.dueAt.year}'),
            trailing: Text(CurrencyFormatter.formatMinor(l.outstandingAmountMinor, symbol: symbol)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(id: l.id))),
          ));
        }),
        const SizedBox(height: 80),
      ]),
    );
  }
  Widget _summary(String label, int amount, String symbol) => Card(child: Padding(
    padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label, style: const TextStyle(fontSize: 12)), const SizedBox(height: 6),
        Text(CurrencyFormatter.formatMinor(amount, symbol: symbol), style: const TextStyle(fontWeight: FontWeight.bold))])));
  void _openLoan() => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanFormScreen()));
}

class LoanFormScreen extends ConsumerStatefulWidget {
  final Loan? loan;
  const LoanFormScreen({super.key, this.loan});
  @override ConsumerState<LoanFormScreen> createState() => _LoanFormScreenState();
}
class _LoanFormScreenState extends ConsumerState<LoanFormScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), phone = TextEditingController(), amount = TextEditingController();
  final note = TextEditingController(), relationship = TextEditingController();
  final whatsapp = TextEditingController(), address = TextEditingController(), reference = TextEditingController();
  LoanType type = LoanType.given;
  String? accountId;
  DateTime due = DateTime.now().add(const Duration(days: 30));
  DateTime issued = DateTime.now();
  DateTime? reminder;
  bool busy = false;
  String? proofPath;
  @override void initState() { super.initState();
    final l = widget.loan;
    if (l != null) {
      final p = HiveService.peopleBox.get(l.personId);
      name.text = p?.fullName ?? ''; phone.text = p?.phoneNumber ?? '';
      relationship.text = p?.relationship ?? ''; note.text = l.note ?? '';
      whatsapp.text = p?.whatsappNumber ?? ''; address.text = p?.address ?? '';
      reference.text = l.referenceNumber ?? ''; reminder = l.reminderAt;
      amount.text = (l.originalAmountMinor / 100).toString(); type = l.type;
      accountId = l.accountId; due = l.dueAt; issued = l.issuedAt;
      proofPath = l.proofPath;
    }
  }
  @override void dispose() { for (final c in [name,phone,amount,note,relationship,whatsapp,address,reference]) {c.dispose();} super.dispose(); }
  @override Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    accountId ??= accounts.isEmpty ? null : accounts.first.id;
    return Scaffold(appBar: AppBar(title: Text(widget.loan == null ? 'New loan' : 'Edit loan')),
      body: Form(key: form, child: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<LoanType>(segments: const [ButtonSegment(value: LoanType.given, label: Text('Money I gave')),
          ButtonSegment(value: LoanType.taken, label: Text('Money I took'))],
          selected: {type}, onSelectionChanged: (v) => setState(() => type = v.first)),
        const SizedBox(height: 12),
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Full name'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
        TextFormField(controller: phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
        TextFormField(controller: whatsapp, decoration: const InputDecoration(labelText: 'WhatsApp (optional)')),
        TextFormField(controller: address, decoration: const InputDecoration(labelText: 'Address / location (optional)')),
        TextFormField(controller: relationship, decoration: const InputDecoration(labelText: 'Relationship')),
        TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'), validator: (v) =>
            (CurrencyFormatter.parseToMinor(v ?? '') ?? 0) <= 0 ? 'Enter a positive amount' : null),
        DropdownButtonFormField<String>(initialValue: accountId,
          decoration: const InputDecoration(labelText: 'Account'), items: accounts.map((a) =>
            DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
          onChanged: (v) => setState(() => accountId = v),
          validator: (v) => v == null ? 'Create an account first' : null),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Loan date and time'),
          subtitle: Text('${issued.day}/${issued.month}/${issued.year}  ${issued.hour.toString().padLeft(2, '0')}:${issued.minute.toString().padLeft(2, '0')}'),
          onTap: () async { final d = await showDatePicker(context: context,
            firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: issued);
            if (d == null || !context.mounted) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(issued));
            if (t != null) setState(() => issued = DateTime(d.year,d.month,d.day,t.hour,t.minute)); }),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Expected repayment date'),
          subtitle: Text('${due.day}/${due.month}/${due.year}  ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}'), trailing: const Icon(Icons.calendar_today),
          onTap: () async { final d = await showDatePicker(context: context,
            firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: due);
            if (d == null || !context.mounted) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(due));
            if (t != null) setState(() => due = DateTime(d.year,d.month,d.day,t.hour,t.minute)); }),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Reminder date (optional)'),
          subtitle: Text(reminder == null ? 'None' : '${reminder!.day}/${reminder!.month}/${reminder!.year}'),
          onTap: () async { final d = await showDatePicker(context: context,
            firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: reminder ?? due);
            if (d != null) setState(() => reminder = d); }),
        TextFormField(controller: reference, decoration: const InputDecoration(labelText: 'Reference number (optional)')),
        TextFormField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        TextButton.icon(onPressed: () async { try { final path = await AttachmentService().pickAndSaveImage();
          if (path != null) setState(() => proofPath = path);
        } catch(e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } },
          icon: const Icon(Icons.attach_file), label: Text(proofPath == null ? 'Attach proof image' : 'Proof image attached')),
        const SizedBox(height: 24),
        FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save loan')),
      ])));
  }
  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final now = DateTime.now(), old = widget.loan;
      final person = Person(id: old?.personId ?? const Uuid().v4(), fullName: name.text.trim(),
        phoneNumber: phone.text.trim(), whatsappNumber: whatsapp.text.trim(),
        address: address.text.trim(), relationship: relationship.text.trim(),
        createdAt: HiveService.peopleBox.get(old?.personId)?.createdAt ?? now, updatedAt: now);
      final minor = CurrencyFormatter.parseToMinor(amount.text)!;
      await LoanRepository().saveLoan(Loan(id: old?.id ?? const Uuid().v4(), personId: person.id,
        accountId: accountId!, type: type, originalAmountMinor: minor,
        outstandingAmountMinor: minor, issuedAt: issued,
        dueAt: due, reminderAt: reminder, note: note.text.trim(),
        referenceNumber: reference.text.trim(), proofPath: proofPath,
        cancelled: old?.cancelled ?? false, writeOffReason: old?.writeOffReason,
        createdAt: old?.createdAt ?? now, updatedAt: now), person);
      ref.read(accountProvider.notifier).loadAccounts();
      ref.read(loanRevisionProvider.notifier).state++;
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
}

class LoanDetailScreen extends ConsumerWidget {
  final String id;
  const LoanDetailScreen({super.key, required this.id});
  @override Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(loanRevisionProvider);
    final loan = HiveService.loansBox.get(id);
    if (loan == null) return const Scaffold(body: Center(child: Text('Loan removed')));
    final person = HiveService.peopleBox.get(loan.personId);
    final payments = HiveService.repaymentsBox.values.where((p) => p.loanId == id).toList()
      ..sort((a,b) => b.paidAt.compareTo(a.paidAt));
    final symbol = ref.watch(settingsProvider).currencySymbol;
    return Scaffold(appBar: AppBar(title: Text(person?.fullName ?? 'Loan'), actions: [
      IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => LoanFormScreen(loan: loan)))),
      IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
        final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text('Delete loan?'), content: const Text('Its account movement will be reversed. Remove repayments first.'),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
        if (ok != true) return;
        try { await LoanRepository().deleteLoan(id);
          ref.read(accountProvider.notifier).loadAccounts(); ref.read(loanRevisionProvider.notifier).state++;
          if (context.mounted) Navigator.pop(context);
        } catch(e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
      }),
    ]), body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(loan.type == LoanType.given ? 'Money owed to me' : 'Money I owe'),
        Text(CurrencyFormatter.formatMinor(loan.outstandingAmountMinor, symbol: symbol),
          style: Theme.of(context).textTheme.headlineMedium),
        Text('${loan.status} · Original ${CurrencyFormatter.formatMinor(loan.originalAmountMinor, symbol: symbol)}'),
        Text('Due ${loan.dueAt.day}/${loan.dueAt.month}/${loan.dueAt.year}'),
        if (person != null) Text('${person.phoneNumber} ${person.relationship ?? ''}'),
        if (loan.note?.isNotEmpty == true) Text(loan.note!),
        if (loan.writeOffReason != null) Text('Write-off reason: ${loan.writeOffReason}'),
        if (loan.proofPath != null) const Text('Proof image attached'),
        if (loan.proofPath != null && File(loan.proofPath!).existsSync())
          Image.file(File(loan.proofPath!), height: 150, fit: BoxFit.cover),
      ]))),
      const SizedBox(height: 12),
      if (loan.outstandingAmountMinor > 0 && !loan.cancelled) FilledButton.icon(icon: const Icon(Icons.payments),
        label: const Text('Record repayment'), onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RepaymentFormScreen(loan: loan)))),
      if (loan.outstandingAmountMinor > 0 && !loan.cancelled)
        OutlinedButton.icon(icon: const Icon(Icons.block_outlined),
          label: const Text('Write off / cancel loan'), onPressed: () async {
            final reason = TextEditingController();
            final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: const Text('Write off this loan?'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('This closes the amount owed. Past account movements stay recorded. Explain why:'),
                TextField(controller: reason, minLines: 2, maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Reason')),
              ]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep active')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Write off'))]));
            if (confirmed == true) {
              try { await LoanRepository().writeOffLoan(id, reason.text);
                ref.read(loanRevisionProvider.notifier).state++;
              } catch(e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
            }
            reason.dispose();
          }),
      const SizedBox(height: 16),
      Text('Repayment timeline', style: Theme.of(context).textTheme.titleMedium),
      if (payments.isEmpty) const ListTile(title: Text('No repayments yet')),
      ...payments.map((p) => Card(child: ListTile(
        onTap: loan.cancelled ? null : () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RepaymentFormScreen(loan: loan, repayment: p))),
        title: Text(CurrencyFormatter.formatMinor(p.amountMinor, symbol: symbol)),
        subtitle: Text('${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year} · ${p.note ?? ''}'),
        leading: p.proofPath == null ? null : const Icon(Icons.attach_file),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
          final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
            title: const Text('Delete repayment?'), content: const Text('The account balance and outstanding amount will be restored.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
          if (ok == true) { try { await LoanRepository().deleteRepayment(p.id);
            ref.read(accountProvider.notifier).loadAccounts(); ref.read(loanRevisionProvider.notifier).state++;
          } catch(e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }
        }),
      ))),
    ]));
  }
}

class RepaymentFormScreen extends ConsumerStatefulWidget {
  final Loan loan;
  final LoanRepayment? repayment;
  const RepaymentFormScreen({super.key, required this.loan, this.repayment});
  @override ConsumerState<RepaymentFormScreen> createState() => _RepaymentFormScreenState();
}
class _RepaymentFormScreenState extends ConsumerState<RepaymentFormScreen> {
  final amount = TextEditingController(), note = TextEditingController();
  String? accountId;
  DateTime paidAt = DateTime.now();
  bool busy = false;
  String? proofPath;
  @override void initState() { super.initState();
    final p = widget.repayment;
    if (p != null) { amount.text = (p.amountMinor / 100).toStringAsFixed(2);
      note.text = p.note ?? ''; accountId = p.accountId;
      paidAt = p.paidAt; proofPath = p.proofPath; }
  }
  @override void dispose() { amount.dispose(); note.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    accountId ??= accounts.isEmpty ? null : accounts.first.id;
    return Scaffold(appBar: AppBar(title: Text(widget.repayment == null ? 'Record repayment' : 'Edit repayment')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Remaining: ${CurrencyFormatter.formatMinor(widget.loan.outstandingAmountMinor)}'),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Repayment amount')),
        DropdownButtonFormField<String>(initialValue: accountId,
          decoration: InputDecoration(labelText: widget.loan.type == LoanType.given ? 'Receiving account' : 'Paying account'),
          items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
          onChanged: (v) => setState(() => accountId = v)),
        ListTile(title: const Text('Date'), subtitle: Text('${paidAt.day}/${paidAt.month}/${paidAt.year}'),
          onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2000),
            lastDate: DateTime(2100), initialDate: paidAt);
            if (d == null || !context.mounted) return;
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(paidAt));
            if (t != null) setState(() => paidAt = DateTime(d.year,d.month,d.day,t.hour,t.minute)); }),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        TextButton.icon(onPressed: () async { try { final path = await AttachmentService().pickAndSaveImage();
          if (path != null) setState(() => proofPath = path);
        } catch(e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } },
          icon: const Icon(Icons.attach_file), label: Text(proofPath == null ? 'Attach proof image' : 'Proof image attached')),
        const SizedBox(height: 24), FilledButton(onPressed: busy ? null : _save,
          child: Text(busy ? 'Saving…' : 'Save repayment')),
      ]));
  }
  Future<void> _save() async {
    final minor = CurrencyFormatter.parseToMinor(amount.text);
    if (minor == null || minor <= 0 || accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount and account'))); return;
    }
    setState(() => busy = true);
    try { await LoanRepository().saveRepayment(LoanRepayment(id: widget.repayment?.id ?? const Uuid().v4(),
      loanId: widget.loan.id, accountId: accountId!, amountMinor: minor,
      paidAt: paidAt, createdAt: DateTime.now(), note: note.text.trim(), proofPath: proofPath));
      ref.read(accountProvider.notifier).loadAccounts(); ref.read(loanRevisionProvider.notifier).state++;
      if (mounted) Navigator.pop(context);
    } catch(e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
}
