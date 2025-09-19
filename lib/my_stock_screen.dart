import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/Model/my_stock_model.dart';

import 'api_service.dart';

class MyStockScreen extends StatefulWidget {
  const MyStockScreen({super.key});

  @override
  _MyStockScreenState createState() {
    return _MyStockScreenState();
  }
}

class _MyStockScreenState extends State<MyStockScreen> {
  String managerIDSalesOrder = '';
  // filters
  DateTime? _fromDate;
  DateTime? _toDate;
  final _dateFmt = DateFormat('dd-MMM-yyyy');
  bool hasBalance = true;
  String _fmtDate(DateTime? d) => d == null ? '' : _dateFmt.format(d);
  // paging
  bool isLoading = false;
  bool hasMore = true;
  int page = 1;
  final int pageSize = 30;
  // data
  final List<MyStockModel> stockList = [];

  Future<void> _loadManagerID() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      managerIDSalesOrder = prefs.getString('stockLocationID')?.trim() ?? '';
    });
  }

  Future<void> _onLoadPressed() async {
    if ( _fromDate == null || _toDate == null) return;

    setState(() {
      page = 1;
      hasMore = true;
      stockList.clear();
    });
    await fetchData();
  }

  Future<void> _onRefresh() async {
    if ( _fromDate == null || _toDate == null) return;
    setState(() {
      page = 1;
      hasMore = true;
      stockList.clear();
    });
    await fetchData();
  }


  String formatNumber(double? value) {
    final formatter = NumberFormat('#,###');
    return formatter.format(value ?? 0);
  }

  Future<void> fetchData() async {
    if ( _fromDate == null || _toDate == null) return;

    setState(() => isLoading = true);
    try {
      final items = await ApiService.fetchMyStock(
        fromDate: _fromDate!.toIso8601String(),
        toDate: _toDate!.toIso8601String(),
        StockLocationID: managerIDSalesOrder,
        hasBalance: hasBalance,
      );
      setState(() {
        stockList.addAll(items);
        hasMore = items.length == pageSize;
        if (hasMore) page += 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ledger: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _fromDate = DateTime(picked.year, picked.month, picked.day);
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = _fromDate;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _toDate = DateTime(picked.year, picked.month, picked.day);
        if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
          _fromDate = _toDate;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadManagerID();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
   // final theme = Theme.of(context);
    final allowLoad = _fromDate != null && _toDate != null;

    return Scaffold(
      appBar: AppBar(title: const Text('My Stock')),
      body: Padding(
        padding: const EdgeInsets.only(left: 20,right: 20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickFromDate,
                    child: InputDecorator(
                      isEmpty: _fromDate == null,
                      decoration: const InputDecoration(
                        //labelText: 'From',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                          _fromDate == null ? 'Select From date' : _fmtDate(_fromDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickToDate,
                    child: InputDecorator(
                      isEmpty: _toDate == null,
                      decoration: const InputDecoration(
                        //labelText: 'To',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                          _toDate == null ? 'Select Till date' : _fmtDate(_toDate)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Show only items with Balance"),
              value: hasBalance,
              onChanged: (value) {
                setState(() {
                  hasBalance = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 20),
            // Load button on separate line
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: allowLoad ? _onLoadPressed : null,
                icon: const Icon(Icons.download),
                label: const Text('Load'),
              ),
            ),
            const SizedBox(height: 20),
            // ---- List ----
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.builder(
                 // padding: const EdgeInsets.all(12),
                  itemCount: stockList.length,
                  itemBuilder: (context, index) {
                    final item = stockList[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category
                            Text(
                              item.categoryName ?? "",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // SKU
                            Text(
                              item.skuName ?? "",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const Divider(height: 20, thickness: 1),
                            // Stock Info
                            _buildInfoRow(
                                Icons.login, "Opening", formatNumber(item.stockPOSShopOpening)),
                            _buildInfoRow(
                                Icons.arrow_downward, "Qty IN", formatNumber(item.stockPOSShopQtyIN)),
                            _buildInfoRow(
                                Icons.arrow_upward, "Qty OUT", formatNumber(item.stockPOSShopQtyOUT)),
                            _buildInfoRow(
                                Icons.inventory, "Balance", formatNumber(item.stockPOSShopBalance)),

                            const Divider(height: 20, thickness: 1),
                            // Grand Total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Grand Total:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  formatNumber(item.grandTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),


              ),
            ),

          ],
        ),
      ),
    );
  }
}

Widget _buildInfoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}
