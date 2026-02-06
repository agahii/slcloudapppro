class Customer {
  final String id;
  final String customerName;
  final String customerAddress;
  final int ledgerBalance;

  Customer({
    required this.id,
    required this.customerName,
    required this.customerAddress,
    required this.ledgerBalance,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      customerName: json['customerName'],
      customerAddress: json['customerAddress'] ?? '',
      ledgerBalance: json['ledgerBalance'] ?? '',
    );
  }
}
