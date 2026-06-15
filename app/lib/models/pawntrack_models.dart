import 'package:intl/intl.dart';

final today = DateTime.now();
final moneyFormat = NumberFormat.currency(locale: 'en_BW', symbol: 'BWP ', decimalDigits: 0);

double parseNumber(dynamic value) {
  final match = RegExp(r'-?\d+(\.\d+)?').firstMatch('${value ?? ''}'.replaceAll(',', ''));
  return match == null ? 0 : double.tryParse(match.group(0) ?? '') ?? 0;
}

DateTime? parseDate(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) return null;
  final formats = ['d-MMMM-y', 'd-MMM-y', 'd/M/y', 'd-M-y', 'y-M-d', 'M/d/y'];
  for (final format in formats) {
    try {
      return DateFormat(format, 'en_US').parseStrict(raw);
    } catch (_) {}
  }
  return DateTime.tryParse(raw);
}

String dateInputValue(DateTime? date) {
  if (date == null) return '';
  return DateFormat('yyyy-MM-dd').format(date);
}

int daysBetween(DateTime a, DateTime b) {
  final left = DateTime(a.year, a.month, a.day);
  final right = DateTime(b.year, b.month, b.day);
  return left.difference(right).inDays.round();
}

List<Map<String, dynamic>> toObjects(List<dynamic>? rows) {
  if (rows == null || rows.isEmpty) return [];
  final headers = (rows.first as List).map((cell) => '${cell ?? ''}'.trim()).toList();
  final body = rows.skip(1).toList();
  final result = <Map<String, dynamic>>[];
  for (var i = 0; i < body.length; i++) {
    final row = body[i] as List;
    if (!row.any((cell) => '${cell ?? ''}'.trim().isNotEmpty)) continue;
    if ('${row.isEmpty ? '' : row.first}'.trim().toLowerCase() == 'totals') continue;
    final object = <String, dynamic>{'__rowNumber': i + 2, '__row': row};
    for (var j = 0; j < headers.length; j++) {
      object[headers[j].isEmpty ? 'Column ${j + 1}' : headers[j]] = j < row.length ? row[j] : null;
    }
    result.add(object);
  }
  return result;
}

class SheetSource {
  SheetSource({
    required this.source,
    required this.companyOwnedItems,
    required this.osDebts,
    required this.activePawns,
    required this.damagedGoods,
    this.syncedAt,
  });

  final String source;
  final DateTime? syncedAt;
  final List<dynamic> companyOwnedItems;
  final List<dynamic> osDebts;
  final List<dynamic> activePawns;
  final List<dynamic> damagedGoods;

  factory SheetSource.fromJson(Map<String, dynamic> json) {
    return SheetSource(
      source: '${json['source'] ?? 'Local snapshot'}',
      syncedAt: DateTime.tryParse('${json['syncedAt'] ?? ''}'),
      companyOwnedItems: json['companyOwnedItems'] as List<dynamic>? ?? [],
      osDebts: json['osDebts'] as List<dynamic>? ?? [],
      activePawns: json['activePawns'] as List<dynamic>? ?? [],
      damagedGoods: json['damagedGoods'] as List<dynamic>? ?? [],
    );
  }
}

class RiskBand {
  RiskBand(this.label, this.colorHex);
  final String label;
  final int colorHex;
}

RiskBand riskBand(double score) {
  if (score >= 70) return RiskBand('High risk', 0xffdc2626);
  if (score >= 40) return RiskBand('Medium risk', 0xfff59e0b);
  return RiskBand('Low risk', 0xff059669);
}

class LoanRecord {
  LoanRecord({
    required this.id,
    required this.sheetName,
    required this.rowNumber,
    required this.type,
    required this.client,
    required this.item,
    required this.loan,
    required this.interest,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.overdueDays,
    required this.riskScore,
    required this.risk,
    this.dueDate,
    this.dateGiven,
    this.location = '',
    this.phone = '',
    this.customerIdNumber = '',
    this.emergencyContact = '',
    this.addressArea = '',
    this.itemSerial = '',
    this.proofOfOwnership = '',
    this.testingChecklist = '',
    this.staffMember = '',
    this.extensionCount = 0,
    this.forfeitureDate,
    this.correctionReason = '',
  });

