
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'package:slcloudapppro/Model/SalesOrderItem.dart';
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
  String status = "Open"; // Open | Unapprove | Approved | Closed


  // data
  final List<SalesOrder> _orders = [];

  // identity
  String? _employeeID;
  String? _managerID = "";

  get itemBuilder => null; // keep same as your HomeScreen

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !isLoading &&
          hasMore) {
        _fetchOrders();
      }
    });
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _managerID = prefs.getString('salesPurchaseOrderManagerID');
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
        managerID: _managerID ?? '',
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
            ),
          ),

          // Filters (kept for future; visually helpful)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              spacing: 8,
              children: [
                _chip("Open"),
                _chip("Unapprove"),
                _chip("Approved"),
                _chip("Closed"),
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
                    final preview = (o.productDetails ?? '').trim();

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
                              // Doc Number chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Text(
                                  'Doc #${o.docNumber ?? '-'}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Order details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title row
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            "Order Details", // fixed title
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if ((o.areaName ?? '').isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              o.areaName!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    const SizedBox(height: 4),

                                    // Customer name
                                    Text(
                                      o.customerName ?? "Unknown Customer",
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    const SizedBox(height: 2),

                                    // Date + preview
                                    Row(
                                      children: [
                                        const Icon(Icons.event, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          _fmtDate(o.docDate ?? ""),
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 12),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.list_alt, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            preview.isEmpty ? '—' : preview,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.grey, fontSize: 12),
                                          ),
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
                  }

              ),
            ),
          )

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
      labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600),
      onSelected: (_) {
        setState(() => status = key);
        _fetchOrders(initial: true);
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side:
        BorderSide(color: isSelected ? color : const Color(0x1F000000)),
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
      backgroundColor: Colors.grey[50], // light grey instead of pure white
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final details = (order.productDetails ?? '').trim();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Title & Doc chip
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Order Details",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Doc #${order.docNumber ?? '-'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Customer name
              Text(
                order.customerName ?? "",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),

              // Date & Area
              Row(
                children: [
                  Text(
                    "Date: ${_fmtDate(order.docDate ?? "")}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if ((order.areaName ?? '').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.areaName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),

              // Delivery Address
              if ((order.deliveryAddress ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  "Delivery: ${order.deliveryAddress}",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade400),

              // Items
              Text(
                "Items",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                details.isEmpty ? '—' : details,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }





}