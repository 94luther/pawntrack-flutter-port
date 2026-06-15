import 'package:flutter/material.dart';

import '../models/pawntrack_models.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({
    super.key,
    required this.title,
    required this.loans,
    required this.selectedLoanId,
    required this.onSelectLoan,
    required this.onSave,
    required this.writeStatus,
  });

  final String title;
  final List<LoanRecord> loans;
  final String? selectedLoanId;
  final ValueChanged<String> onSelectLoan;
  final Future<void> Function(LoanRecord loan, String paymentAmount, String dueDate) onSave;
  final String writeStatus;

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final paymentController = TextEditingController();
  final dueDateController = TextEditingController();

  @override
  void dispose() {
    paymentController.dispose();
    dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLoans = widget.loans.where((loan) => loan.remaining > 0).toList();
    final selected = activeLoans.where((loan) => loan.id == widget.selectedLoanId).firstOrNull ?? activeLoans.firstOrNull;
    if (selected != null && dueDateController.text.isEmpty) {
      dueDateController.text = dateInputValue(selected.dueDate);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final list = _LoanList(loans: activeLoans, selectedLoanId: selected?.id, onSelectLoan: (loan) {
            widget.onSelectLoan(loan.id);
            dueDateController.text = dateInputValue(loan.dueDate);
          });
          final editor = _LoanEditor(
            loan: selected,
            paymentController: paymentController,
            dueDateController: dueDateController,
            writeStatus: widget.writeStatus,
            onSave: () async {
              if (selected == null) return;
              await widget.onSave(selected, paymentController.text, dueDateController.text);
              paymentController.clear();
            },
          );
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: list), const SizedBox(width: 16), SizedBox(width: 360, child: editor)])
              : Column(children: [list, const SizedBox(height: 16), editor]);
        }),
      ],
    );
  }
}

class _LoanList extends StatelessWidget {
  const _LoanList({required this.loans, required this.selectedLoanId, required this.onSelectLoan});

  final List<LoanRecord> loans;
  final String? selectedLoanId;
  final ValueChanged<LoanRecord> onSelectLoan;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: loans.map((loan) {
        final selected = loan.id == selectedLoanId;
        final color = Color(loan.risk.colorHex);
        return Card(
          elevation: selected ? 2 : 0,
          margin: const EdgeInsets.only(bottom: 10),
          color: selected ? color.withValues(alpha: .08) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: selected ? color : const Color(0xffe5e7eb))),
          child: ListTile(
            onTap: () => onSelectLoan(loan),
            title: Text(loan.client, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${loan.type} - ${loan.item}\nDue ${dateInputValue(loan.dueDate).isEmpty ? 'missing' : dateInputValue(loan.dueDate)} - ${loan.risk.label}'),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(moneyFormat.format(loan.remaining), style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('${loan.riskScore}', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LoanEditor extends StatelessWidget {
  const _LoanEditor({
    required this.loan,
    required this.paymentController,
    required this.dueDateController,
    required this.writeStatus,
    required this.onSave,
  });

  final LoanRecord? loan;
  final TextEditingController paymentController;
  final TextEditingController dueDateController;
  final String writeStatus;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xffe5e7eb))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Selected Loan', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (loan != null) Text('${loan!.client}\n${moneyFormat.format(loan!.remaining)} remaining', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextField(controller: paymentController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Repayment amount', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: dueDateController, decoration: const InputDecoration(labelText: 'New due date', hintText: 'YYYY-MM-DD', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: loan == null ? null : onSave, icon: const Icon(Icons.save), label: const Text('Save Loan Update')),
          const SizedBox(height: 10),
          Text(writeStatus),
        ],
      ),
    );
  }
}
