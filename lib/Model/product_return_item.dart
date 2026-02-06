

import 'Product.dart';

/// Wrapper class to hold Product with return-specific data
class ProductReturnItem {
  final Product product;
  int returnQuantity;
  bool isSelected;

  ProductReturnItem({
    required this.product,
    this.returnQuantity = 0,
    this.isSelected = false,
  });

  /// Get the maximum quantity that can be returned (from original order)
  int get maxQuantity => product.quantity ?? 1;

  /// Get the product price
  double get price => product.price;

  /// Get the total return amount for this item
  double get totalReturnAmount => price * returnQuantity;

  /// Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'skuCode': product.skuCode,
      'returnQuantity': returnQuantity,
      'returnAmount': totalReturnAmount,
    };
  }
}