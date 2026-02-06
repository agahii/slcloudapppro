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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  bool isWalkIn =  false;
  bool isSubmitting = false;
  List<Map<String, dynamic>> _bankPayments = [];
  final Map<String, int> _cart = {};
  int qty = 1;


  bool isPercentDiscount = false;
  String selectedPayment = 'Cash';

  // Sample cart items using your Product model
  List<Product> productsList = [];
  String? selectedBankId;
  String? selectedBankName;
  final bankAmountController = TextEditingController();
  late bool isButtonEnabled ;

  late List<Map<String, dynamic>> banks = [];
  late List<Map<String, dynamic>> bfrScenario = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    productsList = widget.products;
    _cart.addAll(widget.cart);
    _loadBanksFromPrefs();
    banksList();
    fbrList();
    //qty = _cart[item.skuCode]!;
  }

  Future<void> banksList() async {
    banks = await _loadBanksFromPrefs();
  }

  Future<List<Map<String, dynamic>>> _loadBanksFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final banksString = prefs.getString('banks');
    if (banksString == null) return [];
    final List<dynamic> banksList = jsonDecode(banksString);
    return banksList.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> fbrList() async {
    bfrScenario = await _loadFbrFromPrefs();
  }

  Future<List<Map<String, dynamic>>> _loadFbrFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final fbrString = prefs.getString('allowedFbrScenario');
    if (fbrString == null) return [];
    final List<dynamic> fbrList = jsonDecode(fbrString);
    return fbrList.map((e) => Map<String, dynamic>.from(e)).toList();
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

  double get grandTotal {
    double baseTotal = subtotal + totalTax - discount;

    // If split payment, subtract bank amount from display
    if (selectedPayment == 'split') {
      double bankAmount = double.tryParse(bankAmountController.text) ?? 0;
      return baseTotal - bankAmount;
    }

    return baseTotal;
  }

