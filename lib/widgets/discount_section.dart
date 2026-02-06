import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/dashed_rect.dart';

class DiscountSection extends StatelessWidget {
  final TextEditingController discountController;
  final bool isPercentDiscount;
  final VoidCallback onToggleDiscountType;
  final Function(String) onDiscountChanged;

  final double subtotal;
  final double totalTax;
  final double discount;
  final double grandTotal;

  const DiscountSection({
    super.key,
    required this.discountController,
    required this.isPercentDiscount,
    required this.onToggleDiscountType,
    required this.onDiscountChanged,
    required this.subtotal,
    required this.totalTax,
    required this.discount,
    required this.grandTotal,
  });

  @override
  Widget build(BuildContext context) {
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
            'OVERALL DISCOUNT',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.tabLabelBlueColor,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 16),

          /// Input Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: discountController,
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: isPercentDiscount ? 'Enter %' : 'Enter Amount',
                    hintStyle: TextStyle(color: AppColors.tabLabelBlueColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: onDiscountChanged,
                ),
              ),

              const SizedBox(width: 12),

              InkWell(
                onTap: onToggleDiscountType,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isPercentDiscount
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
                      color: isPercentDiscount ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// Totals
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.appBackgroundGreyColor),
              ),
            ),
            child: Column(
              children: [
                _buildTotalRow('Subtotal', subtotal, false),
                const SizedBox(height: 8),

                _buildTotalRow('Tax (18%)', totalTax, false),
                const SizedBox(height: 8),

                _buildTotalRow('Discount', discount, true, isDiscount: true),
                const SizedBox(height: 16),

                MySeparator(color: AppColors.lineGretColor),
                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black
                      ),
                    ),
                    Text(
                      'Rs ${grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                        color: AppColors.mainButtonsColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, bool bold,
      {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
              color: isDiscount ? Colors.green : AppColors.tabLabelBlueColor,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              fontSize: 16
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}Rs ${amount.toStringAsFixed(2)}',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDiscount ? Colors.green : Colors.black,
              fontSize: 16
          ),
        ),
      ],
    );
  }
}

