import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/pawntrack_models.dart';

class PawnTrackAiService {
  PawnTrackAiService({GenerativeModel? model})
      : model = model ?? FirebaseAI.googleAI().generativeModel(model: 'gemini-3.5-flash');

  final GenerativeModel model;

  Future<String> answerQuestion(PawnTrackModel data, String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return 'Ask a question about the pawnshop data first.';
    final prompt = _buildPrompt(data, trimmed);
    final response = await model.generateContent([Content.text(prompt)]);
    return response.text?.trim().isNotEmpty == true ? response.text!.trim() : 'Gemini did not return an answer.';
  }

  String _buildPrompt(PawnTrackModel data, String question) {
    final context = {
      'business': 'Last Resort Pawnshop',
      'currency': 'BWP',
      'source': data.source.source,
      'syncedAt': data.source.syncedAt?.toIso8601String(),
      'dailyMetrics': {
        'cashCollected': data.collected,
        'expectedCashToday': data.dueToday,
        'expectedCashThisWeek': data.due7,
        'expectedCashNextWeek': data.dueNextWeek,
        'loansDueToday': data.dueTodayLoans.length,
        'overdueLoans': data.overdue.length,
        'overdueAmount': data.overdueAmount,
        'highRiskBorrowers': data.highRiskBorrowers.length,
        'inventoryReadyToSell': data.availableInventory.length,
        'inventoryValue': data.inventoryValue,
        'realSalesProfit': data.salesProfit,
        'profitForecast': data.expectedNetProfit,
      },
      'loans': data.loans.take(80).map((loan) => {
            'client': loan.client,
            'item': loan.item,
            'sheet': loan.sheetName,
            'loanAmount': loan.loan,
            'totalPayback': loan.total,
            'paid': loan.paid,
            'remaining': loan.remaining,
            'dueDate': loan.dueDate?.toIso8601String().substring(0, 10),
            'daysOverdue': loan.overdueDays,
            'riskScore': loan.riskScore,
            'riskBand': loan.risk.label,
            'phone': loan.phone,
            'location': loan.location,
          }).toList(),
      'inventory': data.inventory.take(80).map((item) => {
            'product': item.product,
            'category': item.category,
            'listedAmount': item.value,
            'pawnAmount': item.pawnAmount,
            'expectedRepayment': item.expectedRepayment,
            'soldAmount': item.sold,
            'profit': item.profit,
            'isSold': item.isSold,
            'ageDays': item.age,
            'daysHeld': item.daysHeld,
          }).toList(),
    };

    return '''
You are Gemini inside PawnTrack, a daily pawnshop operating system for Last Resort Pawnshop.
Answer the user's question using only the data below. Do not invent missing facts.
When useful, calculate totals, rank customers/items, and give practical next actions.
Keep the answer concise, operational, and in Botswana pula (BWP).

User question:
$question

Current live PawnTrack data:
${jsonEncode(context)}
''';
  }
}
