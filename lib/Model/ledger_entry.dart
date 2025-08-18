class LedgerEntry {
  final String? docNo;
  final String? docType;
  final String? narration;
  final DateTime? docDate;
  final DateTime? datePosting;
  final double debit;
  final double credit;
  final double balance; // if backend returns running balance

  LedgerEntry({
    required this.docNo,
    required this.docType,
    required this.narration,
    required this.docDate,
    required this.datePosting,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  static double _num(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return DateTime.tryParse(s);
  }

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      docNo: json['docNo']?.toString(),
      docType: json['docType']?.toString(),
      narration: json['narration']?.toString(),
      docDate: _date(json['docDate']),
      datePosting: _date(json['datePosting']),
      debit: _num(json['debit']),
      credit: _num(json['credit']),
      balance: _num(json['balance']),
    );
  }
}
