import 'package:flutter/material.dart';

import '../models/pawntrack_models.dart';
import '../services/pawntrack_ai_service.dart';
import '../widgets/stat_card.dart';

class NewPawnDraft {
  const NewPawnDraft({
    required this.customerName,
    required this.phone,
    required this.customerIdNumber,
    required this.emergencyContact,
    required this.addressArea,
    required this.item,
    required this.category,
    required this.itemSerial,
    required this.proofOfOwnership,
    required this.testingChecklist,
    required this.storageLocation,
    required this.staffMember,
    required this.loanAmount,
    required this.interestAmount,
    required this.totalPayback,
    required this.dateGiven,
    required this.dueDate,
    required this.riskScore,
  });

  final String customerName;
  final String phone;
  final String customerIdNumber;
  final String emergencyContact;
  final String addressArea;
  final String item;
  final String category;
  final String itemSerial;
  final String proofOfOwnership;
  final String testingChecklist;
  final String storageLocation;
  final String staffMember;
  final double loanAmount;
  final double interestAmount;
  final double totalPayback;
  final String dateGiven;
  final String dueDate;
  final int riskScore;
}

class HomeCommandCentreScreen extends StatelessWidget {
  const HomeCommandCentreScreen({super.key, required this.model, required this.onOpen, required this.onRunCommand});

  final PawnTrackModel model;
  final ValueChanged<int> onOpen;
  final ValueChanged<String> onRunCommand;

  @override
  Widget build(BuildContext context) {
    final inventoryReady = model.availableInventory.where((item) => item.value > 0).length;
    return _OpsScaffold(
      title: 'Daily Command Centre',
      subtitle: 'Last Resort Pawnshop',
      children: [
        _MetricGrid(cards: [
          StatCard(label: 'Cash collected today', value: moneyFormat.format(_cashCollectedToday(model)), tone: Colors.green),
          StatCard(label: 'Expected cash today', value: moneyFormat.format(model.dueToday), tone: Colors.blue),
          StatCard(label: 'Expected cash this week', value: moneyFormat.format(model.due7), tone: Colors.indigo),
          StatCard(label: 'Loans due today', value: '${model.dueTodayLoans.length}', tone: Colors.orange),
          StatCard(label: 'Overdue loans', value: '${model.overdue.length}', tone: Colors.red),
          StatCard(label: 'High-risk borrowers', value: '${model.highRiskBorrowers.length}', tone: Colors.deepOrange),
          StatCard(label: 'Inventory ready to sell', value: '$inventoryReady', tone: Colors.teal),
          StatCard(label: 'Profit forecast', value: moneyFormat.format(model.expectedNetProfit), tone: Colors.purple),
        ]),
        _Panel(
          title: 'Primary Actions',
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            _ActionButton(icon: Icons.add_business, label: 'New Pawn', onTap: () => onOpen(1)),
            _ActionButton(icon: Icons.payments, label: 'Take Repayment', onTap: () => onOpen(3)),
            _ActionButton(icon: Icons.event_repeat, label: 'Extend Loan', onTap: () => onOpen(3)),
            _ActionButton(icon: Icons.sell, label: 'Mark Item Sold', onTap: () => onOpen(7)),
            _ActionButton(icon: Icons.sms, label: 'Send Reminder', onTap: () => onOpen(4)),
            _ActionButton(icon: Icons.record_voice_over, label: 'Voice Command', onTap: () => _showAiQuestionPanel(context)),
          ]),
        ),
        _TwoColumn(
          left: _Panel(
            title: 'Due Today',
            child: _LoanList(loans: model.dueTodayLoans, empty: 'No loans due today.'),
          ),
          right: _Panel(
            title: 'Overdue Collections',
            child: _LoanList(loans: model.overdue.take(8).toList(), empty: 'No overdue loans.'),
          ),
        ),
      ],
    );
  }

  void _showAiQuestionPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _VoiceCommandPanel(model: model, onRunCommand: onRunCommand),
            ),
          ),
        );
      },
    );
  }
}

class NewPawnScreen extends StatefulWidget {
  const NewPawnScreen({super.key, required this.model, required this.onCreate, required this.writeStatus});

