import 'dart:convert';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/print_invoice.dart';
import 'package:slcloudapppro/theme/app_colors.dart';
import 'package:slcloudapppro/utils/dialog_helper.dart';
import 'package:slcloudapppro/utils/functions.dart';
import 'package:slcloudapppro/widgets/cart_item_card.dart';
import 'package:slcloudapppro/widgets/discount_section.dart';
import 'package:slcloudapppro/widgets/payment_method_section.dart';
import 'package:slcloudapppro/widgets_page.dart';

import 'Model/Product.dart';
import 'Model/customer.dart';
import 'api_service.dart';

class RegisteredCustomerTab extends StatefulWidget {
  final Map<String, int> cart;
  final List<Product> products;
  final VoidCallback onCartUpdate;
  final String invoiceMgrId;
  final List<Map<String, dynamic>> fbrList ;

  const RegisteredCustomerTab({
    super.key,
    required this.cart,
    required this.products,
    required this.onCartUpdate,
    required this.invoiceMgrId,
    required this.fbrList,
  });

  @override
  State<RegisteredCustomerTab> createState() => _RegisteredCustomerTabState();
}

class _RegisteredCustomerTabState extends State<RegisteredCustomerTab> {
  Customer? _selectedCustomer;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _creditDaysController =
  TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  bool isWalkIn =  false;
  bool isSubmitting = false;
  List<Map<String, dynamic>> bankPayments = [];
  final Map<String, int> _cart = {};
  int qty = 1;
  String invoiceMgrId = '';


  bool isPercentDiscount = false;
  String selectedPayment = 'Cash';
  late List<Map<String, dynamic>> fbrScenario = [];
  String? selectedFbrId;
  String? selectedFbrName;


  // Sample cart items using your Product model
  List<Product> productsList = [];

