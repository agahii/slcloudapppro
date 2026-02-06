import '../Model/Product.dart';

/// Utility class to parse invoice items from API response
class InvoiceItemsParser {
  /// Parse itemsList string to List<Product>
  ///
  /// Example input:
  /// "Beauty Voc Face Wash (Single Piece) Qty:1.00 Rate:5.00 Amount:5.00,
  ///  Daari Mooch Hair Wax (Single Piece) Qty:1.00 Rate:750.00 Amount:750.00"
  ///
  static List<Product> parseItemsList(String itemsList) {
    if (itemsList.isEmpty) return [];

    List<Product> products = [];

    // Split by comma to get individual items
    List<String> items = itemsList.split(',').map((e) => e.trim()).toList();

    for (int i = 0; i < items.length; i++) {
      try {
        Product? product = _parseSingleItem(items[i], i);
        if (product != null) {
          products.add(product);
        }
      } catch (e) {
        print('Error parsing item: ${items[i]}, Error: $e');
        // Continue with next item even if one fails
      }
    }

    return products;
  }

  /// Parse a single item string to Product object
  static Product? _parseSingleItem(String itemString, int index) {
    if (itemString.isEmpty) return null;

    // Regular expressions to extract data
    final qtyRegex = RegExp(r'Qty:(\d+\.?\d*)');
    final rateRegex = RegExp(r'Rate:(\d+\.?\d*)');
    final amountRegex = RegExp(r'Amount:(\d+\.?\d*)');

    // Extract quantity, rate, and amount
    final qtyMatch = qtyRegex.firstMatch(itemString);
    final rateMatch = rateRegex.firstMatch(itemString);
    final amountMatch = amountRegex.firstMatch(itemString);

    if (qtyMatch == null || rateMatch == null) {
      return null; // Invalid item format
    }

    final quantity = double.tryParse(qtyMatch.group(1) ?? '0')?.toInt() ?? 0;
    final rate = rateMatch.group(1) ?? '0';

    // Extract product name (everything before "Qty:")
    final nameEndIndex = itemString.indexOf('Qty:');
    String productName = nameEndIndex > 0
        ? itemString.substring(0, nameEndIndex).trim()
        : 'Unknown Product';

    // Remove packaging info in parentheses for SKU generation
    String skuBase = productName.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    skuBase = skuBase.replaceAll(RegExp(r'\s+'), '-').toUpperCase();

    return Product(
      id: 'item_$index', // Generate temporary ID
      skuName: productName,
      skuCode: skuBase.isEmpty ? 'SKU-$index' : skuBase,
      skuNameLocalLanguage: productName,
      tradePrice: rate,
      quantity: quantity,
      stockInHand: quantity.toDouble(),
      taxPercentage: 0.0,
      futureTaxPercentage: 0.0,
    );
  }

  /// Parse complete invoice response to extract items
  static List<Product> parseFromInvoiceResponse(Map<String, dynamic> invoiceData) {
    final itemsList = invoiceData['itemsList'] as String? ?? '';
    return parseItemsList(itemsList);
  }
}

/// Extension method for easier parsing
extension InvoiceDataExtension on Map<String, dynamic> {
  /// Get parsed product list from invoice data
  List<Product> getProductsList() {
    return InvoiceItemsParser.parseFromInvoiceResponse(this);
  }

  /// Get invoice number for display
  String getInvoiceNumber() {
    final docNumber = this['docNumber'];
    return '#INV-${docNumber ?? 'UNKNOWN'}';
  }
}