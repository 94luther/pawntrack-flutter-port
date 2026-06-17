import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/pawntrack_models.dart';

class AnalyticsAiBrief {
  const AnalyticsAiBrief({
    required this.summary,
    required this.collectionActions,
    required this.inventoryActions,
    required this.riskActions,
    required this.cashActions,
    required this.generatedByAi,
    this.fallbackReason,
  });

  final String summary;
  final List<String> collectionActions;
  final List<String> inventoryActions;
  final List<String> riskActions;
  final List<String> cashActions;
  final bool generatedByAi;
  final String? fallbackReason;

  factory AnalyticsAiBrief.fromJson(Map<String, dynamic> json) {
    return AnalyticsAiBrief(
      summary: _readString(json['summary']).isEmpty
          ? 'AI analytics completed, but no executive summary was returned.'
          : _readString(json['summary']),
      collectionActions: _readList(json['collectionActions']),
      inventoryActions: _readList(json['inventoryActions']),
      riskActions: _readList(json['riskActions']),
      cashActions: _readList(json['cashActions']),
      generatedByAi: true,
    );
  }

  factory AnalyticsAiBrief.fromText(String text) {
    return AnalyticsAiBrief(
      summary: text.trim(),
      collectionActions: const [],
      inventoryActions: const [],
      riskActions: const [],
      cashActions: const [],
      generatedByAi: true,
    );
  }

  factory AnalyticsAiBrief.local(PawnTrackModel data, {Object? error}) {
    final openLoans = data.loans.where((loan) => loan.remaining > 0).toList();
    final highRiskAmount = data.highRiskBorrowers.fold(
      0.0,
      (sum, loan) => sum + loan.remaining,
    );
    final agedInventory = data.inventoryAging
        .where((row) => row.bucket == '31+ days')
        .fold(0.0, (sum, row) => sum + row.value);
    final topCategory = data.byCategory.isEmpty ? null : data.byCategory.first;
    final topRisk =
        data.highRiskBorrowers.isEmpty ? null : data.highRiskBorrowers.first;
    final overdueShare = _safeDivide(data.overdueAmount, data.remaining);
    final interestYield =
        _safeDivide(data.expectedInterest, data.principalOutstanding);

    return AnalyticsAiBrief(
      summary:
          'Current book has ${openLoans.length} open loans with ${moneyFormat.format(data.remaining)} still outstanding. '
          '${moneyFormat.format(data.overdueAmount)} is overdue, collection rate is ${_percent(data.collectionRate)}, '
          'and expected interest yield is ${_percent(interestYield)}. Inventory on hand is ${moneyFormat.format(data.inventoryValue)}, '
          'with ${moneyFormat.format(agedInventory)} sitting in the 31+ day aging bucket.',
      collectionActions: [
        if (topRisk == null)
          'No high-risk borrower is currently above the local scoring threshold.'
        else
          'Call ${topRisk.client} first: ${moneyFormat.format(topRisk.remaining)} remaining, ${topRisk.overdueDays} days overdue, risk score ${topRisk.riskScore}.',
        'Work today and this week before issuing fresh cash: ${moneyFormat.format(data.dueToday)} due today and ${moneyFormat.format(data.due7)} due within 7 days.',
        'Overdue exposure is ${_percent(overdueShare)} of the open balance; keep repayment follow-up ahead of new lending until it drops.',
      ],
      inventoryActions: [
        'Review ${data.discountItems.length} discount candidates before adding new stock to the floor.',
        if (topCategory == null)
          'No inventory category concentration is available from the current sheet.'
        else
          '${topCategory.name} leads available inventory at ${moneyFormat.format(topCategory.value)} across ${topCategory.count} items.',
        'Move aged stock: ${moneyFormat.format(agedInventory)} is listed at 31+ days or has no list date.',
      ],
      riskActions: [
        '${data.highRiskBorrowers.length} borrowers are high risk, totaling ${moneyFormat.format(highRiskAmount)} outstanding.',
        '${data.overdue.length} loans are overdue; prioritize balances above the shop average of ${moneyFormat.format(_safeDivide(data.remaining, openLoans.length.toDouble()))}.',
        'Check missing phone numbers and serials before enforcement or forfeiture decisions.',
      ],
      cashActions: [
        'Scheduled 30-day collections are ${moneyFormat.format(data.due30)} against ${moneyFormat.format(data.remaining)} open balance.',
        'Keep a cash reserve for the next 7 days of expected collections: ${moneyFormat.format(data.due7)}.',
        'Expected net profit is ${moneyFormat.format(data.expectedNetProfit)} after sales, inventory value, and expected interest.',
      ],
      generatedByAi: false,
      fallbackReason: error == null ? null : '$error',
    );
  }

