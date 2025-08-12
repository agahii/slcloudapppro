class SalesInvoice {
  final String? id;
  final String? docDate;
  final String? docNumber;
  final String? customerName;
  final String? customerNamePOS;
  final String? mobileNumber;
  final num? cashReceived;
  final String? bankReceived;
  final String? bankName;
  final String? itemsList;

  SalesInvoice({
    this.id,
    this.docDate,
    this.docNumber,
    this.customerName,
    this.customerNamePOS,
    this.mobileNumber,
    this.cashReceived,
    this.bankReceived,
    this.bankName,
    this.itemsList,
  });

  factory SalesInvoice.fromJson(Map<String, dynamic> j) {
    return SalesInvoice(
      id: j['id']?.toString(),
      docDate: j['docDate']?.toString(),
      docNumber: j['docNumber']?.toString(),
      customerName: j['customerName']?.toString(),
      customerNamePOS: j['customerNamePOS']?.toString(),
      mobileNumber: j['mobileNumber']?.toString(),
      cashReceived: j['cashReceived'],
      bankReceived: j['bankReceived']?.toString(),
      bankName: j['bankName']?.toString(),
      itemsList: j['itemsList']?.toString(),
    );
  }
}