import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/Model/Product.dart';
import 'api_service.dart';
import 'dart:async';
import 'package:slcloudapppro/Model/customer.dart';
import 'package:dropdown_search/dropdown_search.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {






  Customer? _selectedCustomer;
  Offset fabOffset = const Offset(20, 500);
  Timer? _debounce;
  final Map<String, int> _cart = {};
  final TextEditingController _searchController = TextEditingController();
  String searchKey = "";
  String firstName = '';
  String lastName = '';
  final ScrollController _scrollController = ScrollController();
  final List<Product> _products = [];
  bool isLoading = false;
  int currentPage = 1;
  bool hasMore = true;
  final int pageSize = 20;
  final String managerID = '59ed026d-1764-4616-9387-6ab6676b6667';


  bool isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
    fetchProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
          !isLoading &&
          hasMore) {
        fetchProducts();
      }
    });
    _searchController.addListener(() {
      setState(() {});
    });
  }
  Future<void> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        firstName = prefs.getString('firstName') ?? '';
        lastName = prefs.getString('lastName') ?? '';
      });
    } catch (e) {
      debugPrint('Error loading user data: \$e');
    }
  }
  Future<void> fetchProducts() async {
    setState(() => isLoading = true);
    try {
      final newProducts = await ApiService.fetchProducts(
        managerID: managerID,
        page: currentPage,
        pageSize: pageSize,
        searchKey: searchKey,
      );
      setState(() {
        currentPage++;
        _products.addAll(newProducts);
        if (newProducts.length < pageSize) hasMore = false;
      });
    } catch (e) {
      print('Error loading products: \$e');
    }
    setState(() => isLoading = false);
  }
  Future<void> _clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cart?'),
        content: const Text('Are you sure you want to remove all items from the cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _cart.clear();
      });
    }
  }
  Widget _fabButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isFabExpanded) ...[
          FloatingActionButton.extended(
            heroTag: 'placeOrder',
            backgroundColor: Colors.red,
            onPressed: () {
              if (_cart.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cart is empty')),
                );
              } else {
                _showOrderSummaryDialog();
              }
            },
            icon: const Icon(Icons.shopping_bag, color: Colors.white),
            label: const Text('Place Order',
                style: TextStyle(color: Colors.white)),


          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'anotherAction',
            backgroundColor: Colors.red,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Another Action Clicked')),
              );
            },
            icon: const Icon(Icons.info_outline, color: Colors.white),
            label: const Text('Info',
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          backgroundColor: Colors.red,
          onPressed: () {
            setState(() => isFabExpanded = !isFabExpanded);
          },
          child: Icon(
            isFabExpanded ? Icons.close : Icons.menu,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  Widget _buildExpandableFAB() {
    return Positioned(
      left: fabOffset.dx,
      top: fabOffset.dy,
      child: Draggable(
        feedback: Material(
          color: Colors.transparent,
          child: _fabButtons(),
        ),
        childWhenDragging: const SizedBox.shrink(),
        onDraggableCanceled: (_, offset) {
          setState(() => fabOffset = offset);
        },
        child: _fabButtons(),
      ),
    );
  }
  Widget _buildProductItem(Product product) {
    final TextEditingController _qtyController = TextEditingController(text: '1');
    return Dismissible(
      key: ValueKey(product.skuCode),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: Colors.green[100],
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.shopping_cart, color: Colors.green, size: 30),
      ),
      confirmDismiss: (_) async {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(product.skuName),
            content: Row(
              children: [
                const Text('Qty: '),
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Enter quantity'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final qty = int.tryParse(_qtyController.text);
                  if (qty != null && qty > 0) {
                    setState(() {
                      _cart[product.skuCode] = qty;
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Add to Cart'),
              ),
            ],
          ),
        );
        return false;
      },
      child: _productCard(product),
    );
  }
  Widget _productCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product.imageUrls.isNotEmpty
                  ? Image.network(
                ApiService.imageBaseUrl + product.imageUrls,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported, size: 80),
              )
                  : Container(
                width: 80,
                height: 80,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 40),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.skuName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('Brand: ${product.brandName}', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    'Rs. ${product.tradePrice}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${product.stockInHand.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: product.stockInHand > 0 ? Colors.orange : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showOrderSummaryDialog() {
    String dialogTitle = '🧾 Order Summary';
    TextEditingController addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final cartItems = _products.where((p) => _cart.containsKey(p.skuCode)).toList();
            bool isSubmitting = false;
            double grandTotal = 0;
            for (var item in cartItems) {
              final qty = _cart[item.skuCode]!;
              final price = double.tryParse(item.tradePrice) ?? 0;
              grandTotal += qty * price;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              content: SizedBox(
                width: double.maxFinite,
                height: 600,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("👤 Customer", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownSearch<Customer>(
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        isFilterOnline: true,
                        searchFieldProps: TextFieldProps(
                          decoration: const InputDecoration(hintText: "🔍 Search customer...", border: OutlineInputBorder()),
                        ),
                        itemBuilder: (context, Customer customer, isSelected) => ListTile(
                          title: Text(customer.customerName),
                          subtitle: Text(customer.customerAddress),
                        ),
                      ),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(labelText: "Select Customer", border: OutlineInputBorder()),
                      ),
                      asyncItems: (String filter) async {
                        if (filter.length < 3) return [];
                        return await ApiService.fetchCustomers(managerID, filter);
                      },
                      itemAsString: (Customer u) => u.customerName,
                      selectedItem: _selectedCustomer,
                      onChanged: (Customer? customer) {
                        setStateDialog(() {
                          _selectedCustomer = customer;
                          addressController.text = customer?.customerAddress ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text("🏠 Delivery Address", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: "Enter delivery address",
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const Text("🛒 Items", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: cartItems.isEmpty
                          ? const Center(child: Text("Cart is empty."))
                          : ListView.builder(
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final qty = _cart[item.skuCode]!;
                          final price = double.tryParse(item.tradePrice) ?? 0;
                          final total = qty * price;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child:

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.imageUrls.isNotEmpty
                                      ? Image.network(
                                    ApiService.imageBaseUrl + item.imageUrls,
                                    width: 45,
                                    height: 45,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 45,
                                      height: 45,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image_not_supported, size: 20),
                                    ),
                                  )
                                      : Container(
                                    width: 45,
                                    height: 45,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 20),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Text + Qty + Total
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.skuName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Rs. ${item.tradePrice} each',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 6),

                                      // Qty controls and total
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              // - button
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: qty > 1
                                                    ? () {
                                                  setStateDialog(() {
                                                    _cart[item.skuCode] = qty - 1;
                                                  });
                                                }
                                                    : null,
                                              ),

                                              // Qty
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                child: Text(
                                                  '$qty',
                                                  style: const TextStyle(fontSize: 13),
                                                ),
                                              ),

                                              // + button
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  setStateDialog(() {
                                                    _cart[item.skuCode] = qty + 1;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 4),

                                          // Rs. Total aligned right
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              'Rs. ${total.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                    ],
                                  ),
                                ),

                                // Delete Icon
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _cart.remove(item.skuCode);
                                    });
                                    setStateDialog(() {});
                                  },
                                ),
                              ],
                            ),

                          );

                        },
                      ),
                    ),

                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Grand Total: Rs. ${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: cartItems.isEmpty || _selectedCustomer == null || isSubmitting
                      ? null
                      : () async {
                    setStateDialog(() => isSubmitting = true); // 🔒 Disable further clicks

                    final prefs = await SharedPreferences.getInstance();
                    final _employeeID = prefs.getString('employeeID');

                    final payload = {
                      "fK_Customer_ID": _selectedCustomer!.id,
                      "fK_Employee_ID": _employeeID,
                      "deliveryAddress": addressController.text,
                      "isBankGuarantee": false,
                      "isClosed": false,
                      "fK_PurchaseSalesOrderManagerMaster_ID": managerID,
                      "docDate": DateTime.now().toIso8601String(),
                      "expectedDelRecDate": null,
                      "bankGuaranteeIssueDate": null,
                      "bankGuaranteeExpiryDate": null,
                      "proformaInvoiceDate": null,
                      "lcReceived": false,
                      "transShipmentAllow": false,
                      "purchaseSalesOrderDetailsInp": cartItems.map((item) {
                        final qty = _cart[item.skuCode]!;
                        final rate = double.tryParse(item.tradePrice) ?? 0;
                        return {
                          "id": "",
                          "fK_ChartOfAccounts_ID": null,
                          "fK_Sku_ID": item.id,
                          "fK_SKUPacking_ID": item.defaultPackingID,
                          "quantity": qty,
                          "agreedRate": rate,
                          "totalAmount": qty * rate,
                          "totalAmountInLocalCurrency": 0,
                          "specialInstruction": "",
                          "skuName": "",
                          "packingName": "",
                        };
                      }).toList(),
                      "purchaseSalesOrderShipmentDetailsInp": [],
                    };

                    try {
                      final response = await ApiService.finalizeSalesOrder(payload);
                      if (response.statusCode == 200 || response.statusCode == 201) {
                        setState(() => _cart.clear());
                        setStateDialog(() => dialogTitle = '✅ Order placed successfully!');
                      } else {
                        setStateDialog(() => dialogTitle = '❌ Failed: ${response.statusCode}');
                      }
                    } catch (e) {
                      setStateDialog(() => dialogTitle = '⚠️ Error: $e');
                    }

                    await Future.delayed(const Duration(seconds: 3));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('📝 Finalize Order'),
                )


              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear Cart',
            onPressed: _cart.isNotEmpty ? _clearCart : null,
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {},
              ),
              if (_cart.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      '${_cart.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: theme.primaryColor),
              accountName: Text('$firstName $lastName'),
              accountEmail: const Text(''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  firstName.isNotEmpty ? firstName[0] : '',
                  style: TextStyle(fontSize: 40, color: theme.primaryColor),
                ),
              ),
            ),


            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Customer Ledger'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/customerLedger');
              },
            ),
            ListTile(
              leading: const Icon(Icons.policy),
              title: const Text('Active Policy'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/activePolicy');
              },
            ),
            ListTile(
              leading: const Icon(Icons.money),
              title: const Text('My Expenses'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/myExpenses');
              },
            ),
            const Divider(),

            ListTile(
              leading: Icon(Icons.logout, color: theme.iconTheme.color),
              title: const Text('Logout'),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: isLoading
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      searchKey = '';
                      currentPage = 1;
                      _products.clear();
                      hasMore = true;
                    });
                    fetchProducts();
                  },
                )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  setState(() {
                    searchKey = value.trim();
                    currentPage = 1;
                    _products.clear();
                    hasMore = true;
                  });
                  fetchProducts();
                });
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: _products.isEmpty
                ? Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('No products found.'),
            )
                : ListView.builder(
              controller: _scrollController,
              itemCount: _products.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _products.length) {
                  return _buildProductItem(_products[index]);
                } else {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Stack(children: [_buildExpandableFAB()]),
    );
  }
}
