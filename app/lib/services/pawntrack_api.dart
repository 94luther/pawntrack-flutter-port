import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/pawntrack_models.dart';

class PawnTrackApi {
  PawnTrackApi({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl();

  final String baseUrl;

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      final uri = Uri.base;
      final isLocal = uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.scheme == 'file';
      if (!isLocal && uri.hasScheme && uri.host.isNotEmpty) return uri.origin;
    }
    return 'http://127.0.0.1:8805';
  }

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

  Future<Map<String, dynamic>> uploadCustomerPhoto({
    required String customerId,
    required Uint8List bytes,
    required String fileName,
  }) {
    return _uploadFile(kind: 'customer-photo', customerId: customerId, bytes: bytes, fileName: fileName);
  }

  Future<Map<String, dynamic>> uploadIdPhoto({
    required String customerId,
    required Uint8List bytes,
    required String fileName,
  }) {
    return _uploadFile(kind: 'id-photo', customerId: customerId, bytes: bytes, fileName: fileName);
  }

  Future<Map<String, dynamic>> uploadItemPhoto({
    required String itemId,
    required Uint8List bytes,
    required String fileName,
  }) {
    return _uploadFile(kind: 'item-photo', itemId: itemId, bytes: bytes, fileName: fileName);
  }

  Future<Map<String, dynamic>> uploadProofOfOwnership({
    required String itemId,
    required Uint8List bytes,
    required String fileName,
  }) {
    return _uploadFile(kind: 'proof-of-ownership', itemId: itemId, bytes: bytes, fileName: fileName);
  }

  Future<Map<String, dynamic>> _uploadFile({
    required String kind,
    required Uint8List bytes,
    required String fileName,
    String? customerId,
    String? itemId,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload/$kind'));
    if (customerId != null) request.fields['customerId'] = customerId;
    if (itemId != null) request.fields['itemId'] = itemId;
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) {
      throw Exception('Could not upload file: ${response.body}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['upload'] as Map<String, dynamic>;
  }
}
