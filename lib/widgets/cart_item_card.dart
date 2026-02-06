import 'package:flutter/material.dart';

import '../Model/Product.dart';
import '../api_service.dart';
import '../theme/app_colors.dart';
import '../utils/functions.dart';

class CartItemCard extends StatelessWidget {
  final Product item;
  final VoidCallback onDelete;
  final Function(int delta) onQuantityChange;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onDelete,
    required this.onQuantityChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.imageUrls!.isNotEmpty
                ? Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color:AppColors.appBackgroundGreyColor),
              ),
              child: Image.network(
                ApiService.imageBaseUrl + item.imageUrls!,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.skuName!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SKU: ${item.skuCode}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.brandName!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.mainButtonsColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Stock: ${item.stockInHand!.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: item.stockInHand! > 10
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          /*Text(
                            'Rs ${item.price.toStringAsFixed(2)} / unit',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),*/
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Rs ${item.tradePrice}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainButtonsColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Tax: ${item.taxPercentage} %',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  textAlign: TextAlign.end,
                  'Tax: Rs ${getProductTax(item).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tabLabelBlueColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  textAlign: TextAlign.end,
                  'Incl. Tax: Rs ${getProductPriceWithTax(item).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tabLabelBlueColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child:
                        InkWell(
                          onTap: () {
                            print("DELETE PRESSED");
                            onDelete();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.delete_outline,
                              size: 30,
                              color: AppColors.deleteRedColor,
                            ),
                          ),
                        ),

                    ),
                    Expanded(
                        flex: 8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildIconButton(
                              icon: Icons.remove,
                              color: Colors.grey.shade300,
                              onPressed: () => onQuantityChange( -1),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                    fontSize: 18
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildIconButton(
                              icon: Icons.add,
                              color: AppColors.mainButtonsColor,
                              onPressed: () => onQuantityChange(1),
                            ),
                          ],
                        )),

                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
