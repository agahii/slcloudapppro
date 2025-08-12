class SalesOrder {
  final String? id;
  final String? orderNo; // derived from docNumber
  final String? docDate; // ISO string
  final String? customerName;
  final String? customerAddress;
  final String? deliveryAddress;
  final String? areaName;
  final String? productDetails; // raw comma-separated string
  final String? docNumber; // provided by API (number -> string)

  // parsed items from productDetails
  final List<SalesOrderItem> items;

  SalesOrder({
    required this.id,
    required this.orderNo,
    required this.docDate,
    required this.customerName,
    required this.customerAddress,
    required this.deliveryAddress,
    required this.areaName,
    required this.productDetails,
    required this.docNumber,
    required this.items,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> j) {
    final docNumber = j['docNumber']?.toString();
    final raw = j['productDetails']?.toString();
    final parsedItems = _parseProductDetails(raw);

    return SalesOrder(
      id: j['id']?.toString(),
      orderNo: docNumber, // no explicit orderNo in API; show docNumber
      docDate: j['docDate']?.toString(),
      customerName: j['customerName']?.toString(),
      customerAddress: j['customerAddress']?.toString(),
      deliveryAddress: j['deliveryAddress']?.toString(),
      areaName: j['areaName']?.toString(),
      productDetails: raw,
      docNumber: docNumber,
      items: parsedItems,
    );
  }
}

class SalesOrderItem {
  final String? skuName;
  final String? packingName;
  final int quantity;

  SalesOrderItem({
    required this.skuName,
    required this.packingName,
    required this.quantity,
  });

  factory SalesOrderItem.fromLoose(String line) {
    // Fallback constructor if we just want to keep the raw line
    return SalesOrderItem(skuName: line, packingName: null, quantity: 0);
  }
}

/// Expected format (from SQL STRING_AGG):
///   "SkuName (PackingName) Qty:10, Another Sku (Pack) Qty:2"
List<SalesOrderItem> _parseProductDetails(String? s) {
  if (s == null || s.trim().isEmpty) return [];
  final parts = s.split(',');
  final re = RegExp(r'^\s*(.+?)\s*(?:\((.*?)\))?\s*Qty\s*:?\s*(\d+)\s*$', caseSensitive: false);
  final items = <SalesOrderItem>[];
  for (final p in parts) {
    final m = re.firstMatch(p.trim());
    if (m != null) {
      final sku = m.group(1)?.trim();
      final pack = m.group(2)?.trim();
      final qty = int.tryParse(m.group(3) ?? '0') ?? 0;
      items.add(SalesOrderItem(skuName: sku, packingName: pack, quantity: qty));
    } else {
      // If regex fails, keep the line as-is (defensive)
      items.add(SalesOrderItem.fromLoose(p.trim()));
    }
  }
  return items;
}
