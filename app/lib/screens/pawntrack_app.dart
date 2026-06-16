import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/pawntrack_models.dart';
import '../services/pawntrack_api.dart';
import 'operating_screens.dart';

const activePawnHeaders = [
  'Client Name',
  'Client Number',
  'Item Pawned',
  'Loan Amount',
  'Interest Amount',
  'Total Payback',
  'Date Given',
  'Due Date',
  'Days Overdue',
  'Amount Paid',
  'Remaining Balance',
  'Location',
  'Customer ID Number / Omang',
  'Customer Photo',
  'ID Photo',
  'Phone Number',
  'Emergency Contact',
  'Address / Area',
  'Item Serial / IMEI',
  'Proof Of Ownership',
  'Item Photos',
  'Testing Checklist',
  'Storage Location',
  'Staff Member',
  'Extension Count',
  'Days Overdue Calculated',
  'Forfeiture Date',
  'Sale Date',
  'Actual Profit',
  'Borrower Risk Score',
  'Correction Reason',
  'Voice Command',
  'Audit Status',
];

class PawnTrackApp extends StatefulWidget {
  const PawnTrackApp(
      {super.key, required this.currentUser, required this.onLogout});

  final User currentUser;
  final Future<void> Function() onLogout;

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

  Map<String, dynamic> get actorInfo => {
        'uid': widget.currentUser.uid,
        'email': widget.currentUser.email,
        'displayName': widget.currentUser.displayName,
        'emailVerified': widget.currentUser.emailVerified,
      };

  Map<String, dynamic> withActor(Map<String, dynamic> metadata) => {
        ...metadata,
        'actor': actorInfo,
      };

  static const navLabels = [
    'Home',
    'New Pawn',
    'New Loan',
    'Active Pawns',
    'Repayments',
    'Overdue',
    'Customers / Risk',
    'Inventory',
    'Sales',
    'Reports',
    'Settings',
  ];

