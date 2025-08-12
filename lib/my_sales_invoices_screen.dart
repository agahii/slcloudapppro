import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'package:slcloudapppro/Model/MySalesInvoice.dart';
class MySalesInvoicesScreen extends StatefulWidget {
  const MySalesInvoicesScreen({super.key});

  @override
  State<MySalesInvoicesScreen> createState() => _MySalesInvoicesScreenState();
}

class _MySalesInvoicesScreenState extends State<MySalesInvoicesScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  final int pageSize = 20;

  String searchKey = "";

  final List<SalesInvoice> _invoices = [];

  String? _managerID = "";

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !isLoading &&
          hasMore) {
        _fetchInvoices();
      }
    });
  }

  Future<void> _bootstrap() async {

    final prefs = await SharedPreferences.getInstance();
    _managerID = prefs.getString('invoiceManagerID');
    _fetchInvoices(initial: true);
  }

  Future<void> _fetchInvoices({bool initial = false}) async {
    if (initial) {
      setState(() {
        currentPage = 1;
        hasMore = true;
        _invoices.clear();
      });
    }
    if (!hasMore) return;

    setState(() => isLoading = true);
    try {
      final list = await ApiService.fetchMySalesInvoices(
        managerID: _managerID ?? '',
        searchKey: searchKey,
        pageNumber: currentPage,
        pageSize: pageSize,
      );
      setState(() {
        _invoices.addAll(list);
        currentPage++;
        if (list.length < pageSize) hasMore = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load invoices: $e')),
      );
    }
    setState(() => isLoading = false);
  }

  Future<void> _refresh() async {
    await _fetchInvoices(initial: true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('My Sales Invoices')),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Invoice No / Customer...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchKey = "");
                    _fetchInvoices(initial: true);
                  },
                ),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                setState(() => searchKey = _searchController.text.trim());
                _fetchInvoices(initial: true);
              },
            ),
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _invoices.isEmpty && !isLoading
                  ? const Center(child: Text("No invoices found"))
                  : ListView.builder(
                controller: _scrollController,
                itemCount: _invoices.length + (isLoading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _invoices.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final inv = _invoices[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: ListTile(
                      onTap: () => _showInvoiceDetails(inv),
                      title: Text(
                        "Invoice #${inv.docNumber ?? '-'}",
                        style:
                        const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv.customerName ?? ""),
                          Text("Date: ${_fmtDate(inv.docDate ?? "")}"),
                          Text("Bank: ${inv.bankName ?? "-"}"),
                        ],
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Cash: ${inv.cashReceived ?? 0}"),
                          Text("Bank: ${inv.bankReceived ?? "0"}"),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showInvoiceDetails(SalesInvoice inv) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              "Invoice #${inv.docNumber ?? '-'}",
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text("Customer: ${inv.customerName ?? ""}"),
            Text("POS Name: ${inv.customerNamePOS ?? ""}"),
            Text("Mobile: ${inv.mobileNumber ?? ""}"),
            Text("Date: ${_fmtDate(inv.docDate ?? "")}"),
            Text("Cash Received: ${inv.cashReceived ?? 0}"),
            Text("Bank Received: ${inv.bankReceived ?? "0"}"),
            Text("Bank Name: ${inv.bankName ?? ""}"),
            const Divider(),
            Text("Items:"),
            Text(inv.itemsList ?? "—"),
          ],
        ),
      ),
    );
  }
}