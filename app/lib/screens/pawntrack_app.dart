import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pawntrack_models.dart';
import '../services/pawntrack_api.dart';
import 'analytics_screens.dart';
import 'inventory_screen.dart';
import 'loans_screen.dart';

class PawnTrackApp extends StatefulWidget {
  const PawnTrackApp({super.key});

  @override
  State<PawnTrackApp> createState() => _PawnTrackAppState();
}

class _PawnTrackAppState extends State<PawnTrackApp> {
  final api = PawnTrackApi();
  Timer? timer;
  int selectedIndex = 0;
  String status = 'Loading live Google Sheets';
  String writeStatus = 'Ready';
  PawnTrackModel? model;
  String? selectedLoanId;
  String? selectedInventoryId;

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final source = await api.sheetData();
      setState(() {
        model = PawnTrackModel.fromSource(source);
        status = 'Live Google Sheets connected';
        selectedLoanId ??= model?.loans.where((loan) => loan.remaining > 0).firstOrNull?.id;
        selectedInventoryId ??= model?.availableInventory.firstOrNull?.id;
      });
    } catch (error) {
      setState(() => status = 'Backend not connected yet');
    }
  }

  Future<void> saveLoanUpdate(LoanRecord loan, String paymentAmount, String dueDate) async {
    final amount = parseNumber(paymentAmount);
    final updates = <Map<String, dynamic>>[];
    if (amount > 0) {
      final paidColumn = loan.sheetName == 'OS Debts' ? 'I' : 'J';
      final remainingColumn = loan.sheetName == 'OS Debts' ? 'J' : 'K';
      final newPaid = loan.paid + amount;
      updates.add({'range': "'${loan.sheetName}'!$paidColumn${loan.rowNumber}", 'values': [[newPaid]]});
      updates.add({'range': "'${loan.sheetName}'!$remainingColumn${loan.rowNumber}", 'values': [[(loan.total - newPaid).clamp(0, double.infinity)]]});
    }
    if (dueDate.isNotEmpty) {
      final dueColumn = loan.sheetName == 'OS Debts' ? 'G' : 'H';
      updates.add({'range': "'${loan.sheetName}'!$dueColumn${loan.rowNumber}", 'values': [[dueDate]]});
    }
    if (updates.isEmpty) {
      setState(() => writeStatus = 'Enter repayment, due date, or both.');
      return;
    }
    await api.batchUpdate(updates, metadata: {
      'type': 'loan_update',
      'loan': {
        'sheetName': loan.sheetName,
        'rowNumber': loan.rowNumber,
        'clientName': loan.client,
        'itemPawned': loan.item,
        'paymentAmount': amount,
        'dueDate': dueDate,
      }
    });
    setState(() => writeStatus = 'Updated ${loan.client}.');
    await refresh();
  }

  Future<void> markSold(InventoryRecord item, String sellPrice, String pawnedAmount) async {
    final price = parseNumber(sellPrice);
    final pawned = parseNumber(pawnedAmount);
    if (price <= 0 || pawned <= 0) {
      setState(() => writeStatus = 'Enter sell price and pawned amount.');
      return;
    }
    final profit = price - pawned;
    final saleDate = dateInputValue(today);
    final dateGiven = dateInputValue(item.dateGiven);
    final daysHeld = item.daysHeld ?? '';
    final updates = [
      {'range': "'${item.sheetName}'!K1:N1", 'values': [['Sale Date', 'Date Given', 'Expected Repayment', 'Days Held']]},
      {'range': "'${item.sheetName}'!D${item.rowNumber}", 'values': [['Sold']]},
      {'range': "'${item.sheetName}'!G${item.rowNumber}", 'values': [[pawned]]},
      {'range': "'${item.sheetName}'!H${item.rowNumber}", 'values': [[price]]},
      {'range': "'${item.sheetName}'!I${item.rowNumber}", 'values': [[profit]]},
      {'range': "'${item.sheetName}'!K${item.rowNumber}:N${item.rowNumber}", 'values': [[saleDate, dateGiven, item.expectedRepayment == 0 ? '' : item.expectedRepayment, daysHeld]]},
    ];
    await api.inventorySale({
      'id': item.id,
      'product': item.product,
      'category': item.category,
      'listedAmount': item.value,
      'pawnedAmount': pawned,
      'expectedRepayment': item.expectedRepayment,
      'dateGiven': dateGiven,
      'daysHeld': daysHeld,
      'saleDate': saleDate,
      'sellAmount': price,
      'profit': profit,
      'sheetName': item.sheetName,
      'rowNumber': item.rowNumber,
      'pawnAmountSource': item.pawnAmountSource,
    }, updates);
    setState(() => writeStatus = 'Sold ${item.product} for ${moneyFormat.format(price)}.');
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawnTrack Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xff2563eb),
        scaffoldBackgroundColor: const Color(0xfff7f9fc),
      ),
      home: LayoutBuilder(
        builder: (context, constraints) {
          final loaded = model;
          final pages = loaded == null
              ? List<Widget>.filled(9, const Center(child: CircularProgressIndicator()))
              : [
                  GrowthScreen(model: loaded),
                  CollectionsScreen(model: loaded),
                  CashScreen(model: loaded),
                  ProfitScreen(model: loaded),
                  InventoryScreen(model: loaded, selectedInventoryId: selectedInventoryId, onSelectInventory: (id) => setState(() => selectedInventoryId = id), onMarkSold: markSold, writeStatus: writeStatus),
                  LoansScreen(title: 'Active Pawns', loans: loaded.active, selectedLoanId: selectedLoanId, onSelectLoan: (id) => setState(() => selectedLoanId = id), onSave: saveLoanUpdate, writeStatus: writeStatus),
                  LoansScreen(title: 'Loans', loans: loaded.loans, selectedLoanId: selectedLoanId, onSelectLoan: (id) => setState(() => selectedLoanId = id), onSave: saveLoanUpdate, writeStatus: writeStatus),
                  LiveScreen(model: loaded, status: status, writeStatus: writeStatus, onRefresh: refresh),
                  AiScreen(model: loaded),
                ];
          const destinations = [
            NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: 'Growth'),
            NavigationDestination(icon: Icon(Icons.assignment_returned_outlined), selectedIcon: Icon(Icons.assignment_returned), label: 'Collections'),
            NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'Cash'),
            NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Profit'),
            NavigationDestination(icon: Icon(Icons.sell_outlined), selectedIcon: Icon(Icons.sell), label: 'Inventory'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Active Pawns'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Loans'),
            NavigationDestination(icon: Icon(Icons.sync_outlined), selectedIcon: Icon(Icons.sync), label: 'Live'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI'),
          ];
          final content = Column(
            children: [
              _Header(status: status, onRefresh: refresh),
              if (constraints.maxWidth < 860) _MobileTabs(selectedIndex: selectedIndex, onSelected: (index) => setState(() => selectedIndex = index)),
              Expanded(child: pages[selectedIndex]),
            ],
          );
          if (constraints.maxWidth >= 860) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) => setState(() => selectedIndex = index),
                    labelType: NavigationRailLabelType.all,
                    destinations: destinations.map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label))).toList(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              ),
            );
          }
          return Scaffold(
            body: content,
          );
        },
      ),
    );
  }
}

class _MobileTabs extends StatelessWidget {
  const _MobileTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const labels = ['Growth', 'Collections', 'Cash', 'Profit', 'Inventory', 'Active Pawns', 'Loans', 'Live', 'AI'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(labels[index]),
            selected: selected,
            onSelected: (_) => onSelected(index),
            showCheckmark: false,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, color: selected ? Theme.of(context).colorScheme.onPrimary : null),
            selectedColor: Theme.of(context).colorScheme.primary,
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status, required this.onRefresh});

  final String status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PawnTrack', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  Text(status, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton.filledTonal(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          ],
        ),
      ),
    );
  }
}