  final String id;
  final String sheetName;
  final int rowNumber;
  final String type;
  final String client;
  final String item;
  final String location;
  final String phone;
  final String customerIdNumber;
  final String emergencyContact;
  final String addressArea;
  final String itemSerial;
  final String proofOfOwnership;
  final String testingChecklist;
  final String staffMember;
  final int extensionCount;
  final DateTime? forfeitureDate;
  final String correctionReason;
  final double loan;
  final double interest;
  final double total;
  final double paid;
  final double remaining;
  final int overdueDays;
  final int riskScore;
  final RiskBand risk;
  final DateTime? dueDate;
  final DateTime? dateGiven;
}

class InventoryRecord {
  InventoryRecord({
    required this.id,
    required this.sheetName,
    required this.rowNumber,
    required this.product,
    required this.category,
    required this.value,
    required this.pawnAmount,
    required this.pawnAmountSource,
    required this.expectedRepayment,
    required this.sold,
    required this.profit,
    required this.isSold,
    this.dateGiven,
    this.listDate,
  });

  final String id;
  final String sheetName;
  final int rowNumber;
  final String product;
  final String category;
  final double value;
  final double pawnAmount;
  final String pawnAmountSource;
  final double expectedRepayment;
  final double sold;
  final num profit;
  final bool isSold;
  final DateTime? dateGiven;
  final DateTime? listDate;
  int? get daysHeld => dateGiven == null ? null : daysBetween(today, dateGiven!);
  int? get age => listDate == null ? null : daysBetween(today, listDate!);
}

class MonthlyMetric {
  MonthlyMetric({
    required this.month,
    this.loans = 0,
    this.repayment = 0,
    this.interest = 0,
    this.inventory = 0,
    this.recovered = 0,
    this.profit = 0,
    this.growthPct = 0,
  });

  final String month;
  double loans;
  double repayment;
  double interest;
  double inventory;
  double recovered;
  double profit;
  double growthPct;
}

class WeeklyMetric {
  WeeklyMetric({required this.week, this.loans = 0, this.repayment = 0});

  final String week;
  double loans;
  double repayment;
}

class CategoryMetric {
  CategoryMetric({required this.name, this.value = 0, this.count = 0});

  final String name;
  double value;
  int count;
}

class AgingMetric {
  const AgingMetric({required this.bucket, required this.count, required this.value});

  final String bucket;
  final int count;
  final double value;
}

class PawnTrackModel {
  PawnTrackModel({
    required this.source,
    required this.loans,
    required this.inventory,
  });

  final SheetSource source;
  final List<LoanRecord> loans;
  final List<InventoryRecord> inventory;

  List<LoanRecord> get active => loans.where((loan) => loan.sheetName == 'Active Pawns').toList();
  List<LoanRecord> get os => loans.where((loan) => loan.sheetName == 'OS Debts').toList();
  List<LoanRecord> get overdue => loans.where((loan) => loan.overdueDays > 0 && loan.remaining > 0).toList();
  List<LoanRecord> get dueTodayLoans => loans.where((loan) => loan.dueDate != null && daysBetween(loan.dueDate!, today) == 0 && loan.remaining > 0).toList();
  List<LoanRecord> get highRiskBorrowers => loans.where((loan) => loan.remaining > 0 && loan.riskScore >= 70).toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
  List<InventoryRecord> get availableInventory => inventory.where((item) => !item.isSold).toList();
  List<InventoryRecord> get soldInventory => inventory.where((item) => item.isSold).toList();

