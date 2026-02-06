

// Get tax amount for a single product (with quantity)
double getProductTax(dynamic product) {
  double itemPrice = double.parse(product.tradePrice!);
  int quantity = product.quantity ?? 1;
  double taxAmount = (itemPrice * quantity * (product.taxPercentage ?? 0)) / 100;
  return taxAmount;
}

// Get total price (price + tax) for a single product (with quantity)
double getProductTotal(dynamic product) {
  double itemPrice = double.parse(product.tradePrice!);
  int quantity = product.quantity ?? 1;
  double taxAmount = getProductTax(product);
  return (itemPrice * quantity) + taxAmount;
}

// Get single product price with tax (per unit)
double getProductPriceWithTax(dynamic product) {
  double itemPrice = double.parse(product.tradePrice!);
  int quantity = product.quantity ?? 1;
  double taxAmount = (itemPrice * quantity * (product.taxPercentage ?? 0)) / 100;
  return (itemPrice * quantity) + taxAmount;
}

