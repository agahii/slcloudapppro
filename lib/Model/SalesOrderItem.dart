import '../my_sales_orders_screen.dart';

class SalesOrderItem {
  final String? skuName;   // product name
  final int quantity;
  final double rate;       // ordered qty
  // unit price

  SalesOrderItem({
    required this.skuName,
    required this.quantity,
    required this.rate,
  });

  factory SalesOrderItem.fromJson(Map<String, dynamic> j) {
    return SalesOrderItem(
      skuName: j['skuName']?.toString() ?? j['itemName']?.toString(),
      quantity: int.tryParse((j['quantity'] ?? j['qty'] ?? 0).toString()) ?? 0,
      rate: _toDouble(j['agreedRate'] ?? j['rate'] ?? j['unitPrice'] ?? 0),
    );
  }
}
double _toDouble(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}