  double get principalOutstanding => loans.fold(0.0, (sum, loan) => sum + loan.loan);
  double get expectedRepayment => loans.fold(0.0, (sum, loan) => sum + loan.total);
  double get expectedInterest => loans.fold(0.0, (sum, loan) => sum + loan.interest);
  double get remaining => loans.fold(0.0, (sum, loan) => sum + loan.remaining);
  double get collected => loans.fold(0.0, (sum, loan) => sum + loan.paid);
  double get inventoryValue => availableInventory.fold(0.0, (sum, item) => sum + item.value);
  double get salesEarned => soldInventory.fold(0.0, (sum, item) => sum + item.sold);
  double get salesProfit => soldInventory.fold(0.0, (sum, item) => sum + item.profit.toDouble());
  double get lossValue => 0.0;
  double get expectedNetProfit => expectedInterest + salesEarned + inventoryValue - lossValue;
  double get overdueAmount => overdue.fold(0.0, (sum, loan) => sum + loan.remaining);
  double get collectionRate => expectedRepayment == 0 ? 0 : collected / expectedRepayment;
  double get dueToday => _dueBetween(0, 0);
  double get due7 => _dueBetween(0, 7);
  double get dueNextWeek => _dueBetween(8, 14);
  double get due30 => _dueBetween(0, 30);
  double get due90 => _dueBetween(0, 90);
  List<InventoryRecord> get slowMoving => [...availableInventory]
    ..sort((a, b) => (b.age ?? 999).compareTo(a.age ?? 999));
  List<InventoryRecord> get highValueItems => ([...availableInventory]..sort((a, b) => b.value.compareTo(a.value))).take(8).toList();
  List<InventoryRecord> get discountItems => availableInventory.where((item) => item.age == null || item.age! >= 21).toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  double _dueBetween(int startDays, int endDays) {
    return loans.where((loan) {
      if (loan.dueDate == null || loan.remaining <= 0) return false;
      final days = daysBetween(loan.dueDate!, today);
      return days >= startDays && days <= endDays;
    }).fold(0.0, (sum, loan) => sum + loan.remaining);
  }

  List<MonthlyMetric> get monthlyGrowth {
    final monthly = <String, MonthlyMetric>{};
    MonthlyMetric bucket(String key) => monthly.putIfAbsent(key, () => MonthlyMetric(month: key));

    for (final loan in loans) {
      final key = monthKey(loan.dateGiven ?? loan.dueDate);
      if (key == null) continue;
      final row = bucket(key);
      row.loans += loan.loan;
      row.repayment += loan.total;
      row.interest += loan.interest;
      row.recovered += loan.paid;
    }
    for (final item in availableInventory) {
      final key = monthKey(item.listDate ?? item.dateGiven);
      if (key == null) continue;
      final row = bucket(key);
      row.inventory += item.value;
      row.profit += item.value * .18;
    }
    for (final item in soldInventory) {
      final key = monthKey(item.listDate ?? item.dateGiven);
      if (key == null) continue;
      final row = bucket(key);
      row.recovered += item.sold;
      row.profit += item.profit.toDouble();
    }

    final rows = monthly.values.toList()..sort((a, b) => a.month.compareTo(b.month));
    for (var i = 0; i < rows.length; i++) {
      final previous = i == 0 ? null : rows[i - 1];
      rows[i].growthPct = previous != null && previous.loans > 0 ? ((rows[i].loans - previous.loans) / previous.loans) * 100 : 0;
    }
    return rows;
  }

  List<WeeklyMetric> get weekly {
    final weekly = <String, WeeklyMetric>{};
    for (final loan in loans) {
      final key = weekKey(loan.dateGiven ?? loan.dueDate);
      if (key == null) continue;
      final row = weekly.putIfAbsent(key, () => WeeklyMetric(week: key));
      row.loans += loan.loan;
      row.repayment += loan.total;
    }
    return weekly.values.toList()..sort((a, b) => a.week.compareTo(b.week));
  }

