import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/Model/Product.dart';
import 'api_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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
  final String managerID = '67e98001-1084-48ad-ba98-7d48c440e972';
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
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Place Order'),
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
            icon: const Icon(Icons.info_outline),
            label: const Text('Info'),
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
                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 80),
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
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showOrderSummaryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final cartItems = _products.where((p) => _cart.containsKey(p.skuCode)).toList();

            double grandTotal = 0;
            for (var item in cartItems) {
              final qty = _cart[item.skuCode]!;
              final price = double.tryParse(item.tradePrice) ?? 0;
              grandTotal += qty * price;
            }

            return AlertDialog(
              title: const Text('Order Summary'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.imageUrls.isNotEmpty
                                      ? Image.network(
                                    ApiService.imageBaseUrl + item.imageUrls,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                      : Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 30),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.skuName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Qty: $qty × Rs. ${item.tradePrice}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rs. ${total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Remove Item',
                                      onPressed: () {
                                        setState(() {
                                          _cart.remove(item.skuCode);
                                        });
                                        setStateDialog(() {}); // Refresh popup
                                      },
                                    ),
                                  ],
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: cartItems.isEmpty
                      ? null
                      : () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/salesOrder', arguments: _cart);
                  },
                  child: const Text('Finalize Order'),
                ),
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
