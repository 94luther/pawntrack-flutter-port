import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/pawntrack_models.dart';

class PawnTrackApi {
  PawnTrackApi({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  DocumentReference<Map<String, dynamic>> get _latestSnapshot => firestore.collection('sheetSnapshots').doc('latest');

  Future<SheetSource> sheetData() async {
    final snapshot = await _latestSnapshot.get();
    if (!snapshot.exists) {
      throw Exception('Firestore has no imported PawnTrack data yet.');
    }
    final data = snapshot.data() ?? {};
    final rawPayload = data['payloadJson'];
    final payload = rawPayload is String
        ? jsonDecode(rawPayload) as Map<String, dynamic>
        : Map<String, dynamic>.from(data['payload'] as Map? ?? {});
    payload['source'] = 'Cloud Firestore: PawnTrack';
    payload['syncedAt'] ??= data['syncedAt']?.toString();
    return SheetSource.fromJson(payload);
  }

  Future<void> batchUpdate(List<Map<String, dynamic>> updates, {Map<String, dynamic>? metadata}) async {
    final source = await sheetData();
    final payload = _sourceToPayload(source);
    for (final update in updates) {
      _applySheetUpdate(payload, update);
    }
    await _savePayload(payload, metadata: metadata ?? {}, updates: updates);
    await _recordOperationalEvent(metadata ?? {}, updates);
  }

  Future<void> inventorySale(Map<String, dynamic> item, List<Map<String, dynamic>> updates) async {
    await batchUpdate(updates, metadata: {'type': 'inventory_sale', 'item': item});
    final saleId = _stableId('${item['sheetName'] ?? 'inventory'}-row-${item['rowNumber'] ?? item['id']}-sale');
    await firestore.collection('sales').doc(saleId).set(_clean({
      'sheetName': item['sheetName'],
      'rowNumber': item['rowNumber'],
      'product': item['product'],
      'category': item['category'],
      'listedAmount': _num(item['listedAmount']),
      'pawnedAmount': _num(item['pawnedAmount']),
      'expectedRepayment': _num(item['expectedRepayment']),
      'sellAmount': _num(item['sellAmount']),
      'profit': _num(item['profit']),
      'saleDate': item['saleDate'],
      'dateGiven': item['dateGiven'],
      'daysHeld': item['daysHeld'],
      'payload': item,
      'updatedAt': FieldValue.serverTimestamp(),
    }), SetOptions(merge: true));
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
    final fileId = firestore.collection('_ids').doc().id;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-');
    final path = switch (kind) {
      'customer-photo' => 'customers/${customerId ?? 'unassigned-customer'}/customer-photo/$fileId-$safeName',
      'id-photo' => 'customers/${customerId ?? 'unassigned-customer'}/id-photo/$fileId-$safeName',
      'item-photo' => 'items/${itemId ?? 'unassigned-item'}/photos/$fileId-$safeName',
      'proof-of-ownership' => 'items/${itemId ?? 'unassigned-item'}/proof/$fileId-$safeName',
      _ => throw Exception('Unsupported upload kind: $kind'),
    };
    final ref = storage.ref(path);
    await ref.putData(bytes);
    final url = await ref.getDownloadURL();
    final result = {
      'kind': kind,
      'bucket': ref.bucket,
      'path': path,
      'url': url,
      'fileName': fileName,
    };
    await firestore.collection('storageUploads').add(_clean({
      ...result,
      'customerId': customerId,
      'itemId': itemId,
      'createdAt': FieldValue.serverTimestamp(),
    }));
    if (customerId != null && (kind == 'customer-photo' || kind == 'id-photo')) {
      await firestore.collection('customers').doc(customerId).set({
        kind == 'customer-photo' ? 'customerPhotoUrl' : 'idPhotoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (itemId != null && (kind == 'item-photo' || kind == 'proof-of-ownership')) {
      await firestore.collection('items').doc(itemId).set({
        kind == 'item-photo' ? 'itemPhotoUrls' : 'proofOfOwnershipUrls': FieldValue.arrayUnion([url]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return result;
  }

  Future<void> _savePayload(Map<String, dynamic> payload, {required Map<String, dynamic> metadata, required List<Map<String, dynamic>> updates}) async {
    final next = {
      ...payload,
      'source': 'Cloud Firestore: PawnTrack',
      'syncedAt': DateTime.now().toIso8601String(),
    };
    await _latestSnapshot.set({
      'source': next['source'],
      'syncedAt': next['syncedAt'],
      'payloadJson': jsonEncode(next),
      'metadata': _clean(metadata),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await firestore.collection('syncJobs').add(_clean({
      'kind': 'flutterfire_direct_update',
      'status': 'firestore_only',
      'payload': {'metadata': metadata, 'updates': updates},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
    await _mirrorRows(next);
  }

  Future<void> _recordOperationalEvent(Map<String, dynamic> metadata, List<Map<String, dynamic>> updates) async {
    if (metadata['type'] == null) return;
    await firestore.collection('auditLog').add(_clean({
      'entityType': metadata['type'],
      'entityId': metadata['loan']?['rowNumber'] ?? metadata['item']?['rowNumber'] ?? metadata['customerName'],
      'action': metadata['type'],
      'afterPayload': {'metadata': metadata, 'updates': updates},
      'createdAt': FieldValue.serverTimestamp(),
    }));
    if (metadata['type'] == 'loan_update' && _num(metadata['loan']?['paymentAmount']) > 0) {
      await firestore.collection('repayments').add(_clean({
        'sheetName': metadata['loan']?['sheetName'],
        'rowNumber': metadata['loan']?['rowNumber'],
        'clientName': metadata['loan']?['clientName'],
        'amount': _num(metadata['loan']?['paymentAmount']),
        'dueDate': metadata['loan']?['dueDate'],
        'payload': metadata['loan'],
        'createdAt': FieldValue.serverTimestamp(),
      }));
    }
    if (metadata['type'] == 'new_pawn') {
      await firestore.collection('voiceCommands').add(_clean({
        'transcript': 'Create a new pawn for ${metadata['customerName'] ?? 'customer'}',
        'parsedAction': 'new_pawn',
        'status': 'applied',
        'payload': metadata,
        'createdAt': FieldValue.serverTimestamp(),
      }));
    }
    if (metadata['type'] == 'forfeiture') {
      await firestore.collection('auditLog').add(_clean({
        'entityType': 'loan',
        'entityId': '${metadata['loan']?['sheetName']}:${metadata['loan']?['rowNumber']}',
        'action': 'forfeit_to_inventory',
        'afterPayload': metadata,
        'createdAt': FieldValue.serverTimestamp(),
      }));
    }
  }

  Future<void> _mirrorRows(Map<String, dynamic> payload) async {
    final batch = firestore.batch();
    _mirrorLoans(batch, 'Active Pawns', payload['activePawns'] as List<dynamic>? ?? []);
    _mirrorLoans(batch, 'OS Debts', payload['osDebts'] as List<dynamic>? ?? []);
    _mirrorInventory(batch, payload['companyOwnedItems'] as List<dynamic>? ?? []);
    await batch.commit();
  }

  void _mirrorLoans(WriteBatch batch, String sheetName, List<dynamic> rows) {
    for (final row in toObjects(rows)) {
      final rowNumber = row['__rowNumber'] as int;
      final loanId = _stableId('${sheetName == 'Active Pawns' ? 'active-pawns' : 'os-debts'}-row-$rowNumber');
      final customerId = _stableId('${row['Customer ID Number / Omang'] ?? row['Omang'] ?? row['Client Number'] ?? row['Phone Number'] ?? row['Client Name'] ?? loanId}');
      final loanAmount = _num(row['Loan Amount']);
      final interestAmount = _num(row['Interest Amount']);
      final totalPayback = _num(row['Total Payback']) != 0 ? _num(row['Total Payback']) : loanAmount + interestAmount;
      final amountPaid = _num(row['Amount Paid']);
      final remainingBalance = _num(row['Remaining Balance']) != 0 ? _num(row['Remaining Balance']) : (totalPayback - amountPaid).clamp(0, double.infinity);
      final dueDate = parseDate(row['Due Date']);
      final overdueDays = [
        _num(row['Days Overdue']).round(),
        dueDate == null ? 0 : daysBetween(today, dueDate),
      ].reduce((a, b) => a > b ? a : b);
      final riskScore = ((overdueDays > 0 ? (overdueDays * 1.5).clamp(0, 45) : 0) +
              (amountPaid > 0 && remainingBalance > 0 ? 12 : 0) +
              (overdueDays > 0 && remainingBalance > 0 ? 25 : 0) +
              (loanAmount >= 5000 ? 20 : loanAmount >= 2500 ? 12 : 6))
          .round();
      batch.set(firestore.collection('customers').doc(customerId), _clean({
        'customerCode': customerId,
        'fullName': row['Client Name'] ?? 'Customer $rowNumber',
        'omang': row['Customer ID Number / Omang'] ?? row['Omang'],
        'phoneNumber': row['Phone Number'] ?? row['Client Number'],
        'emergencyContact': row['Emergency Contact'],
        'addressArea': row['Address / Area'],
        'updatedAt': FieldValue.serverTimestamp(),
      }), SetOptions(merge: true));
      batch.set(firestore.collection('loans').doc(loanId), _clean({
        'sheetName': sheetName,
        'rowNumber': rowNumber,
        'customerId': customerId,
        'clientName': row['Client Name'],
        'itemPawned': row['Item Pawned'] ?? row['Column 1'],
        'loanAmount': loanAmount,
        'interestAmount': interestAmount,
        'totalPayback': totalPayback,
        'amountPaid': amountPaid,
        'remainingBalance': remainingBalance,
        'dueDate': dueDate?.toIso8601String().substring(0, 10),
        'dateGiven': parseDate(row['Date Given'])?.toIso8601String().substring(0, 10),
        'location': row['Location'] ?? row['Storage Location'],
        'extensionCount': _num(row['Extension Count']),
        'daysOverdue': overdueDays,
        'riskScore': riskScore,
        'status': remainingBalance > 0 ? (overdueDays > 0 ? 'overdue' : 'active') : 'closed',
        'payload': row,
        'updatedAt': FieldValue.serverTimestamp(),
      }), SetOptions(merge: true));
      batch.set(firestore.collection('riskScores').doc(loanId), _clean({
        'customerId': customerId,
        'loanId': loanId,
        'score': riskScore,
        'band': riskScore >= 70 ? 'High risk' : riskScore >= 40 ? 'Medium risk' : 'Low risk',
        'calculatedAt': FieldValue.serverTimestamp(),
      }), SetOptions(merge: true));
    }
  }

  void _mirrorInventory(WriteBatch batch, List<dynamic> rows) {
    for (final row in toObjects(rows)) {
      final rowNumber = row['__rowNumber'] as int;
      final inventoryId = _stableId('company-owned-row-$rowNumber');
      final sold = _num(row['Sell amount']);
      final pawnedAmount = _num(row['Amount paid']);
      final profit = _num(row['Profit/loss']) != 0 ? _num(row['Profit/loss']) : (sold > 0 ? sold - pawnedAmount : 0);
      batch.set(firestore.collection('inventory').doc(inventoryId), _clean({
        'sheetName': 'Company Owned Items',
        'rowNumber': rowNumber,
        'product': row['Product'],
        'category': row['Category'],
        'damages': row['Damages'],
        'listedStatus': row['Listed on Market place'],
        'listDate': parseDate(row['List Date'])?.toIso8601String().substring(0, 10),
        'listedAmount': _num(row['List amount']),
        'pawnedAmount': pawnedAmount,
        'sellAmount': sold,
        'profit': profit,
        'location': row['Location'],
        'saleDate': parseDate(row['Sale Date'])?.toIso8601String().substring(0, 10),
        'dateGiven': parseDate(row['Date Given'])?.toIso8601String().substring(0, 10),
        'expectedRepayment': _num(row['Expected Repayment']),
        'daysHeld': _num(row['Days Held']),
        'status': sold > 0 || '${row['Listed on Market place'] ?? ''}'.toLowerCase().contains('sold') ? 'sold' : 'available',
        'payload': row,
        'updatedAt': FieldValue.serverTimestamp(),
      }), SetOptions(merge: true));
    }
  }

  Map<String, dynamic> _sourceToPayload(SheetSource source) {
    return {
      'source': source.source,
      'syncedAt': source.syncedAt?.toIso8601String(),
      'companyOwnedItems': _deepCloneRows(source.companyOwnedItems),
      'osDebts': _deepCloneRows(source.osDebts),
      'activePawns': _deepCloneRows(source.activePawns),
      'damagedGoods': _deepCloneRows(source.damagedGoods),
    };
  }

  List<List<dynamic>> _deepCloneRows(List<dynamic> rows) {
    return rows.map((row) => row is List ? List<dynamic>.from(row) : <dynamic>[row]).toList();
  }

  void _applySheetUpdate(Map<String, dynamic> payload, Map<String, dynamic> update) {
    final parsed = _parseRange('${update['range']}');
    final key = _sheetToPayloadKey(parsed.sheetName);
    if (key == null) return;
    final rows = (payload[key] as List<dynamic>? ?? <dynamic>[]);
    payload[key] = rows;
    final values = update['values'] as List<dynamic>? ?? [];
    for (var rowOffset = 0; rowOffset < values.length; rowOffset++) {
      final rowIndex = parsed.startRow - 1 + rowOffset;
      while (rows.length <= rowIndex) {
        rows.add(<dynamic>[]);
      }
      final row = rows[rowIndex] is List ? rows[rowIndex] as List<dynamic> : <dynamic>[rows[rowIndex]];
      rows[rowIndex] = row;
      final rowValues = values[rowOffset] as List<dynamic>? ?? [];
      for (var colOffset = 0; colOffset < rowValues.length; colOffset++) {
        final colIndex = parsed.startColumn + colOffset;
        while (row.length <= colIndex) {
          row.add('');
        }
        row[colIndex] = rowValues[colOffset];
      }
    }
  }

  _ParsedRange _parseRange(String range) {
    final match = RegExp(r"^'?([^']+)'?!([A-Z]+)(\d+)(?::([A-Z]+)(\d+))?$", caseSensitive: false).firstMatch(range);
    if (match == null) throw Exception('Unsupported range: $range');
    return _ParsedRange(
      sheetName: match.group(1)!,
      startColumn: _columnToIndex(match.group(2)!),
      startRow: int.parse(match.group(3)!),
    );
  }

  int _columnToIndex(String column) {
    var sum = 0;
    for (final code in column.toUpperCase().codeUnits) {
      sum = sum * 26 + code - 64;
    }
    return sum - 1;
  }

  String? _sheetToPayloadKey(String sheetName) {
    return switch (sheetName) {
      'Company Owned Items' => 'companyOwnedItems',
      'OS Debts' => 'osDebts',
      'Active Pawns' => 'activePawns',
      'Damaged goods' => 'damagedGoods',
      _ => null,
    };
  }

  Map<String, dynamic> _clean(Map<String, dynamic> value) {
    return Map<String, dynamic>.fromEntries(value.entries.where((entry) => entry.value != null).map((entry) {
      final v = entry.value;
      if (v is Map<String, dynamic>) return MapEntry(entry.key, _clean(v));
      if (v is Map) return MapEntry(entry.key, _clean(Map<String, dynamic>.from(v)));
      if (v is List) return MapEntry(entry.key, v.map((item) => item is Map ? _clean(Map<String, dynamic>.from(item)) : item).toList());
      return entry;
    }));
  }

  num _num(dynamic value) => parseNumber(value);

  String _stableId(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  }
}

class _ParsedRange {
  const _ParsedRange({required this.sheetName, required this.startColumn, required this.startRow});

  final String sheetName;
  final int startColumn;
  final int startRow;
}
