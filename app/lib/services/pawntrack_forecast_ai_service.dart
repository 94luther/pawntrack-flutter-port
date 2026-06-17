import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/pawntrack_models.dart';

class PawnTrackForecastAiService {
  PawnTrackForecastAiService({GenerativeModel? model})
      : model = model ??
            FirebaseAI.googleAI().generativeModel(model: 'gemini-3.5-flash');

  final GenerativeModel model;

  Future<String> generateOperationalForecast(
      PawnTrackModel data, Map<String, Object?> forecastContext) async {
    final response = await model.generateContent([
      Content.text(_buildPrompt(data, forecastContext)),
    ]);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Firebase AI Logic returned an empty forecast.');
    }
    return text;
  }

  String _buildPrompt(
      PawnTrackModel data, Map<String, Object?> forecastContext) {
    final payload = {
      'business': 'Last Resort Pawnshop',
      'currency': 'BWP',
      'source': data.source.source,
      'syncedAt': data.source.syncedAt?.toIso8601String(),
      'forecastContext': forecastContext,
      'topOpenLoans': data.loans
          .where((loan) => loan.remaining > 0)
          .take(80)
          .map((loan) => {
                'client': loan.client,
                'item': loan.item,
                'sheet': loan.sheetName,
                'remaining': loan.remaining,
                'paid': loan.paid,
                'dueDate': loan.dueDate?.toIso8601String().substring(0, 10),
                'daysOverdue': loan.overdueDays,
                'riskScore': loan.riskScore,
                'riskBand': loan.risk.label,
                'phone': loan.phone,
                'location': loan.location,
              })
          .toList(),
      'inventoryForAction': data.availableInventory
          .take(80)
          .map((item) => {
                'product': item.product,
                'category': item.category,
                'listedAmount': item.value,
                'pawnAmount': item.pawnAmount,
                'expectedRepayment': item.expectedRepayment,
                'ageDays': item.age,
                'daysHeld': item.daysHeld,
              })
          .toList(),
    };

    return '''
You are Gemini inside PawnTrack, a daily pawnshop operating system for Last Resort Pawnshop.
Use only the live data and deterministic forecast context below. Do not invent missing facts.
Write a concise operating forecast for today's pawnshop manager in Botswana pula (BWP).
Focus on cash expected, collection risk, inventory liquidation, and the next actions for staff.
Return 5 short bullet points. Mention when an action is driven by risk, overdue amount, or slow-moving stock.

Live PawnTrack forecast payload:
${jsonEncode(payload)}
''';
  }
}
