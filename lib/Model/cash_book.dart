class CashBookEntry {
  final String id;
  final DateTime datePosting;
  final String narration;
  final double debit;
  final double credit;
  final String refNumber;
  final String chequeNumber;

  CashBookEntry({
    required this.id,
    required this.datePosting,
    required this.narration,
    required this.debit,
    required this.credit,
    required this.refNumber,
    required this.chequeNumber,
  });

  factory CashBookEntry.fromJson(Map<String, dynamic> j) {
    return CashBookEntry(
      id: (j['id'] ?? '').toString(),
      datePosting: DateTime.tryParse((j['datePosting'] ?? '').toString()) ?? DateTime.now(),
      narration: (j['narration'] ?? '').toString(),
      debit: (j['debit'] is num) ? (j['debit'] as num).toDouble() : double.tryParse('${j['debit']}') ?? 0.0,
      credit: (j['credit'] is num) ? (j['credit'] as num).toDouble() : double.tryParse('${j['credit']}') ?? 0.0,
      refNumber: (j['refNumber'] ?? '').toString(),
      chequeNumber: (j['chequeNumber'] ?? '').toString(),
    );
  }
}

class CashBookResponse {
  final int responseCode;
  final String message;
  final int totalRecords;
  final int pageSize;
  final int pageIndex;
  final int totalRecordsInResponse;
  final List<CashBookEntry> data;

  CashBookResponse({
    required this.responseCode,
    required this.message,
    required this.totalRecords,
    required this.pageSize,
    required this.pageIndex,
    required this.totalRecordsInResponse,
    required this.data,
  });

  factory CashBookResponse.fromJson(Map<String, dynamic> j) {
    final List<dynamic> arr = (j['data'] as List?) ?? const [];
    return CashBookResponse(
      responseCode: (j['responseCode'] ?? 0) as int,
      message: (j['message'] ?? '').toString(),
      totalRecords: (j['totalRecords'] ?? 0) as int,
      pageSize: (j['pageSize'] ?? 0) as int,
      pageIndex: (j['pageIndex'] ?? 0) as int,
      totalRecordsInResponse: (j['totalRecordsInResponse'] ?? 0) as int,
      data: arr.map((e) => CashBookEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
