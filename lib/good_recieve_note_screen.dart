import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:slcloudapppro/Model/Product.dart';
import 'package:slcloudapppro/theme/app_colors.dart';
import 'package:slcloudapppro/utils/barcode_scanner_page.dart';

import 'Model/customer.dart';
import 'api_service.dart';

/*
class ApiException implements Exception {
  final int code;
  final String message;
  ApiException(this.code, this.message);
}

Future<bool> hasInternetConnection() async {
  // Implement actual connectivity check here
  return true;
}

Future<http.Response> _post(Uri url,
    {required Map<String, String> headers, required String body}) async {
  return await http.post(url, headers: headers, body: body);
}

const String baseUrl = 'https://yourapi.baseurl.com';

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

class ApiService {
  static Future<List<Product>> fetchProductsFromOrderManager({
    required String managerID,
    required String stockLocationID,
    int page = 1,
    int pageSize = 20,
    String searchKey = "",
    String barcode = "",
  }) async {
    if (!await hasInternetConnection()) {
      throw ApiException(0, 'No internet connection.');
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw ApiException(401, 'Token not found. Please login again.');
    }
    final url = Uri.parse('$baseUrl/api/PurchaseSalesOrderMaster/GetSKUPOS');
    final payload = {
      "managerID": managerID,
      "searchKey": searchKey,
      "barCode": barcode,
      "categoryID": "",
      "pageNumber": page,
      "pageSize": pageSize,
      "stockLocationID": stockLocationID
    };

    final response = await _post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List skuList = data['data']['skuVMPOS'];
      return skuList.map((item) => Product.fromJson(item)).toList();
    } else {
      throw ApiException(response.statusCode, 'Failed to fetch products.');
    }
  }
}
*/

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

class PurchaseFormPage extends StatefulWidget {
  const PurchaseFormPage({Key? key}) : super(key: key);

  @override
  _PurchaseFormPageState createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends State<PurchaseFormPage> {
  final _formKey = GlobalKey<FormState>();

  List<String> vendors = ['THE FLEX SHOP (MALIK SAFDAR DGK)(100010)'];
  String? selectedVendor;

  String managerID = '';
  String stockLocationId = '';
  String _invoiceMgrId = '';

  TextEditingController searchController = TextEditingController();
  TextEditingController barcodeController = TextEditingController();
  TextEditingController notesController = TextEditingController();
   TextEditingController addressController = TextEditingController();

  final List<String> packingOptions = ['Piece', 'Kg', 'Box'];

  List<Product> _products = [];
  List<CartItem> _cartItems = [];

  bool isLoading = false;
  int currentPage = 1;
  int pageSize = 20;
  bool hasMore = true;

  String searchKey = '';
  String barcode = '';
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    selectedVendor = vendors.first;
    loadManagerInfo();

  }

  Future<void> loadManagerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    managerID =
        prefs.getString('salesPurchaseOrderManagerID')?.trim() ?? '';
    _invoiceMgrId = prefs.getString('invoiceManagerID')?.trim() ?? '';
    stockLocationId = prefs.getString('stockLocationID')?.trim() ?? '';
    if(managerID.isNotEmpty || stockLocationId.isNotEmpty){
      fetchProducts();
    }
  }

  Future<void> fetchProducts({bool reset = true} ) async {
    if (reset) {
      setState(() {
        currentPage = 1;
        hasMore = true;
        _products.clear();
      });
    }
    if (!hasMore) return;
    setState(() => isLoading = true);
    try {
      final List<Product> newProducts = await ApiService.fetchProductsFromOrderManager(
        managerID: managerID,
        stockLocationID: stockLocationId,
        page: currentPage,
        pageSize: pageSize,
        searchKey: searchKey,
        barcode: barcode,
      );
      setState(() {
        currentPage++;
        _products.addAll(newProducts);
        if (newProducts.length < pageSize) hasMore = false;
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
    setState(() => isLoading = false);
  }

  void _toggleCart(Product product) {
    final idx = _cartItems.indexWhere((item) => item.product.skuCode == product.skuCode);
    if (idx >= 0) {
      setState(() {
        _cartItems.removeAt(idx);
      });
    } else {
      setState(() {
        _cartItems.add(CartItem(
          product: product,
          packing: product.defaultPackingID,
          quantity: 1,
          expiryDate: '',
        ));
      });
    }
  }

  void _updateCartItemQty(String skuCode, int newQty) {
    setState(() {
      final item = _cartItems.firstWhere((item) => item.product.skuCode == skuCode);
      item.quantity = newQty;
    });
  }

  void _updateCartItemPacking(String skuCode, String newPacking) {
    setState(() {
      final item = _cartItems.firstWhere((item) => item.product.skuCode == skuCode);
      item.packing = newPacking;
    });
  }

  void _updateCartItemExpiry(String skuCode, String newExpiry) {
    setState(() {
      final item = _cartItems.firstWhere((item) => item.product.skuCode == skuCode);
      item.expiryDate = newExpiry;
    });
  }

  Future<void> _pickExpiryDate(String skuCode) async {
    DateTime today = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 10),
    );
    if (picked != null) {
      final formatted = '${picked.month}/${picked.day}/${picked.year}';
      _updateCartItemExpiry(skuCode, formatted);
    }
  }

  void _removeCartItem(String skuCode) {
    setState(() {
      _cartItems.removeWhere((item) => item.product.skuCode == skuCode);
    });
  }

  void _showCartDialog() {
    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: AppColors.g1,
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.g1,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                children: [
                  Text(
                    "🛒 Items (${_cartItems.length})",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _cartItems.isEmpty
                        ? const Center(child: Text("Cart is empty."))
                        : ListView.builder(
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        return _OrderItemTile(
                          item: item,
                          onQtyChanged: (newQty) {
                            if (newQty < 1) return;
                            setStateDialog(() {
                              _updateCartItemQty(item.product.skuCode, newQty);
                            });
                          },
                          onPackingChanged: (newPacking) {
                            setStateDialog(() {
                              _updateCartItemPacking(item.product.skuCode, newPacking);
                            });
                          },
                          onExpiryChanged: () async {
                            await _pickExpiryDate(item.product.skuCode);
                            setStateDialog(() {});
                          },
                          onRemove: () {
                            setState(() {
                              _removeCartItem(item.product.skuCode);
                            });
                            setStateDialog(() {});
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _submit();
                      },
                      child: const Text('Submit Selected'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? true) {
      print('Vendor: $selectedVendor');
      print('Notes: ${notesController.text}');
      for (var item in _cartItems) {
        print(
            'SKU: ${item.product.skuCode}, Packing: ${item.packing}, Qty: ${item.quantity}, Expiry: ${item.expiryDate}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted successfully')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please fix form errors')));
    }
  }

  Widget _productCard(Product product) {
    final isSelected = _cartItems.any((item) => item.product.skuCode == product.skuCode);

    return GestureDetector(
      onTap: () => _toggleCart(product),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: isSelected ? 8 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected ? Colors.blue : AppColors.surface,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: product.imageUrls.isNotEmpty
                    ? Image.network(
                  ApiService.imageBaseUrl + product.imageUrls,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.broken_image,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                )
                    : Container(
                  width: 90,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.image,
                    size: 30,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.skuName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: 'Roboto',
                        letterSpacing: 0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Brand: ${product.brandName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Rs. ${product.tradePrice}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontFamily: 'RobotoMono',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.stockInHand > 0
                                ? Colors.orange.withAlpha(25)
                                : Colors.red.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: product.stockInHand > 0 ? Colors.orange : Colors.red,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            product.stockInHand > 0
                                ? 'Stock: ${product.stockInHand.toStringAsFixed(0)}'
                                : 'Out of stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: product.stockInHand > 0 ? Colors.orange[800] : Colors.red[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.blue : Colors.grey,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _OrderItemTile({
    required CartItem item,
    required ValueChanged<int> onQtyChanged,
    required ValueChanged<String> onPackingChanged,
    required VoidCallback onExpiryChanged,
    required VoidCallback onRemove,
  }) {
    final price = double.tryParse(item.product.tradePrice) ?? 0;
    final total = price * item.quantity;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: AppColors.g2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.product.imageUrls.isNotEmpty
                      ? Image.network(
                    item.product.imageUrls,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.product.skuName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        'Rs. ${price.toStringAsFixed(2)} × ${item.quantity}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      _QtyPillStepper(
                        value: item.quantity,
                        onChanged: onQtyChanged,
                        primary: AppColors.onSurface,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rs. ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      splashRadius: 16,
                      onPressed: onRemove,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Packing',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    initialValue:  packingOptions.contains(item.packing) ? item.packing : null,
                    items: packingOptions.toSet().toList().map((pack) =>  // Ensure unique items
                    DropdownMenuItem(value: pack, child: Text(pack))
                    ).toList(),
                    onChanged: (val) => onPackingChanged(val ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onExpiryChanged,
                    child: IgnorePointer(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Expiry Date',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        controller: TextEditingController(text: item.expiryDate),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _QtyPillStepper({
    required int value,
    required ValueChanged<int> onChanged,
    required Color primary,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onChanged(value - 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(Icons.remove, size: 18, color: primary),
            ),
          ),
          Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(minWidth: 24),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('$value', style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
          ),
          InkWell(
            onTap: () => onChanged(value + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(Icons.add, size: 18, color: primary),
            ),
          ),
        ],
      ),
    );
  }

  void scanBarcodeAndFetchProduct() async {
    String result = await BarcodeScannerService.scanBarcode();
    if (!mounted) return;
    setState(() {
      barcode = result;
      searchController.text = barcode;
    });

    if (result.isNotEmpty) {
      fetchProducts();
    }
  }



  @override
  Widget build(BuildContext context) {
    final cartCount = _cartItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Good Receive Note'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: cartCount > 0 ? _showCartDialog : null,
              ),
              if (cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownSearch<Customer>(
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        isFilterOnline: true,
                        searchFieldProps: const TextFieldProps(
                          decoration: InputDecoration(
                            hintText: "🔍 Search customer...",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        itemBuilder:
                            (context, Customer customer, isSelected) =>
                            ListTile(
                              title: Text(customer.customerName),
                              subtitle: Text(customer.customerAddress),
                            ),
                      ),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: "Select Customer",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      asyncItems: (String filter) async {
                        if (filter.length < 3) return [];
                        return await ApiService.fetchVander(
                          _invoiceMgrId,
                          filter,
                        );
                      },
                      itemAsString: (Customer u) => u.customerName,
                      selectedItem: _selectedCustomer,
                      onChanged: (Customer? customer) {
                        setState(() {
                          _selectedCustomer = customer;
                          addressController.text =
                              customer?.customerAddress ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: 'Search by SKU or Brand',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                searchKey = '';
                                currentPage = 1;
                                barcode= '';
                                _products.clear();
                                hasMore = true;
                              });
                              fetchProducts();
                            },
                          )
                              : null,
                        ),
                        onChanged: (val) {
                          searchKey = val;
                          fetchProducts(reset: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        /*barcode = ''; // or open barcode scanner to set this
                        fetchProducts(reset: true);*/
                        scanBarcodeAndFetchProduct();
                      },
                      child: const Icon(Icons.qr_code_scanner),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading && _products.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (_, i) {
                    final product = _products[i];
                    return _productCard(product);
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton(
                    onPressed: cartCount > 0 ? _showCartDialog : null,
                    child: const Text('View Cart & Submit'),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