  String _selectedPaymentMethod = 'Cash';
  List<Map<String, dynamic>> _bankPayments = [];
  bool _isSubmitting = false;
  bool _isDiscountPercentage = true;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    productsList = widget.products;
    _cart.addAll(widget.cart);
    invoiceMgrId = widget.invoiceMgrId;
    fbrScenario = widget.fbrList;

  }


  double get discount {
    double entered = double.tryParse(_discountController.text) ?? 0;

    if (isPercentDiscount) {
      double d = subtotal * (entered / 100);
      if (d > subtotal) return subtotal;
      return d;
    } else {
      if (entered > subtotal) return subtotal;
      return entered;
    }
  }

  void onDiscountChanged(String value) {
    double entered = double.tryParse(value) ?? 0;

    if (isPercentDiscount) {
      // Clamp percent to max 100
      if (entered > 100) {
        entered = 100;
        _discountController.text = "100";
        _discountController.selection = TextSelection.fromPosition(
          TextPosition(offset: _discountController.text.length),
        );
      }
    } else {
      // Clamp amount to max subtotal
      if (entered > subtotal) {
        entered = subtotal;
        _discountController.text = subtotal.toStringAsFixed(0);
        _discountController.selection = TextSelection.fromPosition(
          TextPosition(offset: _discountController.text.length),
        );
      }
    }

    setState(() {});
  }


  @override
  void dispose() {
    _addressController.dispose();
    _creditDaysController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void updateQuantity(String productId, int delta) {
    setState(() {
      final item = productsList.firstWhere((item) => item.id == productId);
      // Check stock availability
      final newQuantity = item.quantity! + delta;
      if (newQuantity > 0 && newQuantity <= item.stockInHand!) {
        item.quantity = newQuantity;
      } else if (newQuantity > item.stockInHand!) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Only ${item.stockInHand!.toInt()} items available in stock'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }


// Get total tax for all products in cart (with quantities)
  double get totalTax {
    return productsList.fold(0.0, (sum, item) {
      return sum + getProductTax(item);
    });
  }

// Get subtotal (all products without tax, with quantities)
  double get subtotal {
    return productsList.fold(0.0, (sum, item) {
      int quantity = item.quantity ?? 1;
      return sum + (double.parse(item.tradePrice!) * quantity);
    });
  }

  void removeItem(String productId) {
    setState(() {
      productsList.removeWhere((item) => item.id == productId);
    });
  }


  double get grandTotal {
    return subtotal + totalTax - discount;
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
          backgroundColor: Colors.white,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text("Select Bank & Amount",style: TextStyle(color: Colors.black),),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(8),
                      // border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonFormField<String>(
                      iconEnabledColor: AppColors.tabLabelBlueColor,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      decoration: const InputDecoration(
                        labelStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                        labelText: 'Bank',
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                      menuMaxHeight: 300,
                      items: banks.map<DropdownMenuItem<String>>((bank) {
                        return DropdownMenuItem<String>(
                          value: bank['bankID'] as String,
                          child: Text(
                            bank['bankName'] as String,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.black,),
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
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(8),
                      // border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: amountController,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        hintStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                        labelText: "Amount",
                        labelStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel" ,style: TextStyle(color: Colors.black),),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainButtonsColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
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
              child: const Text("Add",style: TextStyle(color: Colors.black),),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, ) {
    final cartItems = widget.products
        .where((p) => widget.cart.containsKey(p.skuCode))
        .toList();

    int customerBlnc =0 ;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Customer Selection Card
                    Container(
                      // margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedCustomer == null) ...[
                            const Text(
                              'SELECT CUSTOMER',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.tabLabelBlueColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9F9),
                                borderRadius: BorderRadius.circular(8),
                                // border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownSearch<Customer>(
                                popupProps: PopupProps.menu(
                                  menuProps: MenuProps(
                                    // The backgroundColor property of MenuStyle changes the popup background color
                                    backgroundColor: Colors.white, // <-- Set your desired color here
                                  ),
                                  showSearchBox: true,
                                  isFilterOnline: true,
                                  searchFieldProps: const TextFieldProps(
                                    style: TextStyle(color: Colors.black),
                                    decoration: InputDecoration(
                                      fillColor: const Color(0xFFF9F9F9),
                                      hintText: "🔍 Search customer...",
                                      hintStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  itemBuilder: (context, Customer customer, isSelected) => ListTile(
                                    title: Text(customer.customerName,style: TextStyle(color: Colors.black),),
                                    subtitle: Text(customer.customerAddress,style: TextStyle(color: Colors.black)),
                                  ),
                                ),
                                dropdownDecoratorProps: const DropDownDecoratorProps(
                                  baseStyle: TextStyle(color: Colors.black),
                                  dropdownSearchDecoration: InputDecoration(
                                    labelText: "Select Customer",
                                    labelStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                asyncItems: (String filter) async {
                                  if (filter.length < 3) return [];
                                  return ApiService.fetchInvCustomers(invoiceMgrId, filter);
                                },
                                itemAsString: (Customer u) => u.customerName,
                                selectedItem: _selectedCustomer,
                                onChanged: (Customer? customer) {
                                  _selectedCustomer = customer;
                                  _addressController.text = customer?.customerAddress ?? '';
                                  setState(() => customerBlnc = customer?.ledgerBalance ?? 0);
                                },
                              ),
                            ),
                          ] else ...[
                            // Selected customer display
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.mainButtonsColor,
                                  child: Text(
                                    _selectedCustomer!.customerName[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.black,
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
                                            color: Colors.black,
                                            fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.mainButtonsColor.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'VIP',
                                    style: TextStyle(
                                        color: AppColors.blackColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20,color: AppColors.mainButtonsColor,),
                                  onPressed: () {
                                    setState(() => _selectedCustomer = null);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.only(left: 50,top: 20,bottom: 20),
                              child: Row(
                                children: [
                                  Icon(Icons.account_balance_wallet,
                                      size: 18, color: AppColors.walletIconColor),
                                  const SizedBox(width: 8),
                                  Text('Balance: ',
                                      style: TextStyle(fontSize: 14,color: AppColors.walletIconColor)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$customerBlnc',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.deleteRedColor),
                                  ),
                                  const Text(' (Due)',
                                      style: TextStyle(fontSize: 12, color: AppColors.grey2Color)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: _addressController,
                            maxLines: 2,
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Delivery Address',
                              hintText: 'Enter delivery address',
                              hintStyle:  TextStyle(color: AppColors.tabLabelBlueColor),
                              labelStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: const Color(0xFFF8F8F8),
                            ),
                          ),
                          if (fbrScenario.length != 0) ...[
                            const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(8),
                              // border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonFormField<String>(
                              iconEnabledColor: AppColors.tabLabelBlueColor,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              decoration: const InputDecoration(
                                labelStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                                labelText: 'Select FBR Scenario',
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                              ),
                              menuMaxHeight: 300,
                              items: fbrScenario.map<DropdownMenuItem<String>>((fbr) {
                                return DropdownMenuItem<String>(
                                  value: fbr['id'] as String,
                                  child: Text(
                                    fbr['fbrScenarioName'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.black,),
                                    softWrap: false,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                selectedFbrId = val;
                                if (val != null) {
                                  final match =
                                  fbrScenario.firstWhere((b) => b['id'] == val);
                                  selectedFbrName = match['fbrScenarioName'] as String?;
                                }
                              },
                            ),
                          ),
                          ],
                          const SizedBox(height: 12),
                          CreditDaysField(controller: _creditDaysController),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    CartHeader(itemCount: cartItems.length),
                    const SizedBox(height: 20),
                    ...productsList.map((item) => CartItemCard(
                      item: item,
                      onDelete: () => removeItem(item.id!),
                      onQuantityChange: (delta) => updateQuantity(item.id!, delta),
                    )),

                    const SizedBox(height: 30),
                    DiscountSection(
                      discountController: _discountController,
                      isPercentDiscount: isPercentDiscount,
                      onToggleDiscountType: () {
                        setState(() {
                          isPercentDiscount = !isPercentDiscount;
                        });
                      },
                      onDiscountChanged: onDiscountChanged,
                      subtotal: subtotal,
                      totalTax: totalTax,
                      discount: discount,
                      grandTotal: grandTotal,
                    ),

                    const SizedBox(height: 30),
                   /* PaymentMethodSection(
                      selectedPayment: selectedPayment,
                      onPaymentSelected: (method) {
                        setState(() {
                          selectedPayment = method;
                        });
                      },
                    ),
                    const SizedBox(height: 30),*/
                    // Bank Payments Display
                    /*if (_bankPayments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          // border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'BANK PAYMENTS',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.tabLabelBlueColor,
                                    letterSpacing: 0.5,
                                  ),
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
                                      style: const TextStyle(fontSize: 15,color: Colors.black)),
                                  Row(
                                    children: [
                                      Text(
                                        'Rs. ${(bp['amount'] as double).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,color: Colors.black),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 20,color: AppColors.deleteRedColor),
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
                      ),*/
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    // Check if button should be enabled
    final bool isButtonEnabled = _selectedCustomer != null &&
        productsList.isNotEmpty &&
        !isSubmitting;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isButtonEnabled ? _saveInvoice : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isButtonEnabled
                    ? AppColors.mainButtonsColor
                    : Colors.grey[400],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: isButtonEnabled ? 2 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Charge Rs ${grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isButtonEnabled ? Colors.black : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: isButtonEnabled ? Colors.black : Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInvoice() async {
    // Validation checks with specific error messages
    if (_selectedCustomer == null) {
      DialogHelper.showErrorDialog(
        context,
        'Please select a customer before proceeding.',
      );
      return;
    }

    if (productsList.isEmpty) {
      DialogHelper.showErrorDialog(
        context,
        'Your cart is empty. Please add products first.',
      );
      return;
    }

    if (grandTotal <= 0) {
      DialogHelper.showErrorDialog(
        context,
        'Invalid invoice total amount.',
      );
      return;
    }

    // Show loading overlay
    DialogHelper.showLoadingOverlay(context);

    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeID = prefs.getString('employeeID');

      if (employeeID == null || employeeID.isEmpty) {
        if (!context.mounted) return;
        DialogHelper.closeDialog(context); // Close loading
        DialogHelper.showErrorDialog(
          context,
          'Employee ID not found. Please login again.',
        );
        return;
      }

      final cartItems = widget.products
          .where((p) => widget.cart.containsKey(p.skuCode))
          .toList();

      if (cartItems.isEmpty) {
        if (!context.mounted) return;
        DialogHelper.closeDialog(context); // Close loading
        DialogHelper.showErrorDialog(
          context,
          'No valid items in cart.',
        );
        return;
      }

      // Calculate bank payments
      String? bankID;
      double bankTotal = 0;
      for (final bp in _bankPayments) {
        bankID = bp['bankID'] as String?;
        bankTotal += (bp['amount'] as double?) ?? 0.0;
      }
      final double cashAfterBank =
      (grandTotal - bankTotal).clamp(0, double.infinity);

      // Build payload
      final payload = {
        "fK_Customer_ID": _selectedCustomer!.id,
        "fK_Employee_ID": employeeID,
        "deliveryAddress": _addressController.text.trim(),
        "fK_StockLocation_ID": prefs.getString('stockLocationID') ?? '',
        //"fK_FbrScenario_ID": selectedFbrId ?? '',
        "fK_InvoiceManagerMaster_ID": prefs.getString('invoiceManagerID') ?? '',
        "docDate": DateTime.now().toIso8601String(),
        if (bankID != null) ...{
          "fK_ChartOfAccounts_ID_Bank": bankID,
          "bankReceived": 0,//bankTotal,
        },
        "creditDays": int.tryParse(_creditDaysController.text) ?? 0,
        "cashReceived": 0,// cashAfterBank.toStringAsFixed(2),
        "invoiceDetailsInp": cartItems.map((item) {
          return {
            "id": "",
            "fK_ChartOfAccounts_ID": null,
            "fK_Sku_ID": item.id,
            "fK_SKUPacking_ID": item.defaultPackingID,
            "quantity": item.quantity,
            "rate": item.tradePrice!,
            "amount": item.tradePrice!,
            "discountPercentage": 0,
            "discountAmount": discount,
            "totalAmount": getProductPriceWithTax(item),
            "valueExclusiveTax": 0,
            "taxPercentage": item.taxPercentage,
            "taxAmount": getProductTax(item),
            "valueInclusiveTax": 0,
            "freightCharges": 0,
            "batchNumber": "",
            "notes": "Registered Customer: ${_selectedCustomer!.customerName}",
          };
        }).toList(),
        "invoiceGdnGrnDetailsInp": [],
      };

      // API call
      final resp = await ApiService.finalizeInvoice(payload);

      // Close loading overlay
      if (!context.mounted) return;
      DialogHelper.closeDialog(context);

      // Check HTTP status
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final msg = ApiService.extractServerMessage(resp);
        if (!context.mounted) return;
        DialogHelper.showErrorDialog(
          context,
          msg.isNotEmpty ? msg : 'Failed to create invoice. Please try again.',
        );
        return;
      }

      // Parse response
      Map<String, dynamic> invData;
      try {
        final body = jsonDecode(resp.body);
        final data = body['data'];

        if (data is! Map) {
          if (!context.mounted) return;
          DialogHelper.showErrorDialog(
            context,
            'Invalid response from server.',
          );
          return;
        }

        invData = Map<String, dynamic>.from(data as Map);
      } catch (e) {
        if (!context.mounted) return;
        DialogHelper.showErrorDialog(
          context,
          'Failed to process server response.',
        );
        return;
      }

      // Success - clear cart and navigate
      setState(() => productsList.clear());

      if (!context.mounted) return;

      // Navigate to print page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePrintPage(inv: invData),
        ),
      );
    } catch (e, st) {
      debugPrint('finalizeInvoice error: $e\n$st');

      // Close loading if still open
      if (context.mounted) {
        DialogHelper.closeDialog(context);
        DialogHelper.showErrorDialog(
          context,
          'An unexpected error occurred. Please check your connection and try again.',
        );
      }
    }
  }
}