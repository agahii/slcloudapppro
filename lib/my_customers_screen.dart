// my_customers_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/utils/location_helper.dart';

import 'api_service.dart';
import 'Model/customer_lite.dart';

class MyCustomersScreen extends StatefulWidget {
  final String? managerIDInvoice;
  final String? managerIDPO;

  const MyCustomersScreen({
    super.key,
    this.managerIDInvoice,
    this.managerIDPO,
  });

  @override
  State<MyCustomersScreen> createState() => _MyCustomersScreenState();
}

class _MyCustomersScreenState extends State<MyCustomersScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Set<String> _loggingCustomerIds = {}; // track rows currently logging
  // IDs
  String _mgrInvoice = "";
  String _mgrPO = "";

  // Search
  Timer? _debounce;
  String _searchKey = "";

  // Paging
  static const int _defaultPageSize = 20;
  int _pageNumber = 1;                  // 1-based (matches your sample)
  final int _pageSize = _defaultPageSize;
  bool _initialLoading = false;         // first page loading
  bool _loadingMore = false;            // next pages loading
  bool _hasMore = true;                 // more pages available?

  // Data
  final List<CustomerLite> _items = [];

  @override
  void initState() {
    super.initState();
    _boot();
    _search.addListener(_onSearchChanged);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchChanged);
    _scroll.removeListener(_onScroll);
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    _mgrInvoice = widget.managerIDInvoice ?? (prefs.getString('invoiceManagerID') ?? '');
    _mgrPO = widget.managerIDPO ?? (prefs.getString('salesPurchaseOrderManagerID') ?? '');

    if (!mounted) return;
    setState(() {
      _pageNumber = 1;
      _items.clear();
      _hasMore = true;
      _initialLoading = true;
    });

    await _fetchPage(reset: true);
  }

  // Debounce search
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _searchKey = _search.text.trim();
      _resetAndSearch();
    });
  }

  Future<void> _resetAndSearch() async {
    setState(() {
      _pageNumber = 1;
      _items.clear();
      _hasMore = true;
      _initialLoading = true;
    });
    await _fetchPage(reset: true);
  }

  // Pull to refresh
  Future<void> _refresh() async {
    _searchKey = _search.text.trim();
    setState(() {
      _pageNumber = 1;
      _items.clear();
      _hasMore = true;
      _initialLoading = true;
    });
    await _fetchPage(reset: true);
  }

  // Infinite scroll trigger
  void _onScroll() {
    if (!_hasMore || _loadingMore || _initialLoading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _pageNumber += 1;
    await _fetchPage(reset: false);
  }

  Future<void> _fetchPage({required bool reset}) async {
    if (_mgrInvoice.isEmpty && _mgrPO.isEmpty) {
      // No IDs available — show banner and stop.
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _hasMore = false;
      });
      return;
    }

    try {
      final page = await ApiService.getCustomersPaged(
        managerIDInvoice: _mgrInvoice,
        managerIDPO: _mgrPO,
        searchKey: _searchKey,
        pageNumber: _pageNumber,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _items.clear();
        }
        _items.addAll(page.items);
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load customers: $e")),
      );
      // On failure, don’t advance pageNumber further.
      if (!reset) {
        _pageNumber = (_pageNumber > 1) ? _pageNumber - 1 : 1;
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
      });
    }
  }








  Future<void> _logVisit(CustomerLite c) async {
    if (_loggingCustomerIds.contains(c.id)) return;

    setState(() => _loggingCustomerIds.add(c.id));
    try {
      // 1) Get GPS
      final pos = await LocationHelper.getCurrentPosition();

      // 2) PUT geo-tag with exact payload
      await ApiService.addCustomerGeoTag(
        id: c.id,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return;

      // 3) Feedback (+ optional open maps)
      final mapsUrl = "https://www.google.com/maps?q=${pos.latitude},${pos.longitude}";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Visit geo-tagged for ${c.customer}."),
          action: SnackBarAction(
            label: "Open Map",
            onPressed: () {
              // optional: open maps via url_launcher if added
              // launchUrl(Uri.parse(mapsUrl), mode: LaunchMode.externalApplication);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to Tag: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loggingCustomerIds.remove(c.id));
    }
  }


  Future<void> _confirmLogVisit(BuildContext context, CustomerLite c) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Tagging'),
          content: Text('Do you want to Tag location for "${c.customer}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _logVisit(c);
    }
  }



  void _showCustomerDetail(BuildContext context, CustomerLite c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  c.customerName,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if ((c.area ?? '').isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.area!,
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                if ((c.customerAddress ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.customerAddress!,
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
                if ((c.employee ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.employee!,
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogVisit(context, c),
                    icon: const Icon(Icons.pin_drop_outlined),
                    label: const Text("Log Visit"),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }









  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canQuery = _mgrInvoice.isNotEmpty || _mgrPO.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('My Customers')),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search customers by name, code, or area...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _search.clear();
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
            ),
          ),

          if (!canQuery)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _MissingIdsBanner(onFix: _boot),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _initialLoading && _items.isEmpty
                  ? const _LoadingList()
                  : ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                itemBuilder: (ctx, i) {
                  if (i >= _items.length) {
                    // Footer loader
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final c = _items[i];
                  return ListTile(
                    leading: _Avatar(initials: _initials(c.customer)),
                    title: Text(
                      c.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((c.area ?? '').isNotEmpty) Text("Area: ${c.area}"),
                        if ((c.customerAddress ?? '').isNotEmpty)
                          Text(
                            c.customerAddress!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Log Visit button
                        _loggingCustomerIds.contains(c.id)
                            ? const SizedBox(
                            width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                          icon: const Icon(Icons.pin_drop_outlined),
                          tooltip: 'Log Visit',
                          onPressed: () => _confirmLogVisit(context, c),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),

                    onTap: () {
                      _showCustomerDetail(context, c);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return "?";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].isNotEmpty ? parts[0][0] : '').toUpperCase() +
        (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '').toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(child: Text(initials));
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 8,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
      itemBuilder: (_, __) => const ListTile(
        leading: CircleAvatar(),
        title: _ShimmerBar(width: 160),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBar(width: 220),
            SizedBox(height: 6),
            _ShimmerBar(width: 120),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  const _ShimmerBar({required this.width});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      width: width,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _MissingIdsBanner extends StatelessWidget {
  final VoidCallback onFix;
  const _MissingIdsBanner({required this.onFix});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Manager IDs are missing'),
        subtitle: const Text('Set ManagerIDInvoice / ManagerIDPO to fetch customers.'),
        trailing: TextButton(onPressed: onFix, child: const Text('Retry')),
      ),
    );
  }
}
