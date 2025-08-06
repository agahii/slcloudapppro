class Product {
  final String id;
  final String defaultPackingID;
  final String skuName;
  final String skuCode;
  final String tradePrice;
  final String categoryName;
  final String imageUrls;
  final String brandName;
  final double stockInHand;

  Product({
    required this.id,
    required this.defaultPackingID,
    required this.skuName,
    required this.skuCode,
    required this.tradePrice,
    required this.categoryName,
    required this.imageUrls,
    required this.brandName,
    required this.stockInHand,

  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      defaultPackingID: json['defaultPackingID'],
      skuName: json['skuName'],
      skuCode: json['skuCode'],
      tradePrice: json['tradePrice'],
      categoryName: json['categoryName'],
      imageUrls: json['imageUrls'],
      brandName: json['brandName'],
      stockInHand: (json['stockInHand'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
