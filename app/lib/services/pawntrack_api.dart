import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pawntrack_models.dart';

class PawnTrackApi {
  PawnTrackApi({this.baseUrl = 'http://127.0.0.1:8804'});

  final String baseUrl;

  Future<SheetSource> sheetData() async {
    final response = await http.get(Uri.parse('$baseUrl/api/sheet-data'));
    if (response.statusCode >= 400) {
      throw Exception('Could not load sheet data: ${response.body}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return SheetSource.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<void> batchUpdate(List<Map<String, dynamic>> updates, {Map<String, dynamic>? metadata}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/sheet-batch-update'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'updates': updates, 'metadata': metadata ?? {}}),
    );
    if (response.statusCode >= 400) {
      throw Exception('Could not save update: ${response.body}');
    }
  }

  Future<void> inventorySale(Map<String, dynamic> item, List<Map<String, dynamic>> updates) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/inventory-sale'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'item': item, 'updates': updates}),
    );
    if (response.statusCode >= 400) {
      throw Exception('Could not record sale: ${response.body}');
    }
  }
}
