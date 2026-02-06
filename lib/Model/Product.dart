class Product {
  String? id;
  String? skuName;
  String? skuCode;
  String? skuNameLocalLanguage;
  String? skuDescription;
  String? tradePrice;
  String? categoryName;
  String? imageUrls;
  String? defaultPackingID;
  String? barCode;
  String? brandName;
  double? stockInHand;
  double? taxPercentage;
  double? futureTaxPercentage;
  int? quantity;
  List<SkuPackingVMPOS>? skuPackingVMPOS;

  Product(
      {this.id,
        this.skuName,
        this.skuCode,
        this.skuNameLocalLanguage,
        this.skuDescription,
        this.tradePrice,
        this.categoryName,
        this.imageUrls,
        this.defaultPackingID,
        this.barCode,
        this.brandName,
        this.stockInHand,
        this.taxPercentage,
        this.futureTaxPercentage,
        this.quantity ,
        this.skuPackingVMPOS});

  Product.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    skuName = json['skuName'];
    skuCode = json['skuCode'];
    skuNameLocalLanguage = json['skuNameLocalLanguage'];
    skuDescription = json['skuDescription'];
    tradePrice = json['tradePrice'];
    categoryName = json['categoryName'];
    imageUrls = json['imageUrls'];
    defaultPackingID = json['defaultPackingID'];
    barCode = json['barCode'];
    brandName = json['brandName'];
    stockInHand = json['stockInHand'];
    taxPercentage = json['taxPercentage'];
    futureTaxPercentage = json['futureTaxPercentage'];
    if (json['skuPackingVMPOS'] != null) {
      skuPackingVMPOS = <SkuPackingVMPOS>[];
      json['skuPackingVMPOS'].forEach((v) {
        skuPackingVMPOS!.add(new SkuPackingVMPOS.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['skuName'] = this.skuName;
    data['skuCode'] = this.skuCode;
    data['skuNameLocalLanguage'] = this.skuNameLocalLanguage;
    data['skuDescription'] = this.skuDescription;
    data['tradePrice'] = this.tradePrice;
    data['categoryName'] = this.categoryName;
    data['imageUrls'] = this.imageUrls;
    data['defaultPackingID'] = this.defaultPackingID;
    data['barCode'] = this.barCode;
    data['brandName'] = this.brandName;
    data['stockInHand'] = this.stockInHand;
    data['taxPercentage'] = this.taxPercentage;
    data['futureTaxPercentage'] = this.futureTaxPercentage;
    if (this.skuPackingVMPOS != null) {
      data['skuPackingVMPOS'] =
          this.skuPackingVMPOS!.map((v) => v.toJson()).toList();
    }
    return data;
  }

  double get price => double.tryParse(tradePrice!) ?? 0.0;
  double get totalPrice => double.parse(tradePrice!) * quantity!;
}

class SkuPackingVMPOS {
  String? packingName;
  String? packingID;
  int? qtyInPack;
  double? salePrice;
  double? taxPercentage;
  double? futureTaxPercentage;

  SkuPackingVMPOS(
      {this.packingName,
        this.packingID,
        this.qtyInPack,
        this.salePrice,
        this.taxPercentage,
        this.futureTaxPercentage});

  SkuPackingVMPOS.fromJson(Map<String, dynamic> json) {
    packingName = json['packingName'];
    packingID = json['packingID'];
    qtyInPack = json['qtyInPack'];
    salePrice = json['salePrice'];
    taxPercentage = json['taxPercentage'];
    futureTaxPercentage = json['futureTaxPercentage'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['packingName'] = this.packingName;
    data['packingID'] = this.packingID;
    data['qtyInPack'] = this.qtyInPack;
    data['salePrice'] = this.salePrice;
    data['taxPercentage'] = this.taxPercentage;
    data['futureTaxPercentage'] = this.futureTaxPercentage;
    return data;
  }
}
