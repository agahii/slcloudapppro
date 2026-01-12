import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


import 'package:slcloudapppro/widgets_page.dart';

import 'Model/Product.dart';
Customer? _selectedCustomer;
TextEditingController _addressController = TextEditingController();



// ============================================================================
// MAIN SALES INVOICE SCREEN
// ============================================================================
class SalesInvoiceScreen extends StatefulWidget {
  final String invoiceMgrId;
  final List<Product> products;

  const SalesInvoiceScreen({
    Key? key,
    required this.invoiceMgrId,
    required this.products,
  }) : super(key: key);

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;


  // Cart data - shared between tabs
  final Map<String, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sales Invoice',
          style: TextStyle(
              color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFDB022),
              indicatorWeight: 3,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Walk-in'),
                Tab(text: 'Registered'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          WalkInCustomerTab(
            cart: _cart,
            products: widget.products,
            onCartUpdate: () => setState(() {}),
            invoiceMgrId: widget.invoiceMgrId,
          ),
          RegisteredCustomerTab(
            cart: _cart,
            products: widget.products,
            onCartUpdate: () => setState(() {}),
            invoiceMgrId: widget.invoiceMgrId,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WALK-IN CUSTOMER TAB
// ============================================================================
class WalkInCustomerTab extends StatefulWidget {
  final Map<String, int> cart;
  final List<Product> products;
  final VoidCallback onCartUpdate;
  final String invoiceMgrId;

  const WalkInCustomerTab({
    Key? key,
    required this.cart,
    required this.products,
    required this.onCartUpdate,
    required this.invoiceMgrId,
  }) : super(key: key);

  @override
  State<WalkInCustomerTab> createState() => _WalkInCustomerTabState();
}

class _WalkInCustomerTabState extends State<WalkInCustomerTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _creditDaysController =
  TextEditingController(text: '000');
  final TextEditingController _discountController = TextEditingController();

  String _selectedPaymentMethod = 'Cash';
  List<Map<String, dynamic>> _bankPayments = [];
  bool _isSubmitting = false;
  bool _isDiscountPercentage = true;

  @override
  void dispose() {
    _addressController.dispose();
    _creditDaysController.dispose();
    _discountController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _creditDaysController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double _calculateSubtotal() {
    double total = 0;
    for (var product in widget.products) {
      if (widget.cart.containsKey(product.skuCode)) {
        final qty = widget.cart[product.skuCode]!;
        final price = double.tryParse(product.tradePrice) ?? 0;
        total += qty * price;
      }
    }
    return total;
  }

  double _calculateDiscount() {
    final subtotal = _calculateSubtotal();
    final discountValue = double.tryParse(_discountController.text) ?? 0;

    if (_isDiscountPercentage) {
      return (subtotal * discountValue) / 100;
    } else {
      return discountValue;
    }
  }

  double _calculateTax() {
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount();
    return (subtotal - discount) * 0.05;
  }

  double _calculateGrandTotal() {
    return _calculateSubtotal() - _calculateDiscount() + _calculateTax();
  }

  Future<List<Map<String, dynamic>>> _loadBanksFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final banksString = prefs.getString('banks');
    if (banksString == null) return [];
    final List<dynamic> banksList = jsonDecode(banksString);
    return banksList.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _openBankPaymentPopup() async {
    final banks = await _loadBanksFromPrefs();
    String? selectedBankId;
    String? selectedBankName;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text("Select Bank & Amount"),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Bank",
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    menuMaxHeight: 300,
                    items: banks.map<DropdownMenuItem<String>>((bank) {
                      return DropdownMenuItem<String>(
                        value: bank['bankID'] as String,
                        child: Text(
                          bank['bankName'] as String,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      selectedBankId = val;
                      if (val != null) {
                        final match =
                        banks.firstWhere((b) => b['bankID'] == val);
                        selectedBankName = match['bankName'] as String?;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  setState(() {
                    _bankPayments.add({
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

/*  @override
  Widget build(BuildContext context) {
    final cartItems = widget.products
        .where((p) => widget.cart.containsKey(p.skuCode))
        .toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Customer Selection Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedCustomer == null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDB022).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_search,
                            color: Color(0xFFFDB022), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Customer',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                      itemBuilder: (context, Customer customer, isSelected) =>
                          ListTile(
                            title: Text(customer.customerName),
                            subtitle: Text(customer.customerAddress),
                          ),
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: "Select Customer",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFFF8F8F8),
                      ),
                    ),
                    asyncItems: (String filter) async {
                      if (filter.length < 3) return [];
                      // TODO: Replace with your API call
                      // return await ApiService.fetchInvCustomers(widget.invoiceMgrId, filter);
                      return [];
                    },
                    itemAsString: (Customer u) => u.customerName,
                    selectedItem: _selectedCustomer,
                    onChanged: (Customer? customer) {
                      setState(() {
                        _selectedCustomer = customer;
                        _addressController.text =
                            customer?.customerAddress ?? '';
                      });
                    },
                  ),
                ] else ...[
                  // Selected customer display
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF2E7D32),
                        child: Text(
                          _selectedCustomer!.customerName[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCustomer!.customerName,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedCustomer!.id,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                              color: Colors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          setState(() => _selectedCustomer = null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Balance: ',
                            style: TextStyle(fontSize: 14)),
                        const Text(
                          'Rs. 450.00',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        ),
                        const Text(' (Due)',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Delivery Address',
                    hintText: 'Enter delivery address',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                  ),
                ),
                const SizedBox(height: 12),
                CreditDaysField(controller: _creditDaysController),
              ],
            ),
          ),

          // Cart Items Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CART ITEMS',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600]),
                    ),
                    Text(
                      '${cartItems.length} Items',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFDB022)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (cartItems.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('No items in cart',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ...cartItems.map((product) => ProductCartCard(
                    product: product,
                    quantity: widget.cart[product.skuCode]!,
                    onQuantityChanged: (newQty) {
                      setState(() {
                        if (newQty <= 0) {
                          widget.cart.remove(product.skuCode);
                        } else {
                          widget.cart[product.skuCode] = newQty;
                        }
                      });
                      widget.onCartUpdate();
                    },
                    onRemove: () {
                      setState(() => widget.cart.remove(product.skuCode));
                      widget.onCartUpdate();
                    },
                  )),
              ],
            ),
          ),

          // Overall Discount Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OVERALL DISCOUNT',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        decoration: InputDecoration(
                          labelText: 'Amount or %',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: const Color(0xFFF8F8F8),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isDiscountPercentage = !_isDiscountPercentage;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _isDiscountPercentage
                              ? const Color(0xFFFDB022)
                              : const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '%',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isDiscountPercentage
                                  ? Colors.black
                                  : Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_discountController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Discount: Rs. ${_calculateDiscount().toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Summary Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                SummaryRow('Subtotal', _calculateSubtotal()),
                SummaryRow('Tax (5%)', _calculateTax()),
                SummaryRow('Discount', _calculateDiscount(), isRed: true),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Rs. ${_calculateGrandTotal().toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDB022),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bank Payments Display
          if (_bankPayments.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance,
                          size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Bank Payments',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._bankPayments.map((bp) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(bp['bankName'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                        Row(
                          children: [
                            Text(
                              'Rs. ${(bp['amount'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                setState(() => _bankPayments.remove(bp));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),

          // Payment Method Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAYMENT METHOD',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PaymentMethodButton(
                        icon: Icons.money,
                        label: 'Cash',
                        isSelected: _selectedPaymentMethod == 'Cash',
                        onTap: () =>
                            setState(() => _selectedPaymentMethod = 'Cash'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PaymentMethodButton(
                        icon: Icons.credit_card,
                        label: 'Card',
                        isSelected: _selectedPaymentMethod == 'Card',
                        onTap: () =>
                            setState(() => _selectedPaymentMethod = 'Card'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PaymentMethodButton(
                        icon: Icons.qr_code,
                        label: 'QR Pay',
                        isSelected: _selectedPaymentMethod == 'QRPay',
                        onTap: () =>
                            setState(() => _selectedPaymentMethod = 'QRPay'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: _openBankPaymentPopup,
                  icon: const Icon(Icons.account_balance, size: 28),
                  tooltip: 'Add Bank Payment',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Save as draft logic
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text('Draft',
                        style: TextStyle(fontSize: 16, color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_selectedCustomer == null ||
                        cartItems.isEmpty ||
                        _isSubmitting)
                        ? null
                        : _saveInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDB022),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Save Invoice',
                            style: TextStyle(
                                fontSize: 16, color: Colors.black)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward,
                            size: 20, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInvoice() async {
    if (_selectedCustomer == null) return;

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeID = prefs.getString('employeeID');

      final cartItems = widget.products
          .where((p) => widget.cart.containsKey(p.skuCode))
          .toList();

      String? bankID;
      double bankTotal = 0;
      for (final bp in _bankPayments) {
        bankID = bp['bankID'] as String?;
        bankTotal += (bp['amount'] as double?) ?? 0.0;
      }
      final cashAfterBank =
      (_calculateGrandTotal() - bankTotal).clamp(0, double.infinity);

      final payload = {
        "fK_Customer_ID": _selectedCustomer!.id,
        "fK_Employee_ID": employeeID,
        "deliveryAddress": _addressController.text.trim(),
        "fK_StockLocation_ID": prefs.getString('stockLocationID') ?? '',
        "fK_InvoiceManagerMaster_ID":
        prefs.getString('invoiceManagerID') ?? '',
        "docDate": DateTime.now().toIso8601String(),
        if (bankID != null) ...{
          "fK_ChartOfAccounts_ID_Bank": bankID,
          "bankReceived": bankTotal,
        },
        "creditDays": int.tryParse(_creditDaysController.text) ?? 0,
        "cashReceived": cashAfterBank,
        "invoiceDetailsInp": cartItems.map((item) {
          final qty = widget.cart[item.skuCode]!;
          final rate = double.tryParse(item.tradePrice) ?? 0;
          final itemTotal = qty * rate;
          return {
            "id": "",
            "fK_ChartOfAccounts_ID": null,
            "fK_Sku_ID": item.id,
            "fK_SKUPacking_ID": item.defaultPackingID,
            "quantity": qty,
            "rate": rate,
            "amount": itemTotal,
            "discountPercentage": _isDiscountPercentage
                ? (double.tryParse(_discountController.text) ?? 0)
                : 0,
            "discountAmount": _isDiscountPercentage
                ? 0
                : (double.tryParse(_discountController.text) ?? 0),
            "totalAmount": itemTotal,
            "valueExclusiveTax": 0,
            "taxPercentage": 5,
            "taxAmount": 0,
            "valueInclusiveTax": 0,
            "freightCharges": 0,
            "notes":
            "Registered Customer: ${_selectedCustomer!.customerName}",
            "batchNumber": "",
          };
        }).toList(),
        "invoiceGdnGrnDetailsInp": [],
      };

      // TODO: Call your API service
      // final response = await ApiService.finalizeInvoice(payload);

      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invoice created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear cart
        setState(() {
          widget.cart.clear();
          _selectedCustomer = null;
          _addressController.clear();
          _creditDaysController.text = '000';
          _discountController.clear();
          _bankPayments.clear();
        });
        widget.onCartUpdate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }*/

/*@override
void dispose() {
  _nameController.dispose();
  _mobileController.dispose();
  _creditDaysController.dispose();
  _discountController.dispose();
  super.dispose();
}

double _calculateSubtotal() {
  double total = 0;
  for (var product in widget.products) {
    if (widget.cart.containsKey(product.skuCode)) {
      final qty = widget.cart[product.skuCode]!;
      final price = double.tryParse(product.tradePrice) ?? 0;
      total += qty * price;
    }
  }
  return total;
}

double _calculateDiscount() {
  final subtotal = _calculateSubtotal();
  final discountValue = double.tryParse(_discountController.text) ?? 0;

  if (_isDiscountPercentage) {
    return (subtotal * discountValue) / 100;
  } else {
    return discountValue;
  }
}

double _calculateTax() {
  final subtotal = _calculateSubtotal();
  final discount = _calculateDiscount();
  return (subtotal - discount) * 0.05; // 5% tax
}

double _calculateGrandTotal() {
  return _calculateSubtotal() - _calculateDiscount() + _calculateTax();
}

Future<List<Map<String, dynamic>>> _loadBanksFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final banksString = prefs.getString('banks');
  if (banksString == null) return [];
  final List<dynamic> banksList = jsonDecode(banksString);
  return banksList.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<void> _openBankPaymentPopup() async {
  final banks = await _loadBanksFromPrefs();
  String? selectedBankId;
  String? selectedBankName;
  final amountController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text("Select Bank & Amount"),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Bank",
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  menuMaxHeight: 300,
                  items: banks.map<DropdownMenuItem<String>>((bank) {
                    return DropdownMenuItem<String>(
                      value: bank['bankID'] as String,
                      child: Text(
                        bank['bankName'] as String,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    selectedBankId = val;
                    if (val != null) {
                      final match =
                      banks.firstWhere((b) => b['bankID'] == val);
                      selectedBankName = match['bankName'] as String?;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Amount",
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                setState(() {
                  _bankPayments.add({
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
}*/

  @override
  Widget build(BuildContext context) {
    final cartItems = widget.products
        .where((p) => widget.cart.containsKey(p.skuCode))
        .toList();
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount();
    final tax = _calculateTax();
    final grandTotal = _calculateGrandTotal();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Walk-in Header (like screenshot top)
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Walk-in',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Guest Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cart Items (horizontal scroll, compact cards)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final product = cartItems[index];
                  final qty = widget.cart[product.skuCode] ?? 1;
                  final price = double.tryParse(product.tradePrice ?? '0') ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _ProductCartCard(
                      product: product,
                      quantity: qty,
                      onQuantityChanged: (newQty) {
                        setState(() {
                          if (newQty == 0) {
                            widget.cart.remove(product.skuCode);
                          } else {
                            widget.cart[product.skuCode!] = newQty;
                          }
                        });
                        widget.onCartUpdate();
                      },
                      onRemove: () {
                        setState(() {
                          widget.cart.remove(product.skuCode);
                        });
                        widget.onCartUpdate();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Overall Discount
          _DiscountSection(
            controller: _discountController,
            isPercentage: _isDiscountPercentage,
            onToggle: () => setState(() => _isDiscountPercentage = !_isDiscountPercentage),
          ),
          const SizedBox(height: 20),

          // Summary
          _SummarySection(subtotal: subtotal, tax: tax, discount: discount, grandTotal: grandTotal),
          const SizedBox(height: 20),

        /*  // Bank Payments (if any)
          if (_bankPayments.isNotEmpty)
            _BankPaymentsSection(bankPayments: _bankPayments, onRemove: (bp) => setState(() => _bankPayments.remove(bp))),
          const SizedBox(height: 20),

          // Payment Method
          _PaymentMethodSection(
            selectedMethod: _selectedPaymentMethod,
            onChanged: (method) => setState(() => _selectedPaymentMethod = method),
          ),*/
          const SizedBox(height: 20),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: _openBankPaymentPopup,
                  icon: const Icon(Icons.account_balance, size: 28),
                  style: IconButton.styleFrom(backgroundColor: Colors.blue.shade50),
                  tooltip: 'Add Bank Payment',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {}, // Your draft logic
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Draft', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: cartItems.isEmpty || _isSubmitting ? null : _saveInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDB022),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                    )
                        : Text('Charge \$${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }




Future<void> _saveInvoice() async {
  setState(() => _isSubmitting = true);

  try {
    final prefs = await SharedPreferences.getInstance();
    final employeeID = prefs.getString('employeeID');
    final customerId = prefs.getString('walkInCustomerID') ?? '';

    final cartItems = widget.products
        .where((p) => widget.cart.containsKey(p.skuCode))
        .toList();

    String? bankID;
    double bankTotal = 0;
    for (final bp in _bankPayments) {
      bankID = bp['bankID'] as String?;
      bankTotal += (bp['amount'] as double?) ?? 0.0;
    }
    final cashAfterBank =
    (_calculateGrandTotal() - bankTotal).clamp(0, double.infinity);

    final payload = {
      "fK_Customer_ID": customerId,
      "fK_Employee_ID": employeeID,
      "deliveryAddress": "",
      "fK_StockLocation_ID": prefs.getString('stockLocationID') ?? '',
      "fK_InvoiceManagerMaster_ID": prefs.getString('invoiceManagerID') ?? '',
      "docDate": DateTime.now().toIso8601String(),
      if (bankID != null) ...{
        "fK_ChartOfAccounts_ID_Bank": bankID,
        "bankReceived": bankTotal,
      },
      "customerNamePOS": _nameController.text.trim(),
      "mobileNumber": _mobileController.text.trim(),
      "cashReceived": cashAfterBank,
      "creditDays": int.tryParse(_creditDaysController.text) ?? 0,
      "invoiceDetailsInp": cartItems.map((item) {
        final qty = widget.cart[item.skuCode]!;
        final rate = double.tryParse(item.tradePrice) ?? 0;
        final itemTotal = qty * rate;
        return {
          "id": "",
          "fK_ChartOfAccounts_ID": null,
          "fK_Sku_ID": item.id,
          "fK_SKUPacking_ID": item.defaultPackingID,
          "quantity": qty,
          "rate": rate,
          "amount": itemTotal,
          "discountPercentage": _isDiscountPercentage
              ? (double.tryParse(_discountController.text) ?? 0)
              : 0,
          "discountAmount": _isDiscountPercentage
              ? 0
              : (double.tryParse(_discountController.text) ?? 0),
          "totalAmount": itemTotal,
          "valueExclusiveTax": 0,
          "taxPercentage": 5,
          "taxAmount": 0,
          "valueInclusiveTax": 0,
          "freightCharges": 0,
          "notes":
          "Walk-in: ${_nameController.text.trim()} / ${_mobileController.text.trim()}",
          "batchNumber": "",
        };
      }).toList(),
      "invoiceGdnGrnDetailsInp": [],
    };

    // TODO: Call your API
    // final resp = await ApiService.finalizeInvoice(payload);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    // Clear cart on success
    setState(() {
      widget.cart.clear();
      _nameController.clear();
      _mobileController.clear();
      _creditDaysController.text = '000';
      _discountController.clear();
      _bankPayments.clear();
    });
    widget.onCartUpdate();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Invoice created successfully!'),
            backgroundColor: Colors.green),
      );
      // Navigate to print screen or back
      // Navigator.pop(context);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}
}

class _ProductCartCard extends StatelessWidget {
  final dynamic product; // Your Product model
  final int quantity;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const _ProductCartCard({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(product.tradePrice ?? '0') ?? 0;
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(product.name ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1),
                  Text('\$${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () => onQuantityChanged(quantity - 1),
                      ),
                      Text('$quantity', style: const TextStyle(fontSize: 13)),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () => onQuantityChanged(quantity + 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isPercentage;
  final VoidCallback onToggle;

  const _DiscountSection({required this.controller, required this.isPercentage, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overall Discount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF666666))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount or %',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isPercentage ? const Color(0xFFFDB022) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isRed;
  const _SummaryRow(this.label, this.value, {this.isRed = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(value, style: TextStyle(fontSize: 16, color: isRed ? Colors.red : null, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final double subtotal, tax, discount, grandTotal;

  const _SummarySection({required this.subtotal, required this.tax, required this.discount, required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Column(
          children: [
            _SummaryRow('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
            _SummaryRow('Tax (5%)', '\$${tax.toStringAsFixed(2)}'),
            _SummaryRow('Discount', '-\$${discount.toStringAsFixed(2)}', isRed: true),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('\$${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFDB022))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Add _SummaryRow, _PaymentMethodSection, _BankPaymentsSection similarly from previous response, reusing your PaymentMethodButton if exists.
// Keep all your existing methods (calculateSubtotal, saveInvoice, etc.) unchanged.



// ============================================================================
// REGISTERED CUSTOMER TAB
// ============================================================================
class RegisteredCustomerTab extends StatefulWidget {
  final Map<String, int> cart;
  final List<Product> products;
  final VoidCallback onCartUpdate;
  final String invoiceMgrId;

  const RegisteredCustomerTab({
    Key? key,
    required this.cart,
    required this.products,
    required this.onCartUpdate,
    required this.invoiceMgrId,
  }) : super(key: key);

  @override
  State<RegisteredCustomerTab> createState() => _RegisteredCustomerTabState();
}

class _RegisteredCustomerTabState extends State<RegisteredCustomerTab> {
  Customer? _selectedCustomer;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _creditDaysController =
  TextEditingController(text: '000');
  final TextEditingController _discountController = TextEditingController();

  String _selectedPaymentMethod = 'Cash';
  List<Map<String, dynamic>> _bankPayments = [];
  bool _isSubmitting = false;
  bool _isDiscountPercentage = true;

  @override
  void dispose() {
    _addressController.dispose();
    _creditDaysController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double _calculateSubtotal() {
    double total = 0;
    for (var product in widget.products) {
      if (widget.cart.containsKey(product.skuCode)) {
        final qty = widget.cart[product.skuCode]!;
        final price = double.tryParse(product.tradePrice) ?? 0;
        total += qty * price;
      }
    }
    return total;
  }

  double _calculateDiscount() {
    final subtotal = _calculateSubtotal();
    final discountValue = double.tryParse(_discountController.text) ?? 0;

    if (_isDiscountPercentage) {
      return (subtotal * discountValue) / 100;
    } else {
      return discountValue;
    }
  }

  double _calculateTax() {
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount();
    return (subtotal - discount) * 0.05;
  }

  double _calculateGrandTotal() {
    return _calculateSubtotal() - _calculateDiscount() + _calculateTax();
  }

  Future<List<Map<String, dynamic>>> _loadBanksFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final banksString = prefs.getString('banks');
    if (banksString == null) return [];
    final List<dynamic> banksList = jsonDecode(banksString);
    return banksList.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _openBankPaymentPopup() async {
    final banks = await _loadBanksFromPrefs();
    String? selectedBankId;
    String? selectedBankName;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text("Select Bank & Amount"),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Bank",
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    menuMaxHeight: 300,
                    items: banks.map<DropdownMenuItem<String>>((bank) {
                      return DropdownMenuItem<String>(
                        value: bank['bankID'] as String,
                        child: Text(
                          bank['bankName'] as String,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      selectedBankId = val;
                      if (val != null) {
                        final match =
                        banks.firstWhere((b) => b['bankID'] == val);
                        selectedBankName = match['bankName'] as String?;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  setState(() {
                    _bankPayments.add({
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

  @override
  Widget build(BuildContext context) {
    final cartItems = widget.products
        .where((p) => widget.cart.containsKey(p.skuCode))
        .toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Customer Selection Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedCustomer == null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDB022).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_search,
                            color: Color(0xFFFDB022), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Customer',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                      itemBuilder: (context, Customer customer, isSelected) =>
                          ListTile(
                            title: Text(customer.customerName),
                            subtitle: Text(customer.customerAddress),
                          ),
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: "Select Customer",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFFF8F8F8),
                      ),
                    ),
                    asyncItems: (String filter) async {
                      if (filter.length < 3) return [];
                      // TODO: Replace with your API call
                      // return await ApiService.fetchInvCustomers(widget.invoiceMgrId, filter);
                      return [];
                    },
                    itemAsString: (Customer u) => u.customerName,
                    selectedItem: _selectedCustomer,
                    onChanged: (Customer? customer) {
                      setState(() {
                        _selectedCustomer = customer;
                        _addressController.text =
                            customer?.customerAddress ?? '';
                      });
                    },
                  ),
                ] else ...[
                  // Selected customer display
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF2E7D32),
                        child: Text(
                          _selectedCustomer!.customerName[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCustomer!.customerName,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedCustomer!.id,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                              color: Colors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          setState(() => _selectedCustomer = null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Balance: ',
                            style: TextStyle(fontSize: 14)),
                        const Text(
                          'Rs. 450.00',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        ),
                        const Text(' (Due)',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Delivery Address',
                    hintText: 'Enter delivery address',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                  ),
                ),
                const SizedBox(height: 12),
                CreditDaysField(controller: _creditDaysController),
              ],
            ),
          ),

          // Cart Items Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CART ITEMS',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600]),
                    ),
                    Text(
                      '${cartItems.length} Items',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFDB022)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (cartItems.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('No items in cart',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ...cartItems.map((product) => ProductCartCard(
                    product: product,
                    quantity: widget.cart[product.skuCode]!,
                    onQuantityChanged: (newQty) {
                      setState(() {
                        if (newQty <= 0) {
                          widget.cart.remove(product.skuCode);
                        } else {
                          widget.cart[product.skuCode] = newQty;
                        }
                      });
                      widget.onCartUpdate();
                    },
                    onRemove: () {
                      setState(() => widget.cart.remove(product.skuCode));
                      widget.onCartUpdate();
                    },
                  )),
              ],
            ),
          ),

          // Overall Discount Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OVERALL DISCOUNT',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        decoration: InputDecoration(
                          labelText: 'Amount or %',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: const Color(0xFFF8F8F8),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isDiscountPercentage = !_isDiscountPercentage;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _isDiscountPercentage
                              ? const Color(0xFFFDB022)
                              : const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '%',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isDiscountPercentage
                                  ? Colors.black
                                  : Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_discountController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Discount: Rs. ${_calculateDiscount().toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Summary Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                SummaryRow('Subtotal', _calculateSubtotal()),
                SummaryRow('Tax (5%)', _calculateTax()),
                SummaryRow('Discount', _calculateDiscount(), isRed: true),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Rs. ${_calculateGrandTotal().toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDB022),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bank Payments Display
          if (_bankPayments.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance,
                          size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Bank Payments',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._bankPayments.map((bp) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(bp['bankName'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                        Row(
                          children: [
                            Text(
                              'Rs. ${(bp['amount'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                setState(() => _bankPayments.remove(bp));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),

          // Payment Method Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAYMENT METHOD',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PaymentMethodButton(
                        icon: Icons.money,
                        label: 'Cash',
                        isSelected: _selectedPaymentMethod == 'Cash',
                        onTap: () =>
                            setState(() => _selectedPaymentMethod = 'Cash'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PaymentMethodButton(
                        icon: Icons.credit_card,
                        label: 'Card',
                        isSelected: _selectedPaymentMethod == 'Card',
                        onTap: () =>
                            setState(() => _selectedPaymentMethod = 'Card'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PaymentMethodButton(
                        icon: Icons.qr_code,
                        label: 'QR Pay',
                        isSelected: _selectedPaymentMethod == 'QRPay',
                        onTap: () =>
                            setState(() => _selectedPaymentMethod = 'QRPay'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: _openBankPaymentPopup,
                  icon: const Icon(Icons.account_balance, size: 28),
                  tooltip: 'Add Bank Payment',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Save as draft logic
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text('Draft',
                        style: TextStyle(fontSize: 16, color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_selectedCustomer == null ||
                        cartItems.isEmpty ||
                        _isSubmitting)
                        ? null
                        : _saveInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDB022),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Save Invoice',
                            style: TextStyle(
                                fontSize: 16, color: Colors.black)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward,
                            size: 20, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInvoice() async {
    if (_selectedCustomer == null) return;

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeID = prefs.getString('employeeID');

      final cartItems = widget.products
          .where((p) => widget.cart.containsKey(p.skuCode))
          .toList();

      String? bankID;
      double bankTotal = 0;
      for (final bp in _bankPayments) {
        bankID = bp['bankID'] as String?;
        bankTotal += (bp['amount'] as double?) ?? 0.0;
      }
      final cashAfterBank =
      (_calculateGrandTotal() - bankTotal).clamp(0, double.infinity);

      final payload = {
        "fK_Customer_ID": _selectedCustomer!.id,
        "fK_Employee_ID": employeeID,
        "deliveryAddress": _addressController.text.trim(),
        "fK_StockLocation_ID": prefs.getString('stockLocationID') ?? '',
        "fK_InvoiceManagerMaster_ID":
        prefs.getString('invoiceManagerID') ?? '',
        "docDate": DateTime.now().toIso8601String(),
        if (bankID != null) ...{
          "fK_ChartOfAccounts_ID_Bank": bankID,
          "bankReceived": bankTotal,
        },
        "creditDays": int.tryParse(_creditDaysController.text) ?? 0,
        "cashReceived": cashAfterBank,
        "invoiceDetailsInp": cartItems.map((item) {
          final qty = widget.cart[item.skuCode]!;
          final rate = double.tryParse(item.tradePrice) ?? 0;
          final itemTotal = qty * rate;
          return {
            "id": "",
            "fK_ChartOfAccounts_ID": null,
            "fK_Sku_ID": item.id,
            "fK_SKUPacking_ID": item.defaultPackingID,
            "quantity": qty,
            "rate": rate,
            "amount": itemTotal,
            "discountPercentage": _isDiscountPercentage
                ? (double.tryParse(_discountController.text) ?? 0)
                : 0,
            "discountAmount": _isDiscountPercentage
                ? 0
                : (double.tryParse(_discountController.text) ?? 0),
            "totalAmount": itemTotal,
            "valueExclusiveTax": 0,
            "taxPercentage": 5,
            "taxAmount": 0,
            "valueInclusiveTax": 0,
            "freightCharges": 0,
            "notes":
            "Registered Customer: ${_selectedCustomer!.customerName}",
            "batchNumber": "",
          };
        }).toList(),
        "invoiceGdnGrnDetailsInp": [],
      };

      // TODO: Call your API service
      // final response = await ApiService.finalizeInvoice(payload);

      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invoice created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear cart
        setState(() {
          widget.cart.clear();
          _selectedCustomer = null;
          _addressController.clear();
          _creditDaysController.text = '000';
          _discountController.clear();
          _bankPayments.clear();
        });
        widget.onCartUpdate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}