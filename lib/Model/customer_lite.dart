class CustomerLite {
  final String id;
  final String customer;        // short code/name e.g., "A M TRADERS(101939)"
  final String customerName;    // full name with area
  final String? customerAddress;
  final String? area;
  final String? employee;

  CustomerLite({
    required this.id,
    required this.customer,
    required this.customerName,
    this.customerAddress,
    this.area,
    this.employee,
  });

  factory CustomerLite.fromMap(Map<String, dynamic> m) => CustomerLite(
    id: (m['id'] ?? '').toString(),
    customer: (m['customer'] ?? '').toString(),
    customerName: (m['customerName'] ?? '').toString(),
    customerAddress: (m['customerAddress'] ?? '').toString(),
    area: (m['area'] ?? '').toString(),
    employee: m['employee']?.toString(),
  );
}
