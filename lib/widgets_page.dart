import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Model/Product.dart';

// ============================================================================
// PRODUCT CART CARD COMPONENT
// ============================================================================
class ProductCartCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const ProductCartCard({
    Key? key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(product.tradePrice) ?? 0;
    final total = price * quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              image: product.imageUrls != null
                  ? DecorationImage(
                image: NetworkImage(product.imageUrls!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: product.imageUrls == null
                ? const Icon(Icons.inventory_2, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.skuName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${quantity}x Rs. ${price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Quantity Controls
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18, color: Colors.red),
                  onPressed: () => onQuantityChanged(quantity - 1),
                  padding: EdgeInsets.zero,
                  constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$quantity',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add,
                      size: 18, color: Color(0xFFFDB022)),
                  onPressed: () => onQuantityChanged(quantity + 1),
                  padding: EdgeInsets.zero,
                  constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Total Price & Remove Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${total.toStringAsFixed(2)}',
                style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: onRemove,
                child:
                const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CREDIT DAYS FIELD COMPONENT
// ============================================================================
class CreditDaysField extends StatelessWidget {
  final TextEditingController controller;

  const CreditDaysField({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
        CreditDaysFormatter(),
      ],
      decoration: InputDecoration(
        labelText: 'Credit Days',
        hintText: '000',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        prefixIcon: const Icon(Icons.calendar_today, size: 20),
        helperText: 'Enter 0-999 (format: 001, 010, 100)',
        helperStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}

// Custom formatter for Credit Days field
class CreditDaysFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '000');
    }

    final num = int.tryParse(newValue.text) ?? 0;
    if (num > 999) {
      return oldValue;
    }

    final formatted = num.toString().padLeft(3, '0');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ============================================================================
// PAYMENT METHOD BUTTON COMPONENT
// ============================================================================
class PaymentMethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool highlight;

  const PaymentMethodButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.highlight = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (highlight ? const Color(0xFFFDB022) : Colors.blue.shade50)
              : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (highlight ? const Color(0xFFFDB022) : Colors.blue)
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? (highlight ? Colors.black : Colors.blue)
                  : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? (highlight ? Colors.black : Colors.blue)
                    : Colors.grey,
              ),
            ),
            if (highlight && isSelected) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Paid',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SUMMARY ROW COMPONENT
// ============================================================================
class SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isRed;
  final bool isBold;

  const SummaryRow(
      this.label,
      this.amount, {
        Key? key,
        this.isRed = false,
        this.isBold = false,
      }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? Colors.black : Colors.grey,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isRed ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARD CONTAINER WIDGET
// ============================================================================
class CardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const CardContainer({
    Key? key,
    required this.child,
    this.margin,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      padding: padding ?? const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

// ============================================================================
// SECTION HEADER WIDGET
// ============================================================================
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? icon;

  const SectionHeader({
    Key? key,
    required this.title,
    this.trailing,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFDB022).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFDB022), size: 20),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: icon != null ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ============================================================================
// EMPTY STATE WIDGET
// ============================================================================
class EmptyCartWidget extends StatelessWidget {
  final String message;

  const EmptyCartWidget({
    Key? key,
    this.message = 'No items in cart',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================
/*class Product {
  final String id;
  final String skuCode;
  final String skuName;
  final String tradePrice;
  final String defaultPackingID;
  final String? imageUrl;

  Product({
    required this.id,
    required this.skuCode,
    required this.skuName,
    required this.tradePrice,
    required this.defaultPackingID,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      skuCode: json['skuCode'] ?? '',
      skuName: json['skuName'] ?? '',
      tradePrice: json['tradePrice'] ?? '0',
      defaultPackingID: json['defaultPackingID'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }
}*/

class Customer {
  final String id;
  final String customerName;
  final String customerAddress;
  final String? mobileNumber;
  final String? balance;
  final bool isVIP;

  Customer({
    required this.id,
    required this.customerName,
    required this.customerAddress,
    this.mobileNumber,
    this.balance,
    this.isVIP = false,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      customerName: json['customerName'] ?? '',
      customerAddress: json['customerAddress'] ?? '',
      mobileNumber: json['mobileNumber'],
      balance: json['balance'],
      isVIP: json['isVIP'] ?? false,
    );
  }
}