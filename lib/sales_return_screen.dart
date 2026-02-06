import 'package:flutter/material.dart';
import 'package:slcloudapppro/theme/app_colors.dart';
import 'Model/Product.dart';
import 'Model/product_return_item.dart';
import 'widgets/return_widgets.dart';

class SalesReturnPage extends StatefulWidget {
  final String invoiceNumber;
  final List<Product> items;

  const SalesReturnPage({
    Key? key,
    required this.invoiceNumber,
    required this.items,
  }) : super(key: key);

  @override
  State<SalesReturnPage> createState() => _SalesReturnPageState();
}

class _SalesReturnPageState extends State<SalesReturnPage> {
  bool returnAllItems = false;
  late List<ProductReturnItem> items;

  @override
  void initState() {
    super.initState();
    // Convert Product list to ProductReturnItem list
    items = widget.items.map((products) {
      return ProductReturnItem(
        product: products,
        returnQuantity: 0,
        isSelected: false,
      );
    }).toList();
  }

  double get totalRefundAmount {
    return items.fold(0.0, (sum, item) {
      if (item.isSelected) {
        return sum + (item.product.price * item.returnQuantity);
      }
      return sum;
    });
  }

  void toggleReturnAll(bool? value) {
    setState(() {
      returnAllItems = value ?? false;
      for (var item in items) {
        item.isSelected = returnAllItems;
        if (returnAllItems) {
          item.returnQuantity = item.product.quantity ?? 1;
        } else {
          item.returnQuantity = 0;
        }
      }
    });
  }

  void toggleItemSelection(int index, bool? value) {
    setState(() {
      items[index].isSelected = value ?? false;
      if (!items[index].isSelected) {
        items[index].returnQuantity = 0;
        returnAllItems = false;
      } else if (items[index].returnQuantity == 0) {
        items[index].returnQuantity = 1;
      }
    });
  }

  void updateQuantity(int index, int change) {
    setState(() {
      final newQuantity = items[index].returnQuantity + change;
      final maxQuantity = items[index].product.quantity ?? 1;
      if (newQuantity >= 0 && newQuantity <= maxQuantity) {
        items[index].returnQuantity = newQuantity;
        items[index].isSelected = newQuantity > 0;
      }
    });
  }

  void processReturn() {
    // Implement your return processing logic here
    final selectedItems = items.where((item) => item.isSelected).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Return'),
        content: Text(
          'Processing return for ${selectedItems.length} item(s)\n'
              'Total Refund: \$${totalRefundAmount.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Add your processing logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Return processed successfully')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackgroundGreyColor,
      appBar: AppBar(
        backgroundColor: AppColors.mainButtonsColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sales Return',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search/Invoice Number Section
          const SizedBox(height: 8),

          // Return All Items Toggle
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ReturnAllToggle(
              value: returnAllItems,
              onChanged: toggleReturnAll,
            ),
          ),

          const SizedBox(height: 8),

          // Invoice Items List
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Text(
                      'INVOICE ITEMS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return ReturnItemTile(
                          item: items[index],
                          onCheckChanged: (value) => toggleItemSelection(index, value),
                          onDecrement: () => updateQuantity(index, -1),
                          onIncrement: () => updateQuantity(index, 1),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Section with Total and Button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TotalRefundSection(amount: totalRefundAmount),
                const SizedBox(height: 12),
                ProcessReturnButton(onPressed: processReturn),
              ],
            ),
          ),
        ],
      ),
    );
  }
}