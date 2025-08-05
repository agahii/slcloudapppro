class Product {
  final String id;
  final String defaultPackingID;
  final String skuName;
  final String skuCode;
  final String tradePrice;
  final String categoryName;
  final String imageUrls;
  final String brandName;

  Product({
    required this.id,
    required this.defaultPackingID,
    required this.skuName,
    required this.skuCode,
    required this.tradePrice,
    required this.categoryName,
    required this.imageUrls,
    required this.brandName,
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
    );
  }
}
