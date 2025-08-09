import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class MySalesOrdersScreen extends StatefulWidget {
  const MySalesOrdersScreen({super.key});

  @override
  State<MySalesOrdersScreen> createState() => _MySalesOrdersScreenState();
}

class _MySalesOrdersScreenState extends State<MySalesOrdersScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  // paging
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  final int pageSize = 20;

  // filters
  String searchKey = "";
  String status = "ALL"; // ALL | OPEN | CLOSED

  // data
  final List<SalesOrder> _orders = [];

  // identity
  String? _employeeID;
  String? _managerID = "59ed026d-1764-4616-9387-6ab6676b6667"; // keep same as your HomeScreen

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
          !isLoading && hasMore) {
        _fetchOrders();
      }
    });
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _employeeID = prefs.getString('employeeID');
    _fetchOrders(initial: true);
  }

  Future<void> _fetchOrders({bool initial = false}) async {
    if (initial) {
      setState(() {
        currentPage = 1;
        hasMore = true;
        _orders.clear();
      });
    }
    if (!hasMore) return;

    setState(() => isLoading = true);
    try {
      final list = await ApiService.fetchMySalesOrders(
        managerID: _managerID,
        employeeID: _employeeID,
        page: currentPage,
        pageSize: pageSize,
        searchKey: searchKey,
        status: status, // "ALL" | "OPEN" | "CLOSED"
      );
      setState(() {
        _orders.addAll(list);
        currentPage++;
        if (list.length < pageSize) hasMore = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load orders: $e')),
      );
    }
    setState(() => isLoading = false);
  }

  Future<void> _refresh() async {
    await _fetchOrders(initial: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
    } catch (_) {
      return iso;
    }
  }

  Color _statusColor(bool isClosed) => isClosed ? Colors.blue : Colors.orange;
  String _statusText(bool isClosed) => isClosed ? "Closed" : "Open";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My Sales Orders')),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Order No / Customer...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchKey = "");
                    _fetchOrders(initial: true);
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                setState(() => searchKey = _searchController.text.trim());
                _fetchOrders(initial: true);
              },
              onChanged: (v) {
                // small debounce not strictly needed
              },
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              spacing: 8,
              children: [
                _chip("ALL"),
                _chip("OPEN"),
                _chip("CLOSED"),
              ],
            ),
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _orders.isEmpty && !isLoading
                  ? const Center(child: Text("No orders found"))
                  : ListView.builder(
                controller: _scrollController,
                itemCount: _orders.length + (isLoading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _orders.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final o = _orders[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showOrderDetails(o),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(o.isClosed).withOpacity(.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _statusColor(o.isClosed)),
                              ),
                              child: Text(
                                _statusText(o.isClosed),
                                style: TextStyle(
                                  color: _statusColor(o.isClosed),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          o.orderNo ?? "—",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "Rs. ${o.grandTotal.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    o.customerName ?? "Unknown Customer",
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.event, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        _fmtDate(o.docDate ?? ""),
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.list_alt, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${o.items.length} item(s)",
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String key) {
    final isSelected = status == key;
    final color = Theme.of(context).colorScheme.primary;
    return ChoiceChip(
      label: Text(key),
      selected: isSelected,
      selectedColor: color,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
      onSelected: (_) {
        setState(() => status = key);
        _fetchOrders(initial: true);
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? color : const Color(0x1F000000)),
      ),
      backgroundColor: const Color(0xFFEAEAEA),
    );
  }

  void _showOrderDetails(SalesOrder order) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0x22000000),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNo ?? "Order",
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (order.isClosed ? Colors.blue : Colors.orange).withOpacity(.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: order.isClosed ? Colors.blue : Colors.orange),
                    ),
                    child: Text(
                      order.isClosed ? "Closed" : "Open",
                      style: TextStyle(
                        color: order.isClosed ? Colors.blue[800] : Colors.orange[800],
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  order.customerName ?? "",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Date: ${_fmtDate(order.docDate ?? "")}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Items", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: order.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = order.items[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(it.skuName ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text("Qty: ${it.quantity} × Rs. ${it.rate.toStringAsFixed(2)}"),
                      trailing: Text(
                        "Rs. ${(it.quantity * it.rate).toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                children: [
                  const Spacer(),
                  const Text("Grand Total: ",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                  Text("Rs. ${order.grandTotal.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/* -------------------- Simple Data Models -------------------- */

class SalesOrder {
  final String? id;
  final String? orderNo;
  final String? docDate; // ISO string
  final String? customerName;
  final bool isClosed;
  final double grandTotal;
  final List<SalesOrderItem> items;

  SalesOrder({
    required this.id,
    required this.orderNo,
    required this.docDate,
    required this.customerName,
    required this.isClosed,
    required this.grandTotal,
    required this.items,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> j) {
    // Try to be defensive about possible API field names
    final itemsJson = (j['details'] ?? j['purchaseSalesOrderDetailsVM'] ?? j['items'] ?? []) as List<dynamic>;
    return SalesOrder(
      id: j['id']?.toString(),
      orderNo: j['orderNo']?.toString() ?? j['documentNo']?.toString(),
      docDate: j['docDate']?.toString() ?? j['orderDate']?.toString(),
      customerName: j['customerName']?.toString() ?? j['customer']?['customerName']?.toString(),
      isClosed: (j['isClosed'] ?? j['closed'] ?? false) == true,
      grandTotal: _toDouble(j['grandTotal'] ?? j['totalAmount'] ?? j['netAmount'] ?? 0),
      items: itemsJson.map((e) => SalesOrderItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class SalesOrderItem {
  final String? skuName;
  final int quantity;
  final double rate;

  SalesOrderItem({
    required this.skuName,
    required this.quantity,
    required this.rate,
  });

  factory SalesOrderItem.fromJson(Map<String, dynamic> j) {
    return SalesOrderItem(
      skuName: j['skuName']?.toString() ?? j['itemName']?.toString(),
      quantity: int.tryParse((j['quantity'] ?? j['qty'] ?? 0).toString()) ?? 0,
      rate: SalesOrder._toDouble(j['agreedRate'] ?? j['rate'] ?? j['unitPrice'] ?? 0),
    );
  }
}