  static const navIcons = [
    Icons.home_outlined,
    Icons.add_business_outlined,
    Icons.add_card_outlined,
    Icons.inventory_2_outlined,
    Icons.payments_outlined,
    Icons.warning_amber_outlined,
    Icons.badge_outlined,
    Icons.storefront_outlined,
    Icons.sell_outlined,
    Icons.summarize_outlined,
    Icons.settings_outlined,
  ];

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
        selectedLoanId ??=
            model?.loans.where((loan) => loan.remaining > 0).firstOrNull?.id;
        selectedInventoryId ??= model?.availableInventory.firstOrNull?.id;
      });
    } catch (error) {
      setState(() => status = 'Backend not connected yet');
    }
  }

  Future<void> saveLoanUpdate(
      LoanRecord loan, String paymentAmount, String dueDate) async {
    final amount = parseNumber(paymentAmount);
    final updates = <Map<String, dynamic>>[];
    if (amount > 0) {
      final paidColumn = loan.sheetName == 'OS Debts' ? 'I' : 'J';
      final remainingColumn = loan.sheetName == 'OS Debts' ? 'J' : 'K';
      final newPaid = loan.paid + amount;
      updates.add({
        'range': "'${loan.sheetName}'!$paidColumn${loan.rowNumber}",
        'values': [
          [newPaid]
        ]
      });
      updates.add({
        'range': "'${loan.sheetName}'!$remainingColumn${loan.rowNumber}",
        'values': [
          [(loan.total - newPaid).clamp(0, double.infinity)]
        ]
      });
    }
    if (dueDate.isNotEmpty) {
      final dueColumn = loan.sheetName == 'OS Debts' ? 'G' : 'H';
      updates.add({
        'range': "'${loan.sheetName}'!$dueColumn${loan.rowNumber}",
        'values': [
          [dueDate]
        ]
      });
      if (loan.sheetName == 'Active Pawns') {
        updates.add({
          'range': "'${loan.sheetName}'!Y${loan.rowNumber}",
          'values': [
            [loan.extensionCount + 1]
          ]
        });
      }
    }
    if (updates.isEmpty) {
      setState(() => writeStatus = 'Enter repayment, due date, or both.');
      return;
    }
    await api.batchUpdate(updates,
        metadata: withActor({
          'type': 'loan_update',
          'loan': {
            'sheetName': loan.sheetName,
            'rowNumber': loan.rowNumber,
            'clientName': loan.client,
            'itemPawned': loan.item,
            'paymentAmount': amount,
            'dueDate': dueDate,
          }
        }));
    setState(() => writeStatus = 'Updated ${loan.client}.');
    await refresh();
  }

  Future<void> createNewPawn(NewPawnDraft draft) async {
    if (model == null) return;
    if (draft.customerName.isEmpty ||
        draft.item.isEmpty ||
        draft.loanAmount <= 0 ||
        draft.dueDate.isEmpty) {
      setState(() =>
          writeStatus = 'Enter customer, item, loan amount, and due date.');
      return;
    }
    final rowNumber = model!.source.activePawns.length + 1;
    final row = [
      draft.customerName,
      draft.phone,
      draft.item,
      draft.loanAmount,
      draft.interestAmount,
      draft.totalPayback,
      draft.dateGiven,
      draft.dueDate,
      0,
      0,
      draft.totalPayback,
      draft.storageLocation,
      draft.customerIdNumber,
      '',
      '',
      draft.phone,
      draft.emergencyContact,
      draft.addressArea,
      draft.itemSerial,
      draft.proofOfOwnership,
      '',
      draft.testingChecklist,
      draft.storageLocation,
      draft.staffMember,
      0,
      0,
      '',
      '',
      '',
      draft.riskScore,
      '',
      'Create a new pawn for ${draft.customerName}',
      'created_in_flutter',
    ];
    await api.batchUpdate([
      {
        'range': "'Active Pawns'!A1:AG1",
        'values': [activePawnHeaders]
      },
      {
        'range': "'Active Pawns'!A$rowNumber:AG$rowNumber",
        'values': [row]
      },
    ],
        metadata: withActor({
          'type': 'new_pawn',
          'customerName': draft.customerName,
          'itemPawned': draft.item,
          'loanAmount': draft.loanAmount,
          'riskScore': draft.riskScore,
        }));
    setState(() => writeStatus = 'Created pawn for ${draft.customerName}.');
    await refresh();
  }

  Future<void> createNewLoan(NewLoanDraft draft) async {
    if (model == null) return;
    if (draft.loanAmount <= 0 || draft.dueDate.isEmpty) {
      setState(() => writeStatus = 'Enter loan amount and due date.');
      return;
    }
    final pawn = draft.existingPawn;
    final rowNumber = model!.source.activePawns.length + 1;
    final storageLocation =
        draft.storageLocation.isEmpty ? pawn.location : draft.storageLocation;
    final row = [
      pawn.client,
      pawn.phone,
      pawn.item,
      draft.loanAmount,
      draft.interestAmount,
      draft.totalPayback,
      draft.dateGiven,
      draft.dueDate,
      0,
      0,
      draft.totalPayback,
      storageLocation,
      pawn.customerIdNumber,
      '',
      '',
      pawn.phone,
      pawn.emergencyContact,
      pawn.addressArea,
      pawn.itemSerial,
      pawn.proofOfOwnership,
      '',
      pawn.testingChecklist,
      storageLocation,
      draft.staffMember,
      0,
      0,
      '',
      '',
      '',
      draft.riskScore,
      '',
      'Create a new loan for ${pawn.client}',
      'new_loan_in_flutter',
    ];
    await api.batchUpdate([
      {
        'range': "'Active Pawns'!A1:AG1",
        'values': [activePawnHeaders]
      },
      {
        'range': "'Active Pawns'!A$rowNumber:AG$rowNumber",
        'values': [row]
      },
    ],
        metadata: withActor({
          'type': 'new_loan',
          'sourceLoan': {
            'sheetName': pawn.sheetName,
            'rowNumber': pawn.rowNumber,
            'clientName': pawn.client,
            'itemPawned': pawn.item,
          },
          'customerName': pawn.client,
          'itemPawned': pawn.item,
          'loanAmount': draft.loanAmount,
          'riskScore': draft.riskScore,
        }));
    setState(() => writeStatus = 'Added new loan for ${pawn.client}.');
    await refresh();
  }

  Future<void> savePawnPersonalDetails(
      LoanRecord loan, PawnPersonalDetailsDraft draft) async {
    final sheet = loan.sheetName;
    final row = loan.rowNumber;
    await api.batchUpdate([
      {
        'range': "'$sheet'!A$row:C$row",
        'values': [
          [draft.customerName, draft.phone, draft.item]
        ]
      },
      {
        'range': "'$sheet'!L$row:M$row",
        'values': [
          [draft.storageLocation, draft.customerIdNumber]
        ]
      },
      {
        'range': "'$sheet'!P$row:T$row",
        'values': [
          [
            draft.phone,
            draft.emergencyContact,
            draft.addressArea,
            draft.itemSerial,
            draft.proofOfOwnership
          ]
        ]
      },
      {
        'range': "'$sheet'!V$row:X$row",
        'values': [
          [draft.testingChecklist, draft.storageLocation, draft.staffMember]
        ]
      },
      {
        'range': "'$sheet'!AE$row",
        'values': [
          [draft.correctionReason]
        ]
      },
    ],
        metadata: withActor({
          'type': 'pawn_personal_update',
          'loan': {
            'sheetName': loan.sheetName,
            'rowNumber': loan.rowNumber,
            'clientName': loan.client,
            'itemPawned': loan.item,
          },
          'correctionReason': draft.correctionReason,
        }));
    setState(() => writeStatus = 'Updated details for ${draft.customerName}.');
    await refresh();
  }

  Future<void> saveCurrentLoanDetails(
      LoanRecord loan, LoanDetailsDraft draft) async {
    final sheet = loan.sheetName;
    final row = loan.rowNumber;
    await api.batchUpdate([
      {
        'range': "'$sheet'!D$row:K$row",
        'values': [
          [
            draft.loanAmount,
            draft.interestAmount,
            draft.totalPayback,
            draft.dateGiven,
            draft.dueDate,
            draft.daysOverdue,
            draft.amountPaid,
            draft.remainingBalance,
          ]
        ]
      },
      {
        'range': "'$sheet'!L$row",
        'values': [
          [draft.location]
        ]
      },
      {
        'range': "'$sheet'!Y$row:AE$row",
        'values': [
          [
            draft.extensionCount,
            draft.daysOverdue,
            draft.forfeitureDate,
            draft.saleDate,
            draft.actualProfit,
            draft.riskScore,
            draft.correctionReason,
          ]
        ]
      },
    ],
        metadata: withActor({
          'type': 'loan_detail_update',
          'loan': {
            'sheetName': loan.sheetName,
            'rowNumber': loan.rowNumber,
            'clientName': loan.client,
            'itemPawned': loan.item,
          },
          'correctionReason': draft.correctionReason,
        }));
    setState(() => writeStatus = 'Updated loan details for ${loan.client}.');
    await refresh();
  }

  Future<void> forfeitLoanToInventory(LoanRecord loan) async {
    if (model == null) return;
    final inventoryRow = model!.source.companyOwnedItems.length + 1;
    final todayValue = dateInputValue(today);
    final listAmount = loan.remaining > 0 ? loan.remaining : loan.total;
    await api.batchUpdate([
      {
        'range': "'Company Owned Items'!A1:N1",
        'values': [
          [
            'Category',
            'Product',
            'Damages',
            'Listed on Market place',
            'List Date',
            'List amount',
            'Amount paid',
            'Sell amount',
            'Profit/loss',
            'Location',
            'Sale Date',
            'Date Given',
            'Expected Repayment',
            'Days Held'
          ]
        ]
      },
      {
        'range': "'Company Owned Items'!A$inventoryRow:N$inventoryRow",
        'values': [
          [
            'FORFEITED',
            loan.item,
            '',
            'Listed',
            todayValue,
            listAmount,
            loan.loan,
            '',
            '',
            loan.location,
            '',
            dateInputValue(loan.dateGiven),
            loan.total,
            loan.dateGiven == null ? '' : daysBetween(today, loan.dateGiven!)
          ]
        ]
      },
      if (loan.sheetName == 'Active Pawns')
        {
          'range': "'Active Pawns'!AA${loan.rowNumber}",
          'values': [
            [todayValue]
          ]
        },
    ],
        metadata: withActor({
          'type': 'forfeiture',
          'loan': {
            'sheetName': loan.sheetName,
            'rowNumber': loan.rowNumber,
            'clientName': loan.client,
            'itemPawned': loan.item
          }
        }));
    setState(() => writeStatus = 'Moved ${loan.item} into inventory.');
    await refresh();
  }

  Future<void> markSold(
      InventoryRecord item, String sellPrice, String pawnedAmount) async {
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
      {
        'range': "'${item.sheetName}'!K1:N1",
        'values': [
          ['Sale Date', 'Date Given', 'Expected Repayment', 'Days Held']
        ]
      },
      {
        'range': "'${item.sheetName}'!D${item.rowNumber}",
        'values': [
          ['Sold']
        ]
      },
      {
        'range': "'${item.sheetName}'!G${item.rowNumber}",
        'values': [
          [pawned]
        ]
      },
      {
        'range': "'${item.sheetName}'!H${item.rowNumber}",
        'values': [
          [price]
        ]
      },
      {
        'range': "'${item.sheetName}'!I${item.rowNumber}",
        'values': [
          [profit]
        ]
      },
      {
        'range': "'${item.sheetName}'!K${item.rowNumber}:N${item.rowNumber}",
        'values': [
          [
            saleDate,
            dateGiven,
            item.expectedRepayment == 0 ? '' : item.expectedRepayment,
            daysHeld
          ]
        ]
      },
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
    }, updates, metadata: withActor({'actorAction': 'inventory_sale'}));
    setState(() =>
        writeStatus = 'Sold ${item.product} for ${moneyFormat.format(price)}.');
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final loaded = model;
        final pages = loaded == null
            ? List<Widget>.filled(navLabels.length,
                const Center(child: CircularProgressIndicator()))
            : [
                HomeCommandCentreScreen(
                    model: loaded,
                    onOpen: (index) => setState(() => selectedIndex = index),
                    onRunCommand: (_) {}),
                NewPawnScreen(
                    model: loaded,
                    onCreate: createNewPawn,
                    writeStatus: writeStatus),
                NewLoanScreen(
                    model: loaded,
                    onCreate: createNewLoan,
                    writeStatus: writeStatus),
                ActivePawnsOpsScreen(
                    model: loaded,
                    onForfeit: forfeitLoanToInventory,
                    onOpenRepayments: (loan) => setState(() {
                          selectedLoanId = loan.id;
                          selectedIndex = 4;
                        }),
                    onSavePersonalDetails: savePawnPersonalDetails,
                    onSaveLoanDetails: saveCurrentLoanDetails),
                RepaymentsScreen(
                    model: loaded,
                    selectedLoanId: selectedLoanId,
                    onSelectLoan: (id) => setState(() => selectedLoanId = id),
                    onSave: saveLoanUpdate,
                    writeStatus: writeStatus),
                OverdueCollectionsScreen(
                    model: loaded,
                    onOpenRepayments: (loan) => setState(() {
                          selectedLoanId = loan.id;
                          selectedIndex = 4;
                        }),
                    onForfeit: forfeitLoanToInventory),
                BorrowerRiskScreen(model: loaded),
                InventoryOpsScreen(model: loaded),
                SalesScreen(
                    model: loaded,
                    selectedInventoryId: selectedInventoryId,
                    onSelectInventory: (id) =>
                        setState(() => selectedInventoryId = id),
                    onMarkSold: markSold,
                    writeStatus: writeStatus),
                ReportsScreen(model: loaded),
                SyncSettingsScreen(
                    model: loaded,
                    status: status,
                    writeStatus: writeStatus,
                    currentUser: widget.currentUser,
                    onRefresh: refresh,
                    onLogout: widget.onLogout),
              ];
        final content = Column(
          children: [
            _Header(status: status, onRefresh: refresh),
            if (constraints.maxWidth < 860)
              _MobileTabs(
                  selectedIndex: selectedIndex,
                  onSelected: (index) => setState(() => selectedIndex = index)),
            Expanded(child: pages[selectedIndex]),
          ],
        );
        if (constraints.maxWidth >= 860) {
          return Scaffold(
            body: Row(
              children: [
                _SideNav(
                    selectedIndex: selectedIndex,
                    onSelected: (index) =>
                        setState(() => selectedIndex = index)),
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
    );
  }
}

class _MobileTabs extends StatelessWidget {
  const _MobileTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _PawnTrackAppState.navLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            avatar: Icon(_PawnTrackAppState.navIcons[index],
                size: 18,
                color:
                    selected ? Theme.of(context).colorScheme.onPrimary : null),
            label: Text(_PawnTrackAppState.navLabels[index]),
            selected: selected,
            onSelected: (_) => onSelected(index),
            showCheckmark: false,
            labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color:
                    selected ? Theme.of(context).colorScheme.onPrimary : null),
            selectedColor: Theme.of(context).colorScheme.primary,
          );
        },
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      color: Colors.white,
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _PawnTrackAppState.navLabels.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final selected = index == selectedIndex;
            return ListTile(
              selected: selected,
              selectedTileColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: .1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              leading: Icon(_PawnTrackAppState.navIcons[index],
                  color:
                      selected ? Theme.of(context).colorScheme.primary : null),
              title: Text(_PawnTrackAppState.navLabels[index],
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => onSelected(index),
            );
          },
        ),
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
                  Text('Last Resort Pawnshop',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  Text(status, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton.filledTonal(
                onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          ],
        ),
      ),
    );
  }
}
