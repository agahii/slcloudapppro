class Customer {
  final String id;
  final String customerName;
  final String customerAddress;

  Customer({
    required this.id,
    required this.customerName,
    required this.customerAddress,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      customerName: json['customerName'],
      customerAddress: json['customerAddress'] ?? '',
    );
  }
}