  List<CategoryMetric> get byCategory {
    final categories = <String, CategoryMetric>{};
    for (final item in availableInventory) {
      final row = categories.putIfAbsent(item.category, () => CategoryMetric(name: item.category));
      row.value += item.value;
      row.count += 1;
    }
    return categories.values.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  List<AgingMetric> get inventoryAging {
    double valueWhere(bool Function(InventoryRecord item) test) => availableInventory.where(test).fold(0.0, (sum, item) => sum + item.value);
    int countWhere(bool Function(InventoryRecord item) test) => availableInventory.where(test).length;
    return [
      AgingMetric(bucket: '0-14 days', count: countWhere((item) => item.age != null && item.age! <= 14), value: valueWhere((item) => item.age != null && item.age! <= 14)),
      AgingMetric(bucket: '15-30 days', count: countWhere((item) => item.age != null && item.age! > 14 && item.age! <= 30), value: valueWhere((item) => item.age != null && item.age! > 14 && item.age! <= 30)),
      AgingMetric(bucket: '31+ days', count: countWhere((item) => item.age == null || item.age! > 30), value: valueWhere((item) => item.age == null || item.age! > 30)),
    ];
  }

  factory PawnTrackModel.fromSource(SheetSource source) {
    final activeRows = toObjects(source.activePawns);
    final pawnCandidates = activeRows.map((row) {
      final item = '${row['Item Pawned'] ?? ''}'.trim();
      final parts = item.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
      final loan = parseNumber(row['Loan Amount']);
      final expected = parseNumber(row['Total Payback']) != 0 ? parseNumber(row['Total Payback']) : loan + parseNumber(row['Interest Amount']);
      return {
        'item': item,
        'amountPerItem': parts.isEmpty ? loan : loan / parts.length,
        'expectedPerItem': parts.isEmpty ? expected : expected / parts.length,
        'dateGiven': parseDate(row['Date Given']),
      };
    }).where((row) => '${row['item']}'.isNotEmpty).toList();

    final inventoryRows = toObjects(source.companyOwnedItems);
    final inventory = <InventoryRecord>[];
    for (var i = 0; i < inventoryRows.length; i++) {
      final row = inventoryRows[i];
      final product = '${row['Product'] ?? 'Unknown item'}'.trim();
      final category = '${row['Category'] ?? 'Uncategorized'}'.trim().toUpperCase();
      final value = parseNumber(row['List amount']);
      final paid = parseNumber(row['Amount paid']);
      final sold = parseNumber(row['Sell amount']);
      final match = paid > 0 ? null : _findPawnAmountMatch(product, category, pawnCandidates);
      final pawnAmount = paid > 0 ? paid : parseNumber(match?['amountPerItem']);
      final profit = parseNumber(row['Profit/loss']) != 0 ? parseNumber(row['Profit/loss']) : (sold > 0 && pawnAmount > 0 ? sold - pawnAmount : 0);
      inventory.add(InventoryRecord(
        id: 'I-${i + 1}',
        sheetName: 'Company Owned Items',
        rowNumber: row['__rowNumber'] as int,
        product: product,
        category: category,
        value: value,
        pawnAmount: pawnAmount,
        pawnAmountSource: paid > 0 ? 'Amount paid column' : match == null ? 'Missing' : 'Active Pawns: ${match['item']}',
        expectedRepayment: parseNumber(match?['expectedPerItem']),
        dateGiven: match?['dateGiven'] as DateTime?,
        listDate: parseDate(row['List Date']),
        sold: sold,
        profit: profit,
        isSold: sold > 0 || '${row['Listed on Market place'] ?? ''}'.toLowerCase().contains('sold'),
      ));
    }

    final loans = <LoanRecord>[];
    for (var i = 0; i < activeRows.length; i++) {
      loans.add(_mapLoan(activeRows[i], i, 'Active pawn', 'Active Pawns'));
    }
    final osRows = toObjects(source.osDebts);
    for (var i = 0; i < osRows.length; i++) {
      loans.add(_mapLoan(osRows[i], i, 'Outstanding debt', 'OS Debts'));
    }
    loans.removeWhere((loan) => loan.loan == 0 && loan.total == 0 && loan.remaining == 0);
    return PawnTrackModel(source: source, loans: loans, inventory: inventory);
  }
}

String? monthKey(DateTime? date) {
  if (date == null) return null;
  return DateFormat('yyyy-MM').format(date);
}

String? weekKey(DateTime? date) {
  if (date == null) return null;
  final firstDay = DateTime(date.year, 1, 1);
  final week = (date.difference(firstDay).inDays / 7).floor() + 1;
  return '${date.year}-W${week.toString().padLeft(2, '0')}';
}

Map<String, dynamic>? _findPawnAmountMatch(String product, String category, List<Map<String, dynamic>> candidates) {
  final productTokens = _tokensFor('$product $category');
  Map<String, dynamic>? best;
  double bestScore = 0;
  for (final candidate in candidates) {
    final candidateTokens = _tokensFor(candidate['item']);
    final shared = productTokens.where(candidateTokens.contains).length;
    final score = productTokens.isEmpty ? 0 : shared / productTokens.length;
    if (score > bestScore) {
      bestScore = score.toDouble();
      best = candidate;
    }
  }
  return bestScore >= 0.45 ? best : null;
}

List<String> _tokensFor(dynamic value) {
  return '$value'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').split(RegExp(r'\s+')).where((token) => token.length > 2).toList();
}

LoanRecord _mapLoan(Map<String, dynamic> row, int index, String type, String sheetName) {
  final loan = parseNumber(row['Loan Amount']);
  final interest = parseNumber(row['Interest Amount']);
  final total = parseNumber(row['Total Payback']) != 0 ? parseNumber(row['Total Payback']) : loan + interest;
  final paid = parseNumber(row['Amount Paid']);
  final dueDate = parseDate(row['Due Date']);
  final remaining = parseNumber(row['Remaining Balance']) != 0 ? parseNumber(row['Remaining Balance']) : (total - paid).clamp(0, double.infinity);
  final overdueDays = [
    parseNumber(row['Days Overdue']).round(),
    dueDate == null ? 0 : daysBetween(today, dueDate),
  ].reduce((a, b) => a > b ? a : b);
  final score = ((overdueDays > 0 ? (overdueDays * 1.5).clamp(0, 45) : 0) +
      (paid > 0 && remaining > 0 ? 12 : 0) +
      (overdueDays > 0 && remaining > 0 ? 25 : 0) +
      (loan >= 5000 ? 20 : loan >= 2500 ? 12 : 6));
  return LoanRecord(
    id: '${sheetName == 'Active Pawns' ? 'P' : 'O'}-${index + 1}',
    sheetName: sheetName,
    rowNumber: row['__rowNumber'] as int,
    type: type,
    client: '${row['Client Name'] ?? '$type ${index + 1}'}'.trim(),
    item: '${row['Item Pawned'] ?? row['Column 1'] ?? 'Loan item'}'.trim(),
    loan: loan,
    interest: interest,
    total: total,
    paid: paid,
    remaining: remaining.toDouble(),
    overdueDays: overdueDays,
    riskScore: score.round(),
    risk: riskBand(score.toDouble()),
    dueDate: dueDate,
    dateGiven: parseDate(row['Date Given']),
    location: '${row['Location'] ?? ''}'.trim(),
    phone: '${row['Client Number'] ?? row['Phone Number'] ?? ''}'.trim(),
    customerIdNumber: '${row['Customer ID Number / Omang'] ?? row['Omang'] ?? ''}'.trim(),
    emergencyContact: '${row['Emergency Contact'] ?? ''}'.trim(),
    addressArea: '${row['Address / Area'] ?? row['Address'] ?? ''}'.trim(),
    itemSerial: '${row['Item Serial / IMEI'] ?? row['Serial Number'] ?? row['IMEI'] ?? ''}'.trim(),
    proofOfOwnership: '${row['Proof Of Ownership'] ?? ''}'.trim(),
    testingChecklist: '${row['Testing Checklist'] ?? ''}'.trim(),
    staffMember: '${row['Staff Member'] ?? ''}'.trim(),
    extensionCount: parseNumber(row['Extension Count']).round(),
    forfeitureDate: parseDate(row['Forfeiture Date']),
    correctionReason: '${row['Correction Reason'] ?? ''}'.trim(),
  );
}