  static String _readString(dynamic value) => '${value ?? ''}'.trim();

  static List<String> _readList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .take(6)
          .toList();
    }
    final text = _readString(value);
    return text.isEmpty ? const [] : [text];
  }
}

class PawnTrackAnalyticsAiService {
  PawnTrackAnalyticsAiService({GenerativeModel? model})
      : _model = model ??
            FirebaseAI.googleAI().generativeModel(
              model: 'gemini-3.5-flash',
            );

  final GenerativeModel _model;

  Future<AnalyticsAiBrief> generateBrief(PawnTrackModel data) async {
    try {
      final response = await _model.generateContent([
        Content.text(_buildPrompt(data)),
      ]);
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        return AnalyticsAiBrief.local(data,
            error: 'Empty Firebase AI response');
      }

      final jsonText = _extractJsonObject(text);
      if (jsonText == null) return AnalyticsAiBrief.fromText(text);

      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        return AnalyticsAiBrief.fromJson(decoded);
      }
      return AnalyticsAiBrief.local(
        data,
        error: 'Firebase AI returned an unexpected analytics shape',
      );
    } catch (error) {
      return AnalyticsAiBrief.local(data, error: error);
    }
  }

  String _buildPrompt(PawnTrackModel data) {
    final context = _analyticsContext(data);
    return '''
You are Gemini inside PawnTrack, a daily pawnshop operating system for Last Resort Pawnshop.
Use only the live PawnTrack data below. Be specific, practical, and concise.
Focus on collections, cash, borrower risk, stock movement, and today's operating priorities.
Use Botswana pula (BWP). Do not invent missing facts.

Return ONLY compact JSON with this shape:
{
  "summary": "one short paragraph",
  "collectionActions": ["action", "action", "action"],
  "inventoryActions": ["action", "action", "action"],
  "riskActions": ["action", "action", "action"],
  "cashActions": ["action", "action", "action"]
}

Current live PawnTrack analytics context:
${jsonEncode(context)}
''';
  }

  Map<String, dynamic> _analyticsContext(PawnTrackModel data) {
    final openLoans = data.loans.where((loan) => loan.remaining > 0).toList();
    final highRisk = data.highRiskBorrowers;
    final mediumRisk = openLoans
        .where((loan) => loan.riskScore >= 40 && loan.riskScore < 70)
        .toList();
    final lowRisk = openLoans.where((loan) => loan.riskScore < 40).toList();
    final activeOutstanding =
        data.active.fold(0.0, (sum, loan) => sum + loan.remaining);
    final osOutstanding =
        data.os.fold(0.0, (sum, loan) => sum + loan.remaining);
    final agedInventory = data.inventoryAging
        .where((row) => row.bucket == '31+ days')
        .fold(0.0, (sum, row) => sum + row.value);
    final missingPhones =
        openLoans.where((loan) => loan.phone.trim().isEmpty).length;
    final missingSerials =
        data.active.where((loan) => loan.itemSerial.trim().isEmpty).length;

    return {
      'business': 'Last Resort Pawnshop',
      'currency': 'BWP',
      'source': data.source.source,
      'syncedAt': data.source.syncedAt?.toIso8601String(),
      'operationalKpis': {
        'openLoanCount': openLoans.length,
        'activePawnCount': data.active.length,
        'outstandingDebtCount': data.os.length,
        'principalOutstanding': data.principalOutstanding,
        'expectedRepayment': data.expectedRepayment,
        'remainingBalance': data.remaining,
        'cashCollected': data.collected,
        'collectionRate': data.collectionRate,
        'expectedInterest': data.expectedInterest,
        'interestYield':
            _safeDivide(data.expectedInterest, data.principalOutstanding),
        'overdueLoanCount': data.overdue.length,
        'overdueAmount': data.overdueAmount,
        'overdueShareOfOpenBalance':
            _safeDivide(data.overdueAmount, data.remaining),
        'dueToday': data.dueToday,
        'due7Days': data.due7,
        'dueNextWeek': data.dueNextWeek,
        'due30Days': data.due30,
        'due90Days': data.due90,
        'inventoryValue': data.inventoryValue,
        'availableInventoryCount': data.availableInventory.length,
        'soldInventoryCount': data.soldInventory.length,
        'salesEarned': data.salesEarned,
        'salesProfit': data.salesProfit,
        'expectedNetProfit': data.expectedNetProfit,
        'agedInventoryValue': agedInventory,
        'discountCandidateCount': data.discountItems.length,
        'missingPhoneCount': missingPhones,
        'missingSerialCount': missingSerials,
      },
      'riskSegments': [
        _loanSegment('High risk', highRisk),
        _loanSegment('Medium risk', mediumRisk),
        _loanSegment('Low risk', lowRisk),
      ],
      'loanBookSegments': [
        {
          'name': 'Active Pawns',
          'count': data.active.length,
          'remaining': activeOutstanding,
        },
        {
          'name': 'OS Debts',
          'count': data.os.length,
          'remaining': osOutstanding,
        },
      ],
      'dueWindows': {
        'today': data.dueToday,
        'sevenDays': data.due7,
        'nextWeek': data.dueNextWeek,
        'thirtyDays': data.due30,
        'ninetyDays': data.due90,
      },
      'inventoryCategories': data.byCategory
          .take(8)
          .map((row) => {
                'category': row.name,
                'value': row.value,
                'count': row.count,
              })
          .toList(),
      'inventoryAging': data.inventoryAging
          .map((row) => {
                'bucket': row.bucket,
                'count': row.count,
                'value': row.value,
              })
          .toList(),
      'collectionPriorities': highRisk
          .take(12)
          .map((loan) => {
                'client': loan.client,
                'item': loan.item,
                'remaining': loan.remaining,
                'paid': loan.paid,
                'dueDate': loan.dueDate?.toIso8601String().substring(0, 10),
                'daysOverdue': loan.overdueDays,
                'riskScore': loan.riskScore,
                'phonePresent': loan.phone.trim().isNotEmpty,
                'location': loan.location,
              })
          .toList(),
      'discountCandidates': data.discountItems
          .take(12)
          .map((item) => {
                'product': item.product,
                'category': item.category,
                'listedAmount': item.value,
                'pawnAmount': item.pawnAmount,
                'ageDays': item.age,
                'daysHeld': item.daysHeld,
              })
          .toList(),
      'monthlyTrend': data.monthlyGrowth
          .take(12)
          .map((row) => {
                'month': row.month,
                'loans': row.loans,
                'repayment': row.repayment,
                'recovered': row.recovered,
                'profit': row.profit,
                'growthPct': row.growthPct,
              })
          .toList(),
    };
  }

  Map<String, dynamic> _loanSegment(String name, Iterable<LoanRecord> loans) {
    final rows = loans.toList();
    final remaining = rows.fold(0.0, (sum, loan) => sum + loan.remaining);
    final overdue = rows
        .where((loan) => loan.overdueDays > 0)
        .fold(0.0, (sum, loan) => sum + loan.remaining);
    return {
      'name': name,
      'count': rows.length,
      'remaining': remaining,
      'overdue': overdue,
      'averageRiskScore': _safeDivide(
        rows.fold(0.0, (sum, loan) => sum + loan.riskScore),
        rows.length.toDouble(),
      ),
    };
  }

  String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }
}

double _safeDivide(double numerator, double denominator) {
  if (denominator == 0 || denominator.isNaN) return 0;
  final result = numerator / denominator;
  return result.isFinite ? result : 0;
}

String _percent(double value) {
  if (!value.isFinite) return '0%';
  return '${(value * 100).round()}%';
}