/*  double get grandTotal {
    return subtotal + totalTax - discount;
  }*/

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildCustomerInfoSection(),
                    const SizedBox(height: 30),
                    CartHeader(itemCount: productsList.length),
                    const SizedBox(height: 20),
                    ...productsList.map((item) => CartItemCard(
                      item: item,
                      onDelete: () {
                        print("DELETE CLICKED: ${item.id}");
                        removeItem(item.id!);
                      },
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
                    PaymentMethodSection(
                      selectedPayment: selectedPayment,
                      onPaymentSelected: (method) {
                        setState(() {
                          selectedPayment = method;
                          selectedBankId = null;
                          selectedBankName = null;
                          isButtonEnabled = false;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // Bank Payments Display
                    if (selectedPayment != "Cash") ...[
                      //const SizedBox(height: 30),
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
                                    setState(() {
                                      isButtonEnabled = true;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (selectedPayment == 'split')
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9F9),
                                borderRadius: BorderRadius.circular(8),
                                // border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: TextField(
                                controller: bankAmountController,
                                keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  setState(() {
                                    // Validate bank amount
                                    double baseTotal = subtotal + totalTax - discount;
                                    double entered = double.tryParse(value) ?? 0;
                                    if (entered == baseTotal) {
                                      bankAmountController.text = baseTotal.toStringAsFixed(2);
                                      bankAmountController.selection = TextSelection.fromPosition(
                                        TextPosition(offset: bankAmountController.text.length),
                                      );
                                    }
                                  });
                                },
                                style: TextStyle(color: Colors.black),
                                decoration: const InputDecoration(
                                  hintStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                                  labelText: "Bank Received",
                                  labelStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
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


  Widget _buildCustomerInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WALK-IN CUSTOMER',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.tabLabelBlueColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(8),
              // border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                      hintText: 'Customer Name',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(8),
              // border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                      hintText: 'Phone Number',
                      border: InputBorder.none,
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


  // Replace your _buildActionButtons method with this:
  Widget _buildActionButtons() {
    // Check if button should be enabled based on payment method
    isButtonEnabled = productsList.isNotEmpty && !isSubmitting;

    // Additional validation for Card payment
    if (selectedPayment == 'Card' && selectedBankId == null) {
      isButtonEnabled = false;
    }

    // Additional validation for Split payment
    if (selectedPayment == 'split') {
      final bankAmount = double.tryParse(bankAmountController.text) ?? 0;
      if (selectedBankId == null || bankAmount <= 0) {
        isButtonEnabled = false;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isButtonEnabled ? _saveInvoice : null,
             // onPressed: isButtonEnabled ? _showPaymentSummary : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isButtonEnabled
                    ? AppColors.mainButtonsColor
                    : Colors.grey[300],
                foregroundColor: isButtonEnabled ? Colors.black : Colors.grey[500],
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
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

  /*Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed:(
                  productsList.isEmpty ||
                      isSubmitting)
                  ? null
                  : _saveInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainButtonsColor,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
                  :  Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Charge Rs ${grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,

                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward,
                      size: 20, color: Colors.black),
                ],
              ),


            ),
          ),
        ],
      ),
    );
  }*/

  Future<void> _saveInvoice() async {
    // Validation checks
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

    // Validate payment method specific requirements
    if (selectedPayment == 'Card') {
      if (selectedBankId == null || selectedBankId!.isEmpty) {
        DialogHelper.showErrorDialog(
          context,
          'Please select a bank for card payment.',
        );
        return;
      }
    }

    if (selectedPayment == 'split') {
      if (selectedBankId == null || selectedBankId!.isEmpty) {
        DialogHelper.showErrorDialog(
          context,
          'Please select a bank for split payment.',
        );
        return;
      }

      final bankAmount = double.tryParse(bankAmountController.text) ?? 0;
      if (bankAmount <= 0) {
        DialogHelper.showErrorDialog(
          context,
          'Please enter a valid bank amount.',
        );
        return;
      }

      /*if (bankAmount > grandTotal) {
        DialogHelper.showErrorDialog(
          context,
          'Bank amount cannot exceed grand total (Rs ${grandTotal.toStringAsFixed(2)}).',
        );
        return;
      }*/
    }

    // Show loading overlay
    DialogHelper.showLoadingOverlay(
      context,
      title: 'Creating Invoice...',
      subtitle: 'Please wait',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('walkInCustomerID');
      final employeeID = prefs.getString('employeeID');

      if (employeeID == null || employeeID.isEmpty) {
        if (!context.mounted) return;
        DialogHelper.closeDialog(context);
        DialogHelper.showErrorDialog(
          context,
          'Employee ID not found. Please login again.',
        );
        return;
      }

      if (customerId == null || customerId.isEmpty) {
        if (!context.mounted) return;
        DialogHelper.closeDialog(context);
        DialogHelper.showErrorDialog(
          context,
          'Walk-in customer ID not found.',
        );
        return;
      }

      final cartItems = productsList.where((p) => _cart.containsKey(p.skuCode)).toList();

      if (cartItems.isEmpty) {
        if (!context.mounted) return;
        DialogHelper.closeDialog(context);
        DialogHelper.showErrorDialog(
          context,
          'No valid items in cart.',
        );
        return;
      }

      // Calculate payment amounts based on selected method
      String? bankID;
      double bankTotal = 0.0;
      double cashTotal = 0.0;

      if (selectedPayment == 'Cash') {
        // Cash only - no bank payment
        cashTotal = grandTotal;
      } else if (selectedPayment == 'Card') {
        // Card only - full amount to bank
        bankID = selectedBankId;
        bankTotal = grandTotal;
        cashTotal = 0.0;
      } else if (selectedPayment == 'split') {
        // Split payment
        bankID = selectedBankId;
        bankTotal = double.tryParse(bankAmountController.text) ?? 0;
        cashTotal = grandTotal;
      }

      // Build payload
      final payload = {
        "fK_Customer_ID": customerId,
        "fK_Employee_ID": employeeID,
        "deliveryAddress": '',
        "fK_StockLocation_ID": prefs.getString('stockLocationID') ?? '',
        "fK_InvoiceManagerMaster_ID": prefs.getString('invoiceManagerID') ?? '',
        "docDate": DateTime.now().toIso8601String(),
        if (bankID != null && bankTotal > 0) ...{
          "fK_ChartOfAccounts_ID_Bank": bankID,
          "bankReceived": bankTotal,
        },
        "customerNamePOS": _nameController.text.trim(),
        "mobileNumber": _phoneController.text.trim(),
        "cashReceived": cashTotal.toStringAsFixed(2),
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
            "notes": "Walk-in: ${_nameController.text.trim()} / ${_phoneController.text.trim()}",
            "batchNumber": "",
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
      setState(() {
        productsList.clear();
        _nameController.clear();
        _phoneController.clear();
        _discountController.clear();
        bankAmountController.clear();
        selectedBankId = null;
        selectedBankName = null;
        selectedPayment = 'Cash';
      });

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

// OPTIONAL: Add this helper method to show payment summary before saving
  Future<void> _showPaymentSummary() async {
    String paymentDetails = '';

    if (selectedPayment == 'Cash') {
      paymentDetails = 'Cash: Rs ${grandTotal.toStringAsFixed(2)}';
    } else if (selectedPayment == 'Card') {
      paymentDetails = 'Card ($selectedBankName): Rs ${grandTotal.toStringAsFixed(2)}';
    } else if (selectedPayment == 'split') {
      final bankAmount = double.tryParse(bankAmountController.text) ?? 0;
      final cashAmount = grandTotal - bankAmount;
      paymentDetails = 'Bank ($selectedBankName): Rs ${bankAmount.toStringAsFixed(2)}\nCash: Rs ${cashAmount.toStringAsFixed(2)}';
    }

    final confirmed = await DialogHelper.showConfirmationDialog(
      context,
      'Payment Method:\n$paymentDetails\n\nTotal: Rs ${grandTotal.toStringAsFixed(2)}',
      title: 'Confirm Payment',
      confirmText: 'Proceed',
      cancelText: 'Cancel',
    );

    if (confirmed) {
      _saveInvoice();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _discountController.dispose();
    super.dispose();
  }
}