  final PawnTrackModel model;
  final Future<void> Function(NewPawnDraft draft) onCreate;
  final String writeStatus;

  @override
  State<NewPawnScreen> createState() => _NewPawnScreenState();
}

class _NewPawnScreenState extends State<NewPawnScreen> {
  final customer = TextEditingController();
  final phone = TextEditingController();
  final omang = TextEditingController();
  final emergency = TextEditingController();
  final address = TextEditingController();
  final item = TextEditingController();
  final category = TextEditingController();
  final serial = TextEditingController();
  final proof = TextEditingController();
  final testing = TextEditingController();
  final storage = TextEditingController();
  final staff = TextEditingController(text: 'Last Resort staff');
  final loan = TextEditingController();
  final interest = TextEditingController();
  final total = TextEditingController();
  final dateGiven = TextEditingController(text: dateInputValue(today));
  final dueDate = TextEditingController(text: dateInputValue(today.add(const Duration(days: 14))));

  @override
  void dispose() {
    for (final controller in [customer, phone, omang, emergency, address, item, category, serial, proof, testing, storage, staff, loan, interest, total, dateGiven, dueDate]) {
      controller.dispose();
    }
    super.dispose();
  }

  int get riskScore => estimateNewLoanRisk(widget.model, customer.text, parseNumber(loan.text), omang.text);

