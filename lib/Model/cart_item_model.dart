
import 'Product.dart';

class CartItem {
  final Product product;
  String packing;
  int quantity;
  String expiryDate;

  CartItem({
    required this.product,
    required this.packing,
    required this.quantity,
    required this.expiryDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': product.id,
      'skuCode': product.skuCode,
      'packing': packing,
      'quantity': quantity,
      'expiryDate': expiryDate,
    };
  }
}