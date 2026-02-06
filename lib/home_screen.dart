import 'dart:convert'; // ⬅️ add this

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/Model/Product.dart';
import 'package:slcloudapppro/print_invoice.dart';
import 'package:slcloudapppro/theme/app_colors.dart';
import 'package:slcloudapppro/utils/barcode_scanner_page.dart';
import 'api_service.dart';
import 'dart:async';
import 'package:slcloudapppro/Model/customer.dart';
import 'package:dropdown_search/dropdown_search.dart';

import 'check_out_screen.dart';
enum OrderAction { placeOrder, salesInvoice }
enum ManagerSource { salesOrder, invoice }
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {


  String _salesOrderMgrId = '';
  String _stockLocationId = '';
  String _invoiceMgrId = '';
  ManagerSource? _managerSource; // Currently selected manager source
  bool _showManagerSwitch = false;

  Customer? _selectedCustomer;
  Offset fabOffset = const Offset(20, 500);
  Timer? _debounce;
  final Map<String, int> _cart = {};
  final TextEditingController _searchController = TextEditingController();
  String searchKey = "";
  String barcode = "";
  String firstName = '';
  String lastName = '';
  final ScrollController _scrollController = ScrollController();
  final List<Product> _products = [];
  bool isLoading = false;
  int currentPage = 1;
  bool hasMore = true;
  final int pageSize = 20;
  // final String managerIDSalesOrder = '';
  // final String managerIDSalesInvoice = '';
  bool isFabExpanded = false;
  late String actionLabel ;
  late OrderAction actionType= OrderAction.placeOrder;
  late List<Map<String, dynamic>> fbrScenario = [];


  Future<void> fbrList() async {
    fbrScenario = await _loadFbrFromPrefs();
  }

  Future<List<Map<String, dynamic>>> _loadFbrFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final fbrString = prefs.getString('allowedFbrScenario');
    if (fbrString == null) return [];
    final List<dynamic> fbrList = jsonDecode(fbrString);
    return fbrList.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void scanBarcodeAndFetchProduct() async {
    String result = await BarcodeScannerService.scanBarcode();
    if (!mounted) return;
    setState(() {
      barcode = result;
      _searchController.text = barcode;
    });

    if (result.isNotEmpty) {
      fetchProducts();
    }
  }


  Future<void> _showAddToCartSheet(Product product) async {
    final theme = Theme.of(context);
    final double price = double.tryParse(product.tradePrice!) ?? 0;
    final int stock = product.stockInHand!.round();
    final int initialQty = (_cart[product.skuCode] ?? 0) > 0 ? _cart[product.skuCode]! : 1;

    final qty = ValueNotifier<int>(initialQty);
    final controller = TextEditingController(text: initialQty.toString());

    // Discount controllers
    final discountPercentController = TextEditingController(text: '0');
    final discountAmountController = TextEditingController(text: '0.00');
    final discountPercent = ValueNotifier<double>(0);
    final discountAmount = ValueNotifier<double>(0);

    void syncFromText() {
      final n = int.tryParse(controller.text) ?? 0;
      qty.value = n < 1 ? 1 : n;
      controller
        ..text = qty.value.toString()
        ..selection = TextSelection.collapsed(offset: controller.text.length);
    }

    void updateDiscountFromPercent() {
      final percent = double.tryParse(discountPercentController.text) ?? 0;
      discountPercent.value = percent.clamp(0, 100);
      final subtotal = qty.value * price;
      discountAmount.value = (subtotal * discountPercent.value / 100);
      discountAmountController.text = discountAmount.value.toStringAsFixed(2);
    }

    void updateDiscountFromAmount() {
      final amount = double.tryParse(discountAmountController.text) ?? 0;
      final subtotal = qty.value * price;
      discountAmount.value = amount.clamp(0, subtotal);
      discountPercent.value = subtotal > 0 ? (discountAmount.value / subtotal * 100) : 0;
      discountPercentController.text = discountPercent.value.toStringAsFixed(0);
      discountAmountController.text = discountAmount.value.toStringAsFixed(2);
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
        Widget stockChip() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Stock: $stock',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00A86B),
            ),
          ),
        );

        Widget qtyStepper() => ValueListenableBuilder<int>(
          valueListenable: qty,
          builder: (_, v, __) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: v > 1
                        ? () {
                      qty.value = v - 1;
                      controller.text = qty.value.toString();
                      updateDiscountFromPercent();
                    }
                    : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.remove,
                        size: 18,
                        color: v > 1 ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) {
                        syncFromText();
                        updateDiscountFromPercent();
                      },
                      onSubmitted: (_) {
                        syncFromText();
                        updateDiscountFromPercent();
                      },
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      qty.value = v + 1;
                      controller.text = qty.value.toString();
                      updateDiscountFromPercent();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );

        Widget quickChips() {
          final options = [1, 3, 5, 10, 25,50,100];
          return Wrap(
          direction: Axis.horizontal,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 8,
            runSpacing: 8,
            children: options.map((n) {
              return ValueListenableBuilder<int>(
                valueListenable: qty,
                builder: (_, v, __) {
                  final selected = v == n;
                  return InkWell(
                    onTap: () {
                      qty.value = n;
                      controller.text = '$n';
                      updateDiscountFromPercent();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.mainButtonsColor : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? AppColors.mainButtonsColor : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        }

        return Container(
          //height: MediaQuery.of(context).size.height * 0.50,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    alignment: Alignment.center,
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.greyColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header row with image and product info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: product.imageUrls!.isNotEmpty
                          ? Image.network(
                        ApiService.imageBaseUrl + product.imageUrls!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                          : Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.skuName!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Rs. ${price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.priceGreenColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (stock > 0) stockChip(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Divider(height: 1,color: AppColors.appBackgroundGreyColor,),

                const SizedBox(height: 20),
                // Quantity section
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_rounded,
                      size: 25,
                      color: AppColors.mainButtonsColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    qtyStepper(),
                  ],
                ),

                const SizedBox(height: 30),
                // Quick quantity chips
                quickChips(),
                const SizedBox(height: 40),
                // Discount section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discount (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: discountPercentController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: Colors.black, // typed text color
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              prefixText: '% ',
                              hintText: '0',
                              prefixStyle:  TextStyle(
                                color: AppColors.greyColor,
                              ),
                              hintStyle: TextStyle(
                                color: AppColors.greyColor,
                              ),
                              filled: true,
                              fillColor: AppColors.whiteColor,
                              // Default border
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.borderGreyColor, width: 0.5),
                              ),

                              // When enabled but not focused
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.greyColor, width: 0.5),
                              ),

                              // When focused (clicked)
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.mainButtonsColor, width: 2),
                              ),

                              // When error
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.red, width: 2),
                              ),

                              // When error + focused
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.red, width: 2),
                              ),

                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            onChanged: (_) => updateDiscountFromPercent(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: discountAmountController,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                            style: TextStyle(
                              color: Colors.black, // typed text color
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              labelStyle: TextStyle(
                                color: AppColors.blackColor
                              ),
                              prefixText: 'Rs ',
                              hintText: '0.00',
                              prefixStyle:  TextStyle(
                                color: AppColors.greyColor,
                              ),
                              hintStyle: TextStyle(
                                color: AppColors.greyColor,
                              ),
                              filled: true,
                              fillColor: AppColors.whiteColor,
                              // Default border
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.borderGreyColor, width: 0.5),
                              ),

                              // When enabled but not focused
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.greyColor, width: 0.5),
                              ),

                              // When focused (clicked)
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.mainButtonsColor, width: 2),
                              ),

                              // When error
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.red, width: 2),
                              ),

                              // When error + focused
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.red, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            onChanged: (_) => updateDiscountFromAmount(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 30),


                // Total amount
                ValueListenableBuilder<int>(
                  valueListenable: qty,
                  builder: (_, v, __) {
                    return ValueListenableBuilder<double>(
                      valueListenable: discountAmount,
                      builder: (_, discount, __) {
                        final subtotal = v * price;
                        final total = subtotal - discount;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              'Rs. ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ValueListenableBuilder<int>(
                        valueListenable: qty,
                        builder: (_, v, __) {
                          final canAdd = v >= 1 && (stock == 0 ? true : v <= stock);
                          return ElevatedButton.icon(
                            onPressed: canAdd
                                ? () {
                              setState(() {
                                _cart[product.skuCode!] = v;
                                product.quantity = v;
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product.skuName} • qty $v added'),
                                ),
                              );
                            }
                            : null,
                            icon: const Icon(Icons.shopping_cart, size: 18),
                            label: const Text(
                              'Add to Cart',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mainButtonsColor,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[500],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),



              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initManagersAndFirstLoad();
    fbrList();
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
  Future<void> _initManagersAndFirstLoad() async {
    await loadUserData();

    final prefs = await SharedPreferences.getInstance();
    _salesOrderMgrId = prefs.getString('salesPurchaseOrderManagerID')?.trim() ?? '';
    _invoiceMgrId    = prefs.getString('invoiceManagerID')?.trim() ?? '';
    _stockLocationId = prefs.getString('stockLocationID')?.trim() ?? '';

    final hasSO  = _salesOrderMgrId.isNotEmpty;
    final hasInv = _invoiceMgrId.isNotEmpty;

    setState(() {
      if (hasSO && hasInv) {
        _showManagerSwitch = true;
        _managerSource = ManagerSource.salesOrder; // default
      } else if (hasSO) {
        _showManagerSwitch = false;
        _managerSource = ManagerSource.salesOrder;
      } else if (hasInv) {
        _showManagerSwitch = false;
        _managerSource = ManagerSource.invoice;
      } else {
        _showManagerSwitch = false;
        _managerSource = null;
      }
    });

    _resetAndFetch();
  }
  void _resetAndFetch() {
    setState(() {
      currentPage = 1;
      _products.clear();
      hasMore = true;
    });
    fetchProducts();
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
  String? _resolveActiveManagerId() {
    if (_managerSource == null) return null;
    if (_managerSource == ManagerSource.salesOrder) return _salesOrderMgrId.isNotEmpty ? _salesOrderMgrId : null;
    if (_managerSource == ManagerSource.invoice)    return _invoiceMgrId.isNotEmpty ? _invoiceMgrId : null;
    return null;
  }
  Future<void> fetchProducts() async {
    final activeId = _resolveActiveManagerId();
    if (activeId == null || activeId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No manager ID available to fetch products.')),
        );
      });
      return;
    }
    setState(() => isLoading = true);
    try {

      List<Product> newProducts = [];
      if (_managerSource == ManagerSource.salesOrder) {
        newProducts.clear();
        newProducts = await ApiService.fetchProductsFromOrderManager(
          managerID: activeId,
          stockLocationID: _stockLocationId,
          page: currentPage,
          pageSize: pageSize,
          searchKey: searchKey,
          barcode: barcode
        );
      }
      if (_managerSource == ManagerSource.invoice) {
        newProducts.clear();
        newProducts = await ApiService.fetchProductsFromInvoiceManager(
          managerID: activeId,
          stockLocationID: _stockLocationId,
          page: currentPage,
          pageSize: pageSize,
          searchKey: searchKey,
          barCode: barcode
        );
      }
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
  Widget _managerToggleBar() {
    if (!_showManagerSwitch) {
      // Optional: show small chip if only one manager is active
      if (_managerSource == null) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          //child: Chip(label: Text('Products on Manager: $label')),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: SegmentedButton<ManagerSource>(
        segments: const <ButtonSegment<ManagerSource>>[
          ButtonSegment(value: ManagerSource.salesOrder, label: Text('Sales Order')),
          ButtonSegment(value: ManagerSource.invoice,    label: Text('Invoice')),
        ],
        selected: {
          _managerSource ?? ManagerSource.salesOrder
        },
        onSelectionChanged: (newSel) {
          final bool isInvoice = _managerSource == ManagerSource.invoice;
          actionLabel = isInvoice ? 'Create Invoice' : 'Place Order';
          actionType = isInvoice
              ? OrderAction.placeOrder
              : OrderAction.salesInvoice;
          final next = newSel.first;
          if (next == _managerSource) return;
          setState(() {
            _managerSource = next;
            // ✅ Clear cart when switching between Sales Order / Invoice
            _cart.clear();
            // Reset paging and product list
            currentPage = 1;
            _products.clear();
            hasMore = true;
          });
          fetchProducts();
        },

      ),
    );
  }
  Widget _fabButtons() {
    // Determine dynamic label & action type based on selected manager source
    final bool isInvoice = _managerSource == ManagerSource.invoice;
    final String actionLabel = isInvoice ? 'Create Invoice' : 'Place Order';
    final IconData actionIcon = isInvoice ? Icons.receipt_long : Icons.shopping_bag;
    final OrderAction actionType =
    isInvoice ? OrderAction.salesInvoice : OrderAction.placeOrder;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isFabExpanded) ...[
          FloatingActionButton.extended(
            heroTag: 'dynamicAction',
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: () {
              if (_cart.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cart is empty')),
                );
              } else {
                _showOrderSummaryDialog(actionType);
              }
            },
            icon: Icon(actionIcon, color: Colors.white),
            label: Text(actionLabel, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          backgroundColor: Theme.of(context).colorScheme.primary,
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
    return Dismissible(
      key: ValueKey(product.skuCode),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: AppColors.appBackgroundGreyColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.shopping_cart, color: AppColors.mainButtonsColor, size: 30),
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
      margin: const EdgeInsets.only(top: 20,bottom: 0,left: 20,right: 20),
      elevation: 0,
      color: AppColors.whiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.imageUrls!.isNotEmpty
                  ? Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color:AppColors.appBackgroundGreyColor),
                ),
                    child: Image.network(
                                    ApiService.imageBaseUrl + product.imageUrls!,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                                    ),
                                  ),
                  )
                  : Container(
                width: 110,
                height: 110,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black),
                ),
                child: const Icon(Icons.image, size: 30, color: Colors.black),
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
                    product.skuName!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        fontFamily: 'Roboto', // modern clean font
                        letterSpacing: 0.2,
                        color:AppColors.blackColor
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Brand
                  Text(
                    'Brand: ${product.brandName}',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.brandGreyColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rs. ${product.tradePrice}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.priceGreenColor,
                          fontFamily: 'RobotoMono', // monospace for numbers
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        margin: EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: product.stockInHand! > 0
                              ? AppColors.stockBackColor
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: product.stockInHand! > 0 ? AppColors.stockBorderColor : Colors.red,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          product.stockInHand! > 0
                              ? 'Stock: ${product.stockInHand!.toStringAsFixed(0)}'
                              : 'Out of stock',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: product.stockInHand! > 0 ? AppColors.stockTextColor : Colors.red[800],
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
  void _showOrderSummaryDialog(OrderAction action) {
    final bool isInvoice = action == OrderAction.salesInvoice;
    String dialogTitle = isInvoice ? '🧾 Sales Invoice' : '🧾 Order Summary';

    // Controllers persist for dialog lifetime
    final TextEditingController addressController = TextEditingController();
    final TextEditingController walkInNameController = TextEditingController();
    final TextEditingController walkInMobileController = TextEditingController();
    Future<List<Map<String, dynamic>>> _loadBanksFromPrefs() async {
      final prefs = await SharedPreferences.getInstance();
      final banksString = prefs.getString('banks');
      if (banksString == null) return [];
      final List<dynamic> banksList = jsonDecode(banksString);
      return banksList.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    showDialog(
      context: context,
      builder: (outerCtx) {
        // Persist across StatefulBuilder rebuilds
        bool isWalkIn = isInvoice ? true : false;
        bool isSubmitting = false;
        List<Map<String, dynamic>> bankPayments = [];



        bool finalizeDisabled(List cartItems) {
          if (cartItems.isEmpty || isSubmitting) return true;

          if (isInvoice) {
            // Walk-in: allow finalize even if name/mobile are empty
            if (isWalkIn) return false;

            // Registered: still require a selected customer
            return _selectedCustomer == null;
          } else {
            // Sales Order: always require a selected customer
            return _selectedCustomer == null;
          }
        }

        Future<void> _openBankPaymentPopup(void Function(void Function()) setStateDialog) async {
          final banks = await _loadBanksFromPrefs();
          String? selectedBankId;
          String? selectedBankName;
          final amountController = TextEditingController();

          showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                // Shrink overall dialog margins on small screens
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                title: const Text("Select Bank & Amount"),
                content: ConstrainedBox(
                  // ✅ Hard limit the dialog’s content width
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- Select Bank (narrow + non-overflow) ---
                        DropdownButtonFormField<String>(
                          isExpanded: true, // ✅ Prevents overflow of long names
                          decoration: const InputDecoration(
                            labelText: "Bank",
                            isDense: true, // ✅ More compact height
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          menuMaxHeight: 300, // ✅ Keep the menu from covering the whole screen
                          items: banks.map<DropdownMenuItem<String>>((bank) {
                            return DropdownMenuItem<String>(
                              value: bank['bankID'] as String,
                              child: Text(
                                bank['bankName'] as String,
                                overflow: TextOverflow.ellipsis, // ✅ Ellipsize long names
                                softWrap: false,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            selectedBankId = val;
                            if (val != null) {
                              final match = banks.firstWhere((b) => b['bankID'] == val);
                              selectedBankName = match['bankName'] as String?;
                            }
                          },
                        ),

                        const SizedBox(height: 12),

                        // --- Amount ---
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Amount",
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final raw = amountController.text.trim();
                      final amount = double.tryParse(raw) ?? 0;
                      if (selectedBankId != null && raw.isNotEmpty && amount > 0) {
                        setStateDialog(() {
                          bankPayments.add({
                            "bankID": selectedBankId,
                            "bankName": selectedBankName,
                            "amount": amount,
                          });
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text("Add"),
                  ),
                ],
              );
            },
          );
        }

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final cartItems = _products.where((p) => _cart.containsKey(p.skuCode)).toList();

            double grandTotal = 0;
            for (var item in cartItems) {
              final qty = _cart[item.skuCode]!;
              final price = double.tryParse(item.tradePrice!) ?? 0;
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

                    if (isInvoice==false ) ...[
                      // Walk-in vs Registered toggle
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(value: true, label: Text('Walk-in customer')),
                          ButtonSegment<bool>(value: false, label: Text('Registered customer')),
                        ],
                        selected: {isWalkIn},
                        onSelectionChanged: (s) {
                          setStateDialog(() {
                            isWalkIn = s.first;
                            if (isWalkIn) {
                              _selectedCustomer = null;
                              addressController.text = ''; // no delivery address for walk-in
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),

                      if (isWalkIn) ...[
                        // WALK-IN FIELDS: NAME + MOBILE
                        TextField(
                          controller: walkInNameController,
                          decoration: const InputDecoration(
                            labelText: "Walk-in Name (optional)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: walkInMobileController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: "Mobile Number (optional)",
                            hintText: "03XXXXXXXXX",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        // Registered customer dropdown
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
                            itemBuilder: (context, Customer customer, isSelected) => ListTile(
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
                            return await ApiService.fetchInvCustomers(_invoiceMgrId, filter);
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
                      ],
                    ] else ...[
                      // Sales Order: always registered customer
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
                          itemBuilder: (context, Customer customer, isSelected) => ListTile(
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
                          return await ApiService.fetchPOCustomers(_salesOrderMgrId, filter);
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
                    ],

                    const SizedBox(height: 12),

                    // DELIVERY ADDRESS: hide for walk-in invoice
                    if (!(isInvoice && isWalkIn)) ...[
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
                    ],

                    const Divider(),
                    Text("🛒 Items (${cartItems.length})", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),

                    Expanded(
                      child: cartItems.isEmpty
                          ? const Center(child: Text("Cart is empty."))
                          : ListView.builder(
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final qty = _cart[item.skuCode]!;
                          return _OrderItemTile(
                            item: item,
                            qty: qty,
                            onQtyChanged: (newQty) {
                              if (newQty < 1) return;
                              setStateDialog(() {
                                _cart[item.skuCode!] = newQty;
                              });
                            },
                            onRemove: () {
                              setState(() {
                                _cart.remove(item.skuCode);
                              });
                              setStateDialog(() {});
                            },
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
                Row(
                  children: [


                    if (isInvoice) ...[
                      IconButton(
                        tooltip: 'Add bank payment',
                        onPressed: () => _openBankPaymentPopup(setStateDialog),
                        icon: const Icon(Icons.account_balance),
                      ),
                      const SizedBox(width: 8),
                    ],


                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: finalizeDisabled(cartItems)
                            ? null
                            : () async {
                          setStateDialog(() => isSubmitting = true); // lock UI

                          final prefs = await SharedPreferences.getInstance();
                          final employeeID = prefs.getString('employeeID');

                          if (action == OrderAction.placeOrder) {
                            // Registered customer required
                            final payload = {
                              "fK_Customer_ID": _selectedCustomer!.id,
                              "fK_Employee_ID": employeeID,
                              "deliveryAddress": addressController.text,
                              "isBankGuarantee": false,
                              "isClosed": false,
                              "fK_PurchaseSalesOrderManagerMaster_ID":
                              prefs.getString('salesPurchaseOrderManagerID') ?? '',
                              "docDate": DateTime.now().toIso8601String(),
                              "expectedDelRecDate": null,
                              "bankGuaranteeIssueDate": null,
                              "bankGuaranteeExpiryDate": null,
                              "proformaInvoiceDate": null,
                              "lcReceived": false,
                              "transShipmentAllow": false,
                              "purchaseSalesOrderDetailsInp": cartItems.map((item) {
                                final qty = _cart[item.skuCode]!;
                                final rate = double.tryParse(item.tradePrice!) ?? 0;
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
                                await Future.delayed(const Duration(seconds: 2));
                                if (context.mounted) Navigator.pop(context);
                              } else {
                                final msg = ApiService.extractServerMessage(response);
                                setStateDialog(() => dialogTitle = '❌ $msg');
                              }
                            } catch (e) {
                              setStateDialog(() => dialogTitle = '⚠️ Error: $e');
                            } finally {
                              setStateDialog(() => isSubmitting = false);
                            }
                          }

                          if (action == OrderAction.salesInvoice) {
                            final customerId = isWalkIn
                                ? (prefs.getString('walkInCustomerID') ?? '')
                                : (_selectedCustomer?.id ?? '');
                            String? _bankID;
                            double _bankTotal = 0.0;
                            // recompute totals safely
                            double bankTotal = 0;
                            for (final bp in bankPayments) {
                              _bankID=bp['bankID'] as String;
                              _bankTotal = (bp['amount'] as double?) ?? 0.0;
                              bankTotal += (bp['amount'] as double?) ?? 0.0;
                            }
                            final double cashAfterBank = (grandTotal - bankTotal).clamp(0, double.infinity);
                            final payload = {
                              "fK_Customer_ID": customerId,
                              "fK_Employee_ID": employeeID,
                              // For walk-in: no delivery address
                              "deliveryAddress": isWalkIn ? "" : addressController.text,
                              "fK_StockLocation_ID": prefs.getString('stockLocationID') ?? '',
                              "fK_InvoiceManagerMaster_ID": prefs.getString('invoiceManagerID') ?? '',
                              "docDate": DateTime.now().toIso8601String(),
                              if (_bankID != null && _bankTotal > 0) ...{
                                "fK_ChartOfAccounts_ID_Bank": _bankID,
                                "bankReceived": _bankTotal,
                              },
                              // Walk-in extras (your API can accept these or ignore if not present)
                              "customerNamePOS": isWalkIn ? walkInNameController.text.trim() : "",
                              "mobileNumber": isWalkIn ? walkInMobileController.text.trim() : "",
                              "cashReceived": cashAfterBank,
                              "invoiceDetailsInp": cartItems.map((item) {
                                final qty = _cart[item.skuCode]!;
                                final rate = double.tryParse(item.tradePrice!) ?? 0;
                                return {
                                  "id": "",
                                  "fK_ChartOfAccounts_ID": null,
                                  "fK_Sku_ID": item.id,
                                  "fK_SKUPacking_ID": item.defaultPackingID,
                                  "quantity": qty,
                                  "rate": rate,
                                  "amount": qty * rate,
                                  "discountPercentage": 0,
                                  "discountAmount": 0,
                                  "totalAmount": qty * rate,
                                  "valueExclusiveTax": 0,
                                  "taxPercentage": 0,
                                  "taxAmount": 0,
                                  "valueInclusiveTax": 0,
                                  "freightCharges": 0,
                                  "notes": isWalkIn
                                      ? "Walk-in: ${walkInNameController.text.trim()} / ${walkInMobileController.text.trim()}"
                                      : "",
                                  "batchNumber": "",
                                };
                              }).toList(),
                              "invoiceGdnGrnDetailsInp": [],
                            };

                            try {
                              final resp = await ApiService.finalizeInvoice(payload);

                              // 1) Check HTTP status first
                              final ok = resp.statusCode >= 200 && resp.statusCode < 300;
                              if (!ok) {
                                final msg = ApiService.extractServerMessage(resp);
                                setStateDialog(() => dialogTitle = '❌ $msg');
                                return;
                              }

                              // 2) Parse body → data
                              Map<String, dynamic> invData;
                              try {
                                final body = jsonDecode(resp.body);
                                final data = body['data'];
                                if (data is Map) {
                                  invData = Map<String, dynamic>.from(data as Map);
                                } else {
                                  // Data missing or wrong shape
                                  setStateDialog(() => dialogTitle = '⚠️ Invalid server response (no data).');
                                  return;
                                }
                              } catch (e) {
                                setStateDialog(() => dialogTitle = '⚠️ Could not read invoice from server.');
                                return;
                              }

                              // 3) Success UI updates
                              setState(() => _cart.clear());
                              setStateDialog(() => dialogTitle = '✅ Invoice Created successfully!');

                              // 4) Close the summary dialog
                              if (!context.mounted) return;
                              Navigator.pop(context);

                              // 5) Go to print/preview screen
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvoicePrintPage(inv: invData),
                                ),
                              );
                            } catch (e, st) {
                              setStateDialog(() => dialogTitle = '⚠️ Error: $e');
                              debugPrint('finalizeInvoice error: $e\n$st');
                            } finally {
                              setStateDialog(() => isSubmitting = false);
                            }

                          }
                        },
                        child: isSubmitting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                            : Text(isInvoice ? '🧾 Save' : '📝 Save'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

/*  void _showOrderSummaryDialog(OrderAction action) {
    final bool isInvoice = action == OrderAction.salesInvoice;
    String dialogTitle = isInvoice ? '🧾 Sales Invoice' : '🧾 Order Summary';

    // Controllers persist for dialog lifetime
    final TextEditingController addressController = TextEditingController();
    final TextEditingController walkInNameController = TextEditingController();
    final TextEditingController walkInMobileController = TextEditingController();
    Future<List<Map<String, dynamic>>> _loadBanksFromPrefs() async {
      final prefs = await SharedPreferences.getInstance();
      final banksString = prefs.getString('banks');
      if (banksString == null) return [];
      final List<dynamic> banksList = jsonDecode(banksString);
      return banksList.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    showDialog(
      context: context,
      builder: (outerCtx) {
        // Persist across StatefulBuilder rebuilds
        bool isWalkIn = isInvoice ? true : false;
        bool isSubmitting = false;
        List<Map<String, dynamic>> bankPayments = [];


        bool finalizeDisabled(List cartItems) {
          if (cartItems.isEmpty || isSubmitting) return true;

          if (isInvoice) {
            // Walk-in: allow finalize even if name/mobile are empty
            if (isWalkIn) return false;

            // Registered: still require a selected customer
            return _selectedCustomer == null;
          } else {
            // Sales Order: always require a selected customer
            return _selectedCustomer == null;
          }
        }
        
        Future<void> _openBankPaymentPopup(
          void Function(void Function()) setStateDialog,
        ) async
        {
          final banks = await _loadBanksFromPrefs();
          String? selectedBankId;
          String? selectedBankName;
          final amountController = TextEditingController();

          showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                // Shrink overall dialog margins on small screens
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                title: const Text("Select Bank & Amount"),
                content: ConstrainedBox(
                  // ✅ Hard limit the dialog’s content width
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- Select Bank (narrow + non-overflow) ---
                        DropdownButtonFormField<String>(
                          isExpanded: true, // ✅ Prevents overflow of long names
                          decoration: const InputDecoration(
                            labelText: "Bank",
                            isDense: true, // ✅ More compact height
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          menuMaxHeight: 300, // ✅ Keep the menu from covering the whole screen
                          items: banks.map<DropdownMenuItem<String>>((bank) {
                            return DropdownMenuItem<String>(
                              value: bank['bankID'] as String,
                              child: Text(
                                bank['bankName'] as String,
                                overflow: TextOverflow.ellipsis, // ✅ Ellipsize long names
                                softWrap: false,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            selectedBankId = val;
                            if (val != null) {
                              final match = banks.firstWhere((b) => b['bankID'] == val);
                              selectedBankName = match['bankName'] as String?;
                            }
                          },
                        ),

                        const SizedBox(height: 12),

                        // --- Amount ---
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Amount",
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final raw = amountController.text.trim();
                      final amount = double.tryParse(raw) ?? 0;
                      if (selectedBankId != null && raw.isNotEmpty && amount > 0) {
                        setStateDialog(() {
                          bankPayments.add({
                            "bankID": selectedBankId,
                            "bankName": selectedBankName,
                            "amount": amount,
                          });
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text("Add"),
                  ),
                ],
              );
            },
          );
        }

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

                    if (isInvoice) ...[
                      // Walk-in vs Registered toggle
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(value: true, label: Text('Walk-in customer')),
                          ButtonSegment<bool>(value: false, label: Text('Registered customer')),
                        ],
                        selected: {isWalkIn},
                        onSelectionChanged: (s) {
                          setStateDialog(() {
                            isWalkIn = s.first;
                            if (isWalkIn) {
                              _selectedCustomer = null;
                              addressController.text = ''; // no delivery address for walk-in
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),

                      if (isWalkIn) ...[
                        // WALK-IN FIELDS: NAME + MOBILE
                        TextField(
                          controller: walkInNameController,
                          decoration: const InputDecoration(
                            labelText: "Walk-in Name (optional)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: walkInMobileController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: "Mobile Number (optional)",
                            hintText: "03XXXXXXXXX",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        // Registered customer dropdown
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
                            itemBuilder: (context, Customer customer, isSelected) => ListTile(
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
                            return await ApiService.fetchInvCustomers(_invoiceMgrId, filter);
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
                      ],
                    ] else ...[
                      // Sales Order: always registered customer
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
                          itemBuilder: (context, Customer customer, isSelected) => ListTile(
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
                          return await ApiService.fetchPOCustomers(_salesOrderMgrId, filter);
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
                    ],

                    const SizedBox(height: 12),

                    // DELIVERY ADDRESS: hide for walk-in invoice
                    if (!(isInvoice && isWalkIn)) ...[
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
                    ],

                    const Divider(),
                    Text("🛒 Items (${cartItems.length})", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),

                    Expanded(
                      child: cartItems.isEmpty
                          ? const Center(child: Text("Cart is empty."))
                          : ListView.builder(
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final qty = _cart[item.skuCode]!;
                          return _OrderItemTile(
                            item: item,
                            qty: qty,
                            onQtyChanged: (newQty) {
                              if (newQty < 1) return;
                              setStateDialog(() {
                                _cart[item.skuCode] = newQty;
                              });
                            },
                            onRemove: () {
                              setState(() {
                                _cart.remove(item.skuCode);
                              });
                              setStateDialog(() {});
                            },
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
                Row(
                  children: [


                    if (isInvoice) ...[
                      IconButton(
                        tooltip: 'Add bank payment',
                        onPressed: () => _openBankPaymentPopup(setStateDialog),
                        icon: const Icon(Icons.account_balance),
                      ),
                      const SizedBox(width: 8),
                    ],


                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: finalizeDisabled(cartItems)
                            ? null
                            : () async {
                          setStateDialog(() => isSubmitting = true); // lock UI

                          final prefs = await SharedPreferences.getInstance();
                          final employeeID = prefs.getString('employeeID');

                          if (action == OrderAction.placeOrder) {
                            // Registered customer required
                            final payload = {
                              "fK_Customer_ID": _selectedCustomer!.id,
                              "fK_Employee_ID": employeeID,
                              "deliveryAddress": addressController.text,
                              "isBankGuarantee": false,
                              "isClosed": false,
                              "fK_PurchaseSalesOrderManagerMaster_ID":
                              prefs.getString('salesPurchaseOrderManagerID') ?? '',
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
                                await Future.delayed(const Duration(seconds: 2));
                                if (context.mounted) Navigator.pop(context);
                              } else {
                                final msg = ApiService.extractServerMessage(response);
                                setStateDialog(() => dialogTitle = '❌ $msg');
                              }
                            } catch (e) {
                              setStateDialog(() => dialogTitle = '⚠️ Error: $e');
                            } finally {
                              setStateDialog(() => isSubmitting = false);
                            }
                          }

                          if (action == OrderAction.salesInvoice) {
                            final customerId = isWalkIn
                                ? (prefs.getString('walkInCustomerID') ?? '')
                                : (_selectedCustomer?.id ?? '');

                            String? _bankID;
                            double _bankTotal = 0.0;
                            // recompute totals safely
                            double bankTotal = 0;
                            for (final bp in bankPayments) {
                              _bankID=bp['bankID'] as String;
                              _bankTotal = (bp['amount'] as double?) ?? 0.0;
                              bankTotal += (bp['amount'] as double?) ?? 0.0;
                            }
                            final double cashAfterBank = (grandTotal - bankTotal).clamp(0, double.infinity);









                            final payload = {
                              "fK_Customer_ID": customerId,
                              "fK_Employee_ID": employeeID,
                              // For walk-in: no delivery address
                              "deliveryAddress": isWalkIn ? "" : addressController.text,
                              "fK_StockLocation_ID": prefs.getString('stockLocationID') ?? '',
                              "fK_InvoiceManagerMaster_ID": prefs.getString('invoiceManagerID') ?? '',
                              "docDate": DateTime.now().toIso8601String(),


                              if (_bankID != null && _bankTotal > 0) ...{
                                "fK_ChartOfAccounts_ID_Bank": _bankID,
                                "bankReceived": _bankTotal,
                              },


                              // Walk-in extras (your API can accept these or ignore if not present)
                              "customerNamePOS": isWalkIn ? walkInNameController.text.trim() : "",
                              "mobileNumber": isWalkIn ? walkInMobileController.text.trim() : "",
                              "cashReceived": cashAfterBank,

                              "invoiceDetailsInp": cartItems.map((item) {
                                final qty = _cart[item.skuCode]!;
                                final rate = double.tryParse(item.tradePrice) ?? 0;
                                return {
                                  "id": "",
                                  "fK_ChartOfAccounts_ID": null,
                                  "fK_Sku_ID": item.id,
                                  "fK_SKUPacking_ID": item.defaultPackingID,
                                  "quantity": qty,
                                  "rate": rate,
                                  "amount": qty * rate,
                                  "discountPercentage": 0,
                                  "discountAmount": 0,
                                  "totalAmount": qty * rate,
                                  "valueExclusiveTax": 0,
                                  "taxPercentage": 0,
                                  "taxAmount": 0,
                                  "valueInclusiveTax": 0,
                                  "freightCharges": 0,
                                  "notes": isWalkIn
                                      ? "Walk-in: \${walkInNameController.text.trim()} / \${walkInMobileController.text.trim()}"
                                      : "",
                                  "batchNumber": "",
                                };
                              }).toList(),
                              "invoiceGdnGrnDetailsInp": [],
                            };

                            try {
                              final resp = await ApiService.finalizeInvoice(payload);

                              // 1) Check HTTP status first
                              final ok = resp.statusCode >= 200 && resp.statusCode < 300;
                              if (!ok) {
                                final msg = ApiService.extractServerMessage(resp);
                                setStateDialog(() => dialogTitle = '❌ $msg');
                                return;
                              }

                              // 2) Parse body → data
                              Map<String, dynamic> invData;
                              try {
                                final body = jsonDecode(resp.body);
                                final data = body['data'];
                                if (data is Map) {
                                  invData = Map<String, dynamic>.from(data as Map);
                                } else {
                                  // Data missing or wrong shape
                                  setStateDialog(() => dialogTitle = '⚠️ Invalid server response (no data).');
                                  return;
                                }
                              } catch (e) {
                                setStateDialog(() => dialogTitle = '⚠️ Could not read invoice from server.');
                                return;
                              }

                              // 3) Success UI updates
                              setState(() => _cart.clear());
                              setStateDialog(() => dialogTitle = '✅ Invoice Created successfully!');

                              // 4) Close the summary dialog
                              if (!context.mounted) return;
                              Navigator.pop(context);

                              // 5) Go to print/preview screen
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvoicePrintPage(inv: invData),
                                ),
                              );
                            } catch (e, st) {
                              setStateDialog(() => dialogTitle = '⚠️ Error: $e');
                              debugPrint('finalizeInvoice error: $e\n$st');
                            } finally {
                              setStateDialog(() => isSubmitting = false);
                            }

                          }
                        },
                        child: isSubmitting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                            : Text(isInvoice ? '🧾 Save' : '📝 Save'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }*/


  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
 final theme = Theme.of(context);
 final cartItems = _products.where((p) => _cart.containsKey(p.skuCode)).toList();

 double grandTotal = 0;
 for (var item in cartItems) {
   final qty = _cart[item.skuCode]!;
   final price = double.tryParse(item.tradePrice!) ?? 0;
   grandTotal += qty * price;
 }

    return Scaffold(
      backgroundColor: AppColors.appBackgroundGreyColor,
      appBar: AppBar(
        title: const Text('Products',style: TextStyle(color: Colors.black,fontSize: 20,fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.mainButtonsColor,
        toolbarHeight: 80,
        iconTheme: IconThemeData(color: AppColors.blackColor,size: 30),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Cart',
            onPressed: _cart.isNotEmpty ? _clearCart : null,
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  if (_cart.isEmpty) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Cart is empty')));
                  } else {
                    //_showOrderSummaryDialog(actionType);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>  SalesInvoiceScreen(invoiceMgrId: _invoiceMgrId,products: cartItems,cart: _cart,fbrList : fbrScenario)
                      ),
                    ).then((value) {
                      setState(() {
                        _cart.clear();
                      });
                    }
                    );
                  }
                },
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
        backgroundColor: AppColors.whiteColor,
        surfaceTintColor: AppColors.mainButtonsColor,
        child: Column(
          children: [
            // Header Section
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: AppColors.mainButtonsColor),
              accountName: Text(
                '$firstName $lastName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blackColor
                ),
              ),
              accountEmail: Text(
                'admin@topsum.com', // Replace with actual email if available
                style:  TextStyle(fontSize: 14,color: AppColors.blackColor),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : 'D',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainButtonsColor,
                  ),
                ),
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.language,
                    title: 'Allowed IP',
                    route: '/allowedIPs',
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.account_balance_wallet,
                    title: 'Customer Ledger',
                    route: '/customerLedger',
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.payments_outlined,
                    title: 'Collections',
                    route: '/collections',
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.call_received,
                    title: 'Good Receive Note',
                    route: '/good_recieve_note_screen',
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.call_made,
                    title: 'GRN Discard',
                    route: '/grn_discard_screen',
                  ),

                 /* _buildDrawerItem(
                    context,
                    icon: Icons.storage_outlined,
                    title: 'Stock Taking',
                    route: '/my_stock_screen',
                  ),*/

                  _buildDrawerItem(
                    context,
                    icon: Icons.inventory_outlined,
                    title: 'Stock Taking',
                    route: '/stock_taking_screen',
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.shopping_cart,
                    title: 'My Sales Orders',
                    route: '/mySalesOrders',
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.people,
                    title: 'My Customers',
                    route: '/myCustomers',
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.receipt_long,
                    title: 'My Sales Invoices',
                    route: '/mySalesInvoices',
                    // badge: '3', // Uncomment if you want to show badge count
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.book,
                    title: 'My Cash Book',
                    route: '/myCashBook',
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.attach_money,
                    title: 'My Expenses',
                    route: '/myExpenses',
                  ),

                  _buildDrawerItem(
                    context,
                    icon: Icons.policy,
                    title: 'Active Policy',
                    route: '/activePolicy',
                  ),
                ],
              ),
            ),

            // Bottom Section
            const Divider(height: 1),

            _buildDrawerItem(
              context,
              icon: Icons.logout,
              title: 'Logout',
              iconColor: Colors.red,
              textColor: Colors.red,
              onTap: () async {
                final nav = Navigator.of(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                nav.pushReplacementNamed('/login');
              },
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Version 2.4.1',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '© 2025 SMH Global',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          _managerToggleBar(),
          Padding(
            padding: const EdgeInsets.only(left:20,right: 20,top: 10,bottom: 10),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.black87), // make typed text visible
              cursorColor: Colors.black54,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: const TextStyle(color: AppColors.greyColor),    // visible hint
                filled: true,
                fillColor: Colors.white,                               // solid light background
                icon: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: Offset(0, 5), // changes position of shadow
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: scanBarcodeAndFetchProduct,
                    icon: Icon(Icons.qr_code_scanner ,color: AppColors.grey2Color,size: 30,),
                  ),
                ),
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
                    : const Icon(Icons.search, color: AppColors.greyColor),
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
                      barcode = ''; // Also clear barcode state on search clear
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
                  borderSide: const BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white), // brand color on focus
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
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
          Expanded(
            child: _products.isEmpty
                ? Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('No products found.'),
            )
                : ListView.builder(
              padding: EdgeInsets.only(bottom: 40),
              controller: _scrollController,
              itemCount: _products.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _products.length) {
                  return _buildProductItem(_products[index]);
                } else {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: AppColors.mainButtonsColor,)),
                  );
                }
              },
            ),
          ),
        ],
      ),
      //floatingActionButton: Stack(children: [_buildExpandableFAB()]),
    );
  }
  // void _switchManager(ManagerSource next) {
  //   if (next == _managerSource) return;
  //
  //   setState(() {
  //     _managerSource = next;
  //
  //     // 👇 clear cart on mode change
  //     _cart.clear();
  //
  //     // also reset paging & products so list reloads for new mode
  //     currentPage = 1;
  //     _products.clear();
  //     hasMore = true;
  //   });
  //
  //   // tiny heads-up
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Mode changed. Cart cleared.')),
  //   );
  //
  //   // fetch with the new active manager id
  //   fetchProducts();
  // }

  Widget _buildDrawerItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? route,
        VoidCallback? onTap,
        Color? iconColor,
        Color? textColor,
        String? badge,
      }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Colors.grey[700],
        size: 24,
      ),
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor ?? Colors.grey[800],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap ??
              () {
            Navigator.pop(context);
            if (route != null) {
              Navigator.pushNamed(context, route);
            }
          },
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
class _OrderItemTile extends StatelessWidget {
  final Product item;
  final int qty;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChanged;

  const _OrderItemTile({
    super.key,
    required this.item,
    required this.qty,
    required this.onRemove,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = double.tryParse(item.tradePrice!) ?? 0;
    final total = price * qty;

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4), // less margin
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8), // reduced padding
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // align center vertically
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8), // slightly smaller radius
              child: item.imageUrls!.isNotEmpty
                  ? Image.network(
                ApiService.imageBaseUrl + item.imageUrls!,
                width: 48,
                height: 48, // reduced size
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 18, color: Colors.grey),
                ),
              )
                  : Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                color: Colors.grey[200],
                child: const Icon(Icons.image, size: 18, color: Colors.grey),
              ),
            ),

            const SizedBox(width: 8),

            // Title, price x qty, stepper
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // shrink height
                children: [
                  Text(
                    item.skuName!,
                    maxLines: 1, // force single line for compactness
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Rs. ${price.toStringAsFixed(2)} × $qty',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  _QtyPillStepper(
                    value: qty,
                    onChanged: onQtyChanged,
                    primary: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Total + delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min, // shrink height
              children: [
                Text(
                  'Rs. ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  splashRadius: 16,
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );

  }
}
class _QtyPillStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color primary;

  const _QtyPillStepper({
    required this.value,
    required this.onChanged,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // much smaller
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniIconButton(Icons.remove, () {
            if (value > 1) onChanged(value - 1);
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 13, // smaller font
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _miniIconButton(Icons.add, () {
            onChanged(value + 1);
          }),
        ],
      ),
    );
  }

  Widget _miniIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(2), // small tap target
        child: Icon(icon, size: 16, color: primary), // smaller icon
      ),
    );
  }
}