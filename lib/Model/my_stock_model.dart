class MyStockModel {
  String? categoryName;
  String? skuName;
  double? stockPOSShopOpening;
  double? stockPOSShopQtyIN;
  double? stockPOSShopQtyOUT;
  double? stockPOSShopBalance;
  double? grandTotal;

  MyStockModel(
      {this.categoryName,
        this.skuName,
        this.stockPOSShopOpening,
        this.stockPOSShopQtyIN,
        this.stockPOSShopQtyOUT,
        this.stockPOSShopBalance,
        this.grandTotal});

  MyStockModel.fromJson(Map<String, dynamic> json) {
    categoryName = json['CategoryName'];
    skuName = json['SkuName'];
    stockPOSShopOpening = json['Stock POS Shop_Opening'];
    stockPOSShopQtyIN = json['Stock POS Shop_QtyIN'];
    stockPOSShopQtyOUT = json['Stock POS Shop_QtyOUT'];
    stockPOSShopBalance = json['Stock POS Shop_Balance'];
    grandTotal = json['GrandTotal'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['CategoryName'] = this.categoryName;
    data['SkuName'] = this.skuName;
    data['Stock POS Shop_Opening'] = this.stockPOSShopOpening;
    data['Stock POS Shop_QtyIN'] = this.stockPOSShopQtyIN;
    data['Stock POS Shop_QtyOUT'] = this.stockPOSShopQtyOUT;
    data['Stock POS Shop_Balance'] = this.stockPOSShopBalance;
    data['GrandTotal'] = this.grandTotal;
    return data;
  }
}