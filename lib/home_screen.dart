

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


  Future<void> _showAddToCartSheet(Product product) async {
    final theme = Theme.of(context);
    final double price = double.tryParse(product.tradePrice) ?? 0;
    final int stock = product.stockInHand.round();
    final int initialQty = (_cart[product.skuCode] ?? 0) > 0 ? _cart[product.skuCode]! : 1;

    final qty = ValueNotifier<int>(initialQty);
    final controller = TextEditingController(text: initialQty.toString());

    void syncFromText() {
      final n = int.tryParse(controller.text) ?? 0;
      qty.value = n < 1 ? 1 : n;
      controller
        ..text = qty.value.toString()
        ..selection = TextSelection.collapsed(offset: controller.text.length);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final sheetTheme = theme.copyWith(
          // High-contrast text/icons on white
          iconTheme: const IconThemeData(color: Colors.black87),
          textTheme: theme.textTheme.apply(
            bodyColor: Colors.black87,
            displayColor: Colors.black87,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
          chipTheme: theme.chipTheme.copyWith(
            labelStyle: const TextStyle(color: Colors.black87),
            side: const BorderSide(color: Color(0x1F000000)),
            backgroundColor: const Color(0x0D000000),
            selectedColor: theme.colorScheme.primary.withOpacity(.12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: const BorderSide(color: Colors.black26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        );

        Widget stockChip() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: stock > 0 ? Colors.green.withOpacity(.10) : Colors.red.withOpacity(.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: stock > 0 ? Colors.green : Colors.red),
          ),
          child: Text(
            stock > 0 ? 'Stock: $stock' : 'Out of stock',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: stock > 0 ? Colors.green[800] : Colors.red[800],
            ),
          ),
        );

        // Rounded "pill" stepper for a premium look
        Widget qtyStepper() => ValueListenableBuilder<int>(
          valueListenable: qty,
          builder: (_, v, __) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x11000000)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundIconButton(
                    icon: Icons.remove_rounded,
                    onTap: v > 1
                        ? () {
                      qty.value = v - 1;
                      controller.text = qty.value.toString();
                    }
                        : null,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,     // cleaner inside the pill
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => syncFromText(),
                      onSubmitted: (_) => syncFromText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RoundIconButton(
                    icon: Icons.add_rounded,
                    onTap: () {
                      // if (stock > 0 && v >= stock) return; // optional cap
                      qty.value = v + 1;
                      controller.text = qty.value.toString();
                    },
                  ),
                ],
              ),
            );
          },
        );

        Widget quickChips() {
          final options = [1, 3, 5, 10];
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((n) {
              final selected = int.tryParse(controller.text) == n;
              return ChoiceChip(
                label: Text('$n'),
                selected: selected,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87, // white when selected
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: theme.colorScheme.primary, // solid brand color
                backgroundColor: const Color(0xFFE0E0E0), // light grey when unselected
                onSelected: (_) {
                  qty.value = n;
                  controller.text = '$n';
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selected
                        ? theme.colorScheme.primary
                        : const Color(0x1F000000),
                  ),
                ),
              );
            }).toList(),
          );
        }



        return Theme(
          data: sheetTheme,
          child: Container(
            decoration: BoxDecoration(
              // Subtle “card-in-sheet” look
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 44, height: 5, margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0x22000000),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: product.imageUrls.isNotEmpty
                            ? Image.network(
                          ApiService.imageBaseUrl + product.imageUrls,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 68,
                            height: 68,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        )
                            : Container(
                          width: 68,
                          height: 68,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.skuName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                  color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Rs. ${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                stockChip(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),

                  // Quantity section label + stepper
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_rounded, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Quantity',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color:  Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        qtyStepper(),
                      ],
                    ),
                  ),

                  // Quick chips
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: quickChips()),

                  // Total
                  const SizedBox(height: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: qty,
                    builder: (_, v, __) => Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                        child: Text(
                          'Total: Rs. ${(v * price).toStringAsFixed(2)}',
                          key: ValueKey(v),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),

                  // Actions
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: qty,
                          builder: (_, v, __) {
                            final canAdd = v >= 1 && (stock == 0 ? true : v <= stock);
                            return ElevatedButton(
                              onPressed: canAdd
                                  ? () {
                                setState(() => _cart[product.skuCode] = v);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${product.skuName} • qty $v added')),
                                );
                              }
                                  : null,
                              child: const Text('Add to Cart'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },

    );
  }





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
        await _showAddToCartSheet(product);
        return false; // don’t actually dismiss the tile
      },

      child: _productCard(product),
    );
  }
  Widget _productCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
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
                  child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
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
                child: const Icon(Icons.image, size: 30, color: Colors.grey),
              ),
            ),

            const SizedBox(width: 14),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    product.skuName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFamily: 'Roboto', // modern clean font
                      letterSpacing: 0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Brand
                  Text(
                    'Brand: ${product.brandName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Price + Stock Row
                  Row(
                    children: [
                      Text(
                        'Rs. ${product.tradePrice}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontFamily: 'RobotoMono', // monospace for numbers
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: product.stockInHand > 0
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
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
        backgroundColor: Colors.white, // solid background
        surfaceTintColor: Colors.white,
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
              leading: Icon(Icons.account_balance_wallet, color: theme.primaryColor),
              title: Text(
                'Customer Ledger',
                style: TextStyle(color: theme.primaryColor),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/customerLedger');
              },
            ),

            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: theme.primaryColor),
              title: Text(
                'My Sales Orders',
                style: TextStyle(color: theme.primaryColor),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/mySalesOrders');
              },
            ),

            ListTile(
              leading: Icon(Icons.policy, color: theme.primaryColor),
              title: Text(
                'Active Policy',
                style: TextStyle(color: theme.primaryColor),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/activePolicy');
              },
            ),

            ListTile(
              leading: Icon(Icons.money, color: theme.primaryColor),
              title: Text(
                'My Expenses',
                style: TextStyle(color: theme.primaryColor),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/myExpenses');
              },
            ),

            const Divider(),

            ListTile(
              leading: Icon(Icons.logout, color: theme.primaryColor),
              title: Text(
                'Logout',
                style: TextStyle(color: theme.primaryColor),
              ),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      )
      ,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.black87),          // make typed text visible
              cursorColor: Colors.black54,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: const TextStyle(color: Colors.black45),    // visible hint
                filled: true,
                fillColor: Colors.white,                               // solid light background
                prefixIcon: isLoading
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black54), // visible spinner
                    ),
                  ),
                )
                    : const Icon(Icons.search, color: Colors.black54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black54),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor), // brand color on focus
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
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
          )
          ,
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
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFEAECEF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x11000000)),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 20, color: enabled ? Colors.black87 : Colors.black26),
      ),
    );
  }
}
