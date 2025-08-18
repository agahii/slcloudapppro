import 'dart:async';

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
  Timer? _debounce;
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




  Future<void> _onReturnPressed(SalesInvoice inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Invoice Return'),
        content: Text('Return Invoice #${inv.docNumber ?? "-"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Option A: Navigate to a return screen (recommended)
    Navigator.pushNamed(
      context,
      '/invoiceReturn',
      arguments: {
        'invoiceId': inv.id,
        'docNumber': inv.docNumber,
        'customerName': inv.customerName,
        'docDate': inv.docDate,
        'itemsList': inv.itemsList,
      },
    );

    // Option B (alternative): Call an API directly here to create a return
    // try {
    //   await ApiService.createInvoiceReturn(invoiceId: inv.id!);
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Return created successfully')),
    //   );
    //   _refresh(); // reload list if needed
    // } catch (e) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Failed: $e')),
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My Sales Invoices')),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
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
                    _debounce?.cancel();
                    setState(() => searchKey = "");
                    _fetchInvoices(initial: true);
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (value) {
                // cancel old timer
                if (_debounce?.isActive ?? false) _debounce!.cancel();

                // wait 800ms after user stops typing
                _debounce = Timer(const Duration(milliseconds: 800), () {
                  setState(() => searchKey = value.trim());
                  _fetchInvoices(initial: true);
                });
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
                  final preview = (inv.itemsList ?? '').trim();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showInvoiceDetails(inv),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Doc Number chip (same style as Orders)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue),
                              ),
                              child: Text(
                                'Doc #${inv.docNumber ?? '-'}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Invoice details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title row + Bank pill on right
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          "Invoice Details",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if ((inv.bankName ?? '').isNotEmpty)
                                        Container(
                                          constraints: const BoxConstraints(maxWidth: 150), // limit width if needed
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            inv.bankName!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1, // only one line
                                            overflow: TextOverflow.ellipsis, // show "..."
                                            softWrap: false,
                                          ),
                                        ),

                                    ],
                                  ),

                                  const SizedBox(height: 3),

                                  // Customer name
                                  Text(
                                    inv.customerName ?? "Unknown Customer",
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 2),

                                  // Date + items preview
                                  Row(
                                    children: [
                                      const Icon(Icons.event, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        _fmtDate(inv.docDate ?? ""),
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.list_alt, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          preview.isEmpty ? '—' : preview,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  // Money chips + Return button (short label, right aligned)
                                  Row(
                                    children: [
                                      _moneyChip(
                                        label: 'Cash',
                                        value: inv.cashReceived,
                                        border: Colors.green,
                                        fill: Colors.green.withOpacity(.08),
                                        text: Colors.green,
                                      ),
                                      const SizedBox(width: 6),
                                      _moneyChip(
                                        label: 'Bank',
                                        value: inv.bankReceived,
                                        border: Colors.indigo,
                                        fill: Colors.indigo.withOpacity(.08),
                                        text: Colors.indigo,
                                      ),
                                      const Spacer(), // pushes button to the far right
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.assignment_return, size: 16),
                                        label: const Text('Return'),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.red.shade300),
                                          foregroundColor: Colors.red.shade300,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // match chip height
                                          minimumSize: const Size(0, 38),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                          textStyle: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: () => _onReturnPressed(inv),
                                      )


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

// --- helpers (keep in same file) ---
  Widget _moneyChip({
    required String label,
    dynamic value,
    required Color border,
    required Color fill,
    required Color text,
  }) {
    final str = (value == null || value.toString().trim().isEmpty) ? '0' : value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        '$label: $str',
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showInvoiceDetails(SalesInvoice inv) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.grey[50], // light grey like orders
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final items = (inv.itemsList ?? '').trim();

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
                      "Invoice Details",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Doc #${inv.docNumber ?? '-'}',
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

              // Customer name (primary line)
              Text(
                inv.customerName ?? "",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),

              // POS name and Mobile (optional)
              if ((inv.customerNamePOS ?? '').isNotEmpty ||
                  (inv.mobileNumber ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if ((inv.customerNamePOS ?? '').isNotEmpty)
                      Flexible(
                        child: Text(
                          "POS: ${inv.customerNamePOS}",
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if ((inv.customerNamePOS ?? '').isNotEmpty &&
                        (inv.mobileNumber ?? '').isNotEmpty)
                      const SizedBox(width: 12),
                    if ((inv.mobileNumber ?? '').isNotEmpty)
                      Text(
                        "Mob: ${inv.mobileNumber}",
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                  ],
                ),
              ],

              // Date & Bank name pill
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    "Date: ${_fmtDate(inv.docDate ?? "")}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if ((inv.bankName ?? '').isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 150), // limit width
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        inv.bankName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,                  // keep in one line
                        overflow: TextOverflow.ellipsis, // show "..."
                        softWrap: false,              // prevent wrap
                      ),
                    ),

                ],
              ),

              // Amount chips (Cash / Bank)
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Text(
                      'Cash: ${inv.cashReceived ?? 0}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigo),
                    ),
                    child: Text(
                      'Bank: ${(inv.bankReceived ?? "0")}',
                      style: const TextStyle(
                        color: Colors.indigo,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

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
                items.isEmpty ? '—' : items,
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