  @override
  Widget build(BuildContext context) {
    final risk = riskBand(riskScore.toDouble());
    return _OpsScaffold(
      title: 'New Pawn',
      subtitle: 'Capture customer, item, offer, proof, and risk before cash leaves the shop.',
      children: [
        _Panel(
          title: 'Borrower Risk Before Offer',
          child: Row(children: [
            CircleAvatar(radius: 28, backgroundColor: Color(risk.colorHex), child: Text('$riskScore', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
            const SizedBox(width: 12),
            Expanded(child: Text('${risk.label}. Based on existing exposure, overdue history, duplicate customer matches, and requested amount.')),
          ]),
        ),
        _Panel(
          title: 'Customer Details',
          child: _ResponsiveForm(children: [
            _Field(controller: customer, label: 'Customer name', onChanged: (_) => setState(() {})),
            _Field(controller: phone, label: 'Phone number'),
            _Field(controller: omang, label: 'Customer ID / Omang', onChanged: (_) => setState(() {})),
            _Field(controller: emergency, label: 'Emergency contact'),
            _Field(controller: address, label: 'Address / area'),
          ]),
        ),
        _Panel(
          title: 'Item, Proof, and Storage',
          child: _ResponsiveForm(children: [
            _Field(controller: item, label: 'Item pawned'),
            _Field(controller: category, label: 'Category'),
            _Field(controller: serial, label: 'Serial number / IMEI'),
            _Field(controller: proof, label: 'Proof of ownership'),
            _Field(controller: testing, label: 'Testing checklist'),
            _Field(controller: storage, label: 'Storage location'),
            _Field(controller: staff, label: 'Staff member'),
          ]),
        ),
        _Panel(
          title: 'Loan Terms',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _ResponsiveForm(children: [
              _Field(controller: loan, label: 'Loan amount', keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
              _Field(controller: interest, label: 'Interest amount', keyboardType: TextInputType.number),
              _Field(controller: total, label: 'Total payback', keyboardType: TextInputType.number),
              _Field(controller: dateGiven, label: 'Date given', hint: 'YYYY-MM-DD'),
              _Field(controller: dueDate, label: 'Due date', hint: 'YYYY-MM-DD'),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Create Pawn and Sync Sheet'),
              onPressed: () async {
                final principal = parseNumber(loan.text);
                final interestAmount = parseNumber(interest.text);
                final totalPayback = parseNumber(total.text) == 0 ? principal + interestAmount : parseNumber(total.text);
                await widget.onCreate(NewPawnDraft(
                  customerName: customer.text.trim(),
                  phone: phone.text.trim(),
                  customerIdNumber: omang.text.trim(),
                  emergencyContact: emergency.text.trim(),
                  addressArea: address.text.trim(),
                  item: item.text.trim(),
                  category: category.text.trim(),
                  itemSerial: serial.text.trim(),
                  proofOfOwnership: proof.text.trim(),
                  testingChecklist: testing.text.trim(),
                  storageLocation: storage.text.trim(),
                  staffMember: staff.text.trim(),
                  loanAmount: principal,
                  interestAmount: interestAmount,
                  totalPayback: totalPayback,
                  dateGiven: dateGiven.text.trim(),
                  dueDate: dueDate.text.trim(),
                  riskScore: riskScore,
                ));
              },
            ),
            const SizedBox(height: 8),
            Text(widget.writeStatus),
          ]),
        ),
      ],
    );
  }
}

class ActivePawnsOpsScreen extends StatelessWidget {
  const ActivePawnsOpsScreen({super.key, required this.model, required this.onForfeit, required this.onOpenRepayments});

  final PawnTrackModel model;
  final Future<void> Function(LoanRecord loan) onForfeit;
  final VoidCallback onOpenRepayments;

  @override
  Widget build(BuildContext context) {
    final active = model.active.where((loan) => loan.remaining > 0).toList();
    return _OpsScaffold(
      title: 'Active Pawns',
      subtitle: 'Live pawn contracts with repayment, extension, reminder, and forfeiture actions.',
      children: [
        _MetricGrid(cards: [
          StatCard(label: 'Active principal', value: moneyFormat.format(active.fold(0.0, (sum, loan) => sum + loan.loan)), tone: Colors.blue),
          StatCard(label: 'Remaining balance', value: moneyFormat.format(active.fold(0.0, (sum, loan) => sum + loan.remaining)), tone: Colors.indigo),
          StatCard(label: 'Due today', value: '${model.dueTodayLoans.length}', tone: Colors.orange),
          StatCard(label: 'Overdue', value: '${model.overdue.length}', tone: Colors.red),
        ]),
        _Panel(
          title: 'Active Pawn Register',
          child: Column(children: active.map((loan) => _LoanActionTile(loan: loan, onRepay: onOpenRepayments, onForfeit: () => onForfeit(loan))).toList()),
        ),
      ],
    );
  }
}

class RepaymentsScreen extends StatefulWidget {
  const RepaymentsScreen({super.key, required this.model, required this.selectedLoanId, required this.onSelectLoan, required this.onSave, required this.writeStatus});

  final PawnTrackModel model;
  final String? selectedLoanId;
  final ValueChanged<String> onSelectLoan;
  final Future<void> Function(LoanRecord loan, String paymentAmount, String dueDate) onSave;
  final String writeStatus;

  @override
  State<RepaymentsScreen> createState() => _RepaymentsScreenState();
}

class _RepaymentsScreenState extends State<RepaymentsScreen> {
  final amount = TextEditingController();
  final dueDate = TextEditingController();
  final reason = TextEditingController();

  @override
  void dispose() {
    amount.dispose();
    dueDate.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final openLoans = widget.model.loans.where((loan) => loan.remaining > 0).toList();
    final selected = openLoans.where((loan) => loan.id == widget.selectedLoanId).firstOrNull ?? openLoans.firstOrNull;
    if (selected != null && dueDate.text.isEmpty) dueDate.text = dateInputValue(selected.dueDate);
    return _OpsScaffold(
      title: 'Repayments',
      subtitle: 'Take repayment or extend due date from one fast counter screen.',
      children: [
        _Panel(
          title: 'Take Repayment / Extend Loan',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: selected?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Customer / loan', border: OutlineInputBorder()),
              items: openLoans.map((loan) => DropdownMenuItem(value: loan.id, child: Text('${loan.client} - ${loan.item} - ${moneyFormat.format(loan.remaining)}'))).toList(),
              onChanged: (id) {
                if (id == null) return;
                widget.onSelectLoan(id);
                dueDate.text = dateInputValue(openLoans.firstWhere((loan) => loan.id == id).dueDate);
              },
            ),
            const SizedBox(height: 12),
            _ResponsiveForm(children: [
              _Field(controller: amount, label: 'Repayment amount', keyboardType: TextInputType.number),
              _Field(controller: dueDate, label: 'New due date', hint: 'YYYY-MM-DD'),
              _Field(controller: reason, label: 'Correction / extension reason'),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.payments),
              label: const Text('Save Repayment / Extension'),
              onPressed: selected == null
                  ? null
                  : () async {
                      await widget.onSave(selected, amount.text, dueDate.text);
                      amount.clear();
                    },
            ),
            const SizedBox(height: 8),
            Text(widget.writeStatus),
          ]),
        ),
        _Panel(title: 'Open Loans', child: _LoanList(loans: openLoans.take(15).toList(), empty: 'No open loans.')),
      ],
    );
  }
}

class OverdueCollectionsScreen extends StatelessWidget {
  const OverdueCollectionsScreen({super.key, required this.model, required this.onOpenRepayments, required this.onForfeit});

  final PawnTrackModel model;
  final VoidCallback onOpenRepayments;
  final Future<void> Function(LoanRecord loan) onForfeit;

  @override
  Widget build(BuildContext context) {
    final overdue = model.overdue..sort((a, b) => b.overdueDays.compareTo(a.overdueDays));
    return _OpsScaffold(
      title: 'Overdue Collections',
      subtitle: 'Prioritise overdue customers and generate WhatsApp reminders.',
      children: [
        _MetricGrid(cards: [
          StatCard(label: 'Overdue loans', value: '${overdue.length}', tone: Colors.red),
          StatCard(label: 'Overdue amount', value: moneyFormat.format(model.overdueAmount), tone: Colors.deepOrange),
          StatCard(label: 'High risk overdue', value: '${overdue.where((loan) => loan.riskScore >= 70).length}', tone: Colors.purple),
          StatCard(label: 'Due this week', value: moneyFormat.format(model.due7), tone: Colors.blue),
        ]),
        _Panel(
          title: 'Collection Queue',
          child: Column(children: overdue.map((loan) => _CollectionTile(loan: loan, onRepay: onOpenRepayments, onForfeit: () => onForfeit(loan))).toList()),
        ),
      ],
    );
  }
}

class BorrowerRiskScreen extends StatefulWidget {
  const BorrowerRiskScreen({super.key, required this.model});

  final PawnTrackModel model;

  @override
  State<BorrowerRiskScreen> createState() => _BorrowerRiskScreenState();
}

class _BorrowerRiskScreenState extends State<BorrowerRiskScreen> {
  final customer = TextEditingController();
  final omang = TextEditingController();
  final amount = TextEditingController();

  @override
  void dispose() {
    customer.dispose();
    omang.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = estimateNewLoanRisk(widget.model, customer.text, parseNumber(amount.text), omang.text);
    final risk = riskBand(score.toDouble());
    return _OpsScaffold(
      title: 'Customers / Borrower Risk',
      subtitle: 'Check repeat exposure and risk before issuing new cash.',
      children: [
        _Panel(
          title: 'Risk Calculator',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _ResponsiveForm(children: [
              _Field(controller: customer, label: 'Customer name', onChanged: (_) => setState(() {})),
              _Field(controller: omang, label: 'Omang / ID', onChanged: (_) => setState(() {})),
              _Field(controller: amount, label: 'Requested amount', keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              CircleAvatar(radius: 26, backgroundColor: Color(risk.colorHex), child: Text('$score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              const SizedBox(width: 12),
              Expanded(child: Text('${risk.label}. Suggested max offer: ${moneyFormat.format(suggestedOffer(parseNumber(amount.text), score))}.')),
            ]),
          ]),
        ),
        _Panel(title: 'High-Risk Borrowers', child: _LoanList(loans: widget.model.highRiskBorrowers, empty: 'No high-risk borrowers right now.')),
      ],
    );
  }
}

class InventoryOpsScreen extends StatelessWidget {
  const InventoryOpsScreen({super.key, required this.model});

  final PawnTrackModel model;

  @override
  Widget build(BuildContext context) {
    return _OpsScaffold(
      title: 'Inventory',
      subtitle: 'Items available, stuck stock, storage, and forfeited goods ready to sell.',
      children: [
        _MetricGrid(cards: [
          StatCard(label: 'Ready to sell', value: '${model.availableInventory.length}', tone: Colors.teal),
          StatCard(label: 'Inventory value', value: moneyFormat.format(model.inventoryValue), tone: Colors.orange),
          StatCard(label: 'Stuck 30+ days', value: '${model.availableInventory.where((item) => item.age == null || item.age! > 30).length}', tone: Colors.red),
          StatCard(label: 'Sold items', value: '${model.soldInventory.length}', tone: Colors.green),
        ]),
        _Panel(
          title: 'Ready To Sell',
          child: Column(children: model.availableInventory.map((item) => _InventoryTile(item: item)).toList()),
        ),
      ],
    );
  }
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, required this.model, required this.selectedInventoryId, required this.onSelectInventory, required this.onMarkSold, required this.writeStatus});

  final PawnTrackModel model;
  final String? selectedInventoryId;
  final ValueChanged<String> onSelectInventory;
  final Future<void> Function(InventoryRecord item, String sellPrice, String pawnedAmount) onMarkSold;
  final String writeStatus;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final sellPrice = TextEditingController();
  final pawned = TextEditingController();

  @override
  void dispose() {
    sellPrice.dispose();
    pawned.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.model.availableInventory;
    final selected = items.where((item) => item.id == widget.selectedInventoryId).firstOrNull ?? items.firstOrNull;
    if (selected != null && sellPrice.text.isEmpty) sellPrice.text = selected.value.round().toString();
    if (selected != null && pawned.text.isEmpty && selected.pawnAmount > 0) pawned.text = selected.pawnAmount.round().toString();
    final price = parseNumber(sellPrice.text);
    final cost = parseNumber(pawned.text);
    return _OpsScaffold(
      title: 'Sales',
      subtitle: 'Mark inventory sold and track actual profit.',
      children: [
        _Panel(
          title: 'Mark Item Sold',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: selected?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Inventory item', border: OutlineInputBorder()),
              items: items.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.product} - ${moneyFormat.format(item.value)}'))).toList(),
              onChanged: (id) {
                if (id == null) return;
                final next = items.firstWhere((item) => item.id == id);
                widget.onSelectInventory(id);
                sellPrice.text = next.value.round().toString();
                pawned.text = next.pawnAmount > 0 ? next.pawnAmount.round().toString() : '';
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            _ResponsiveForm(children: [
              _Field(controller: sellPrice, label: 'Sell price', keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
              _Field(controller: pawned, label: 'Original pawn amount', keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
            ]),
            const SizedBox(height: 8),
            Text('Actual profit: ${moneyFormat.format(price - cost)}'),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.sell),
              label: const Text('Mark Sold and Sync Sheet'),
              onPressed: selected == null ? null : () => widget.onMarkSold(selected, sellPrice.text, pawned.text),
            ),
            const SizedBox(height: 8),
            Text(widget.writeStatus),
          ]),
        ),
        _Panel(
          title: 'Sold Items / Profit',
          child: Column(children: widget.model.soldInventory.map((item) => _InventoryTile(item: item, sold: true)).toList()),
        ),
      ],
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.model});

  final PawnTrackModel model;

  @override
  Widget build(BuildContext context) {
    return _OpsScaffold(
      title: 'Reports',
      subtitle: 'Operational totals without burying the daily workflow in charts.',
      children: [
        _MetricGrid(cards: [
          StatCard(label: 'Outstanding principal', value: moneyFormat.format(model.principalOutstanding), tone: Colors.blue),
          StatCard(label: 'Remaining balance', value: moneyFormat.format(model.remaining), tone: Colors.indigo),
          StatCard(label: 'Collection rate', value: '${(model.collectionRate * 100).round()}%', tone: Colors.green),
          StatCard(label: 'Real sales profit', value: moneyFormat.format(model.salesProfit), tone: Colors.teal),
        ]),
        _Panel(
          title: 'Firebase-Ready Tables',
          child: const Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip('Customers'),
            _Chip('Loans'),
            _Chip('Items'),
            _Chip('Repayments'),
            _Chip('Inventory'),
            _Chip('Sales'),
            _Chip('Risk Scores'),
            _Chip('Staff Users'),
            _Chip('Audit Log'),
            _Chip('WhatsApp Messages'),
            _Chip('Voice Commands'),
          ]),
        ),
      ],
    );
  }
}

class SyncSettingsScreen extends StatelessWidget {
  const SyncSettingsScreen({super.key, required this.model, required this.status, required this.writeStatus, required this.onRefresh});

  final PawnTrackModel model;
  final String status;
  final String writeStatus;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _OpsScaffold(
      title: 'Settings / Google Sheets Sync',
      subtitle: 'Google Sheets remains the business record while Firebase is prepared as the main source of truth.',
      children: [
        _Panel(
          title: 'Sync Status',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _InfoRow(label: 'Read status', value: status),
            _InfoRow(label: 'Write status', value: writeStatus),
            _InfoRow(label: 'Source', value: model.source.source),
            _InfoRow(label: 'Last sync', value: model.source.syncedAt?.toLocal().toString() ?? 'Unknown'),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRefresh, icon: const Icon(Icons.sync), label: const Text('Refresh Google Sheets')),
          ]),
        ),
        _Panel(
          title: 'Sheet Updates Enabled',
          child: const Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip('New pawn'),
            _Chip('Repayment'),
            _Chip('Due date extension'),
            _Chip('Overdue status'),
            _Chip('Forfeiture'),
            _Chip('Inventory sale'),
            _Chip('Profit/loss'),
            _Chip('Cash forecast'),
            _Chip('Risk score'),
          ]),
        ),
      ],
    );
  }
}

class _VoiceCommandPanel extends StatefulWidget {
  const _VoiceCommandPanel({required this.model, required this.onRunCommand});

  final PawnTrackModel model;
  final ValueChanged<String> onRunCommand;

  @override
  State<_VoiceCommandPanel> createState() => _VoiceCommandPanelState();
}

class _VoiceCommandPanelState extends State<_VoiceCommandPanel> {
  final question = TextEditingController();
  final ai = PawnTrackAiService();
  String result = 'Ask Gemini about cash, overdue customers, risk, inventory, reminders, or profit.';
  bool loading = false;

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Ask Gemini',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: question,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Question about live pawnshop data',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.auto_awesome),
          ),
          onSubmitted: (_) => _askGemini(),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          icon: const Icon(Icons.auto_awesome),
          label: Text(loading ? 'Asking Gemini...' : 'Ask Gemini'),
          onPressed: loading ? null : _askGemini,
        ),
        const SizedBox(height: 10),
        if (loading) const LinearProgressIndicator(),
        if (loading) const SizedBox(height: 10),
        SelectableText(result),
      ]),
    );
  }

  Future<void> _askGemini() async {
    final text = question.text.trim();
    widget.onRunCommand(text);
    if (text.isEmpty) {
      setState(() => result = 'Ask a question about the pawnshop data first.');
      return;
    }
    setState(() {
      loading = true;
      result = 'Gemini is checking the live Firestore data...';
    });
    try {
      final answer = await ai.answerQuestion(widget.model, text);
      if (!mounted) return;
      setState(() => result = answer);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        result = 'Gemini is not ready yet. Open Firebase Console > AI Services > AI Logic and finish setup with the Gemini Developer API, then try again.\n\n$error';
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

int estimateNewLoanRisk(PawnTrackModel model, String customerName, double requestedAmount, String idNumber) {
  final normalized = customerName.trim().toLowerCase();
  final matches = model.loans.where((loan) {
    final byName = normalized.isNotEmpty && loan.client.toLowerCase().contains(normalized);
    final byId = idNumber.trim().isNotEmpty && loan.customerIdNumber == idNumber.trim();
    return byName || byId;
  }).toList();
  final openExposure = matches.fold(0.0, (sum, loan) => sum + loan.remaining);
  final overdueCount = matches.where((loan) => loan.overdueDays > 0).length;
  final base = requestedAmount >= 5000 ? 34 : requestedAmount >= 2500 ? 24 : requestedAmount >= 1000 ? 16 : 10;
  final score = base + (openExposure > 0 ? 22 : 0) + (overdueCount * 18) + (matches.length >= 3 ? 12 : 0);
  return score.clamp(5, 95).round();
}

double suggestedOffer(double requestedAmount, int riskScore) {
  if (requestedAmount <= 0) return 0;
  if (riskScore >= 75) return requestedAmount * .45;
  if (riskScore >= 55) return requestedAmount * .65;
  return requestedAmount * .8;
}

double _cashCollectedToday(PawnTrackModel model) {
  return model.loans.where((loan) => loan.dateGiven != null && daysBetween(today, loan.dateGiven!) == 0).fold(0.0, (sum, loan) => sum + loan.paid);
}

String whatsappReminder(LoanRecord loan) {
  return 'Hi ${loan.client}, this is Last Resort Pawnshop. Your pawn for ${loan.item} is overdue by ${loan.overdueDays} days with ${moneyFormat.format(loan.remaining)} remaining. Please pay or contact us today to avoid forfeiture.';
}

class _OpsScaffold extends StatelessWidget {
  const _OpsScaffold({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xff64748b))),
        const SizedBox(height: 16),
        ...children.expand((child) => [child, const SizedBox(height: 16)]),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xffe5e7eb))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: cards.map((card) => SizedBox(width: 220, child: card)).toList());
  }
}

class _ResponsiveForm extends StatelessWidget {
  const _ResponsiveForm({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth >= 780 ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth >= 520 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
      return Wrap(spacing: 12, runSpacing: 12, children: children.map((child) => SizedBox(width: width, child: child)).toList());
    });
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.hint, this.keyboardType, this.onChanged});

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(controller: controller, keyboardType: keyboardType, onChanged: onChanged, decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()));
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 860) return Column(children: [left, const SizedBox(height: 16), right]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 16), Expanded(child: right)]);
    });
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label));
  }
}

class _LoanList extends StatelessWidget {
  const _LoanList({required this.loans, required this.empty});

  final List<LoanRecord> loans;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) return Text(empty);
    return Column(children: loans.map((loan) => _LoanTile(loan: loan)).toList());
  }
}

class _LoanTile extends StatelessWidget {
  const _LoanTile({required this.loan});

  final LoanRecord loan;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: Color(loan.risk.colorHex), child: Text('${loan.riskScore}', style: const TextStyle(color: Colors.white, fontSize: 12))),
      title: Text(loan.client, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${loan.item}\nDue ${dateInputValue(loan.dueDate).ifEmpty('missing')} - ${loan.overdueDays} days overdue'),
      isThreeLine: true,
      trailing: Text(moneyFormat.format(loan.remaining), style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _LoanActionTile extends StatelessWidget {
  const _LoanActionTile({required this.loan, required this.onRepay, required this.onForfeit});

  final LoanRecord loan;
  final VoidCallback onRepay;
  final VoidCallback onForfeit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xffe5e7eb))),
      child: ListTile(
        title: Text(loan.client, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${loan.item}\nPhone ${loan.phone.ifEmpty('missing')} - Storage ${loan.location.ifEmpty('missing')}'),
        isThreeLine: true,
        trailing: Wrap(spacing: 6, children: [
          IconButton.filledTonal(onPressed: onRepay, icon: const Icon(Icons.payments), tooltip: 'Repay or extend'),
          IconButton.filledTonal(onPressed: onForfeit, icon: const Icon(Icons.inventory_2), tooltip: 'Move forfeited item to inventory'),
        ]),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.loan, required this.onRepay, required this.onForfeit});

  final LoanRecord loan;
  final VoidCallback onRepay;
  final VoidCallback onForfeit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: loan.riskScore >= 70 ? const Color(0xfffff1f2) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xffe5e7eb))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${loan.client} - ${moneyFormat.format(loan.remaining)}', style: const TextStyle(fontWeight: FontWeight.w900))),
            Text('${loan.overdueDays} days', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.red)),
          ]),
          const SizedBox(height: 6),
          Text(whatsappReminder(loan)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            FilledButton.tonalIcon(onPressed: onRepay, icon: const Icon(Icons.payments), label: const Text('Repay / Extend')),
            FilledButton.tonalIcon(onPressed: onForfeit, icon: const Icon(Icons.inventory), label: const Text('Forfeit to Inventory')),
          ]),
        ]),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.item, this.sold = false});

  final InventoryRecord item;
  final bool sold;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(sold ? Icons.sell : Icons.inventory_2)),
      title: Text(item.product, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${item.category} - ${item.pawnAmountSource}\nAge ${item.age ?? 'unknown'} days - pawned ${moneyFormat.format(item.pawnAmount)}'),
      isThreeLine: true,
      trailing: Text(sold ? moneyFormat.format(item.profit) : moneyFormat.format(item.value), style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)));
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
