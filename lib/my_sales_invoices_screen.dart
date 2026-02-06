import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/sales_return_screen.dart';
import 'package:slcloudapppro/theme/app_colors.dart';
import 'package:slcloudapppro/utils/return_invoice_parser.dart';
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
        backgroundColor: Colors.white,
        title: const Text('Confirm Invoice Return',style: TextStyle(color: Colors.black),),
        content: Text('Return Invoice #${inv.docNumber ?? "-"}?',style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mainButtonsColor,

            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed',style: TextStyle(color: Colors.black),),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    _openReturnPage(inv);


    // Option A: Navigate to a return screen (recommended)
   /* Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesReturnPage(
          invoiceNumber: inv.docNumber ?? "",
          items: inv.itemsList,
        ),
      ),
    );*/


    /*Navigator.pushNamed(
      context,
      '/invoiceReturn',
      arguments: {
        'invoiceId': inv.id,
        'docNumber': inv.docNumber,
        'customerName': inv.customerName,
        'docDate': inv.docDate,
        'itemsList': inv.itemsList,
      },
    );*/

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


  void _openReturnPage(SalesInvoice invoice) {
    // Parse products from itemsList
    final products = InvoiceItemsParser.parseItemsList(invoice.itemsList ?? '');

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items found in this invoice'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesReturnPage(
          invoiceNumber: invoice.docNumber!,
          items: products,
        ),
      ),
    ).then((result) {
      if (result != null) {
        _handleReturnProcessed(invoice, result);
      }
    });
  }
  void _handleReturnProcessed(SalesInvoice invoice, Map<String, dynamic> returnData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Return processed for ${invoice.docNumber}\n'
              'Amount: Rs.${returnData['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.appBackgroundGreyColor,
      appBar: AppBar(
          backgroundColor: AppColors.mainButtonsColor,
          iconTheme: IconThemeData(color: Colors.black),
          title: const Text('My Sales Invoices',style: TextStyle(color: Colors.black),)
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.only(left:20,right: 20,top: 10,bottom: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Invoice No / Customer...',
                hintStyle: const TextStyle(color: AppColors.greyColor),    // visible hint
                filled: true,
                fillColor: Colors.white,                               // solid light background
                prefixIcon: isLoading
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black54), // visible spinner
                    ),
                  ),
                )
                    : const Icon(Icons.search, color: AppColors.greyColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black54),
                  onPressed: () {
                    _searchController.clear();
                    _debounce?.cancel();
                    setState(() => searchKey = "");
                    _fetchInvoices(initial: true);
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white), // brand color on focus
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
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
          // List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.blackColor,
              backgroundColor: AppColors.mainButtonsColor,
              onRefresh: _refresh,
              child: _invoices.isEmpty && !isLoading
                  ? const Center(child: Text("No invoices found"))
                  : ListView.builder(
                controller: _scrollController,
                itemCount: _invoices.length + (isLoading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _invoices.length) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator( color: AppColors.mainButtonsColor,)),
                    );
                  }

                  final inv = _invoices[i];
                  final preview = (inv.itemsList ?? '').trim();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    elevation: 0,
                    color: Colors.white,
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
                                color: AppColors.tabLabelBlueColor.withOpacity(.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.tabLabelBlueColor),
                              ),
                              child: Text(
                                'Doc #${inv.docNumber ?? '-'}',
                                style: const TextStyle(
                                  color: AppColors.tabLabelBlueColor,
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
                                            fontWeight: FontWeight.w300,
                                            fontSize: 16,
                                            color: Colors.black
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
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
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
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
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
                                      ElevatedButton(
                                        onPressed: () => _onReturnPressed(inv),
                                      style:  ElevatedButton.styleFrom(
                                       // side: BorderSide(color: AppColors.mainButtonsColor),
                                        backgroundColor: AppColors.mainButtonsColor,
                                        foregroundColor: AppColors.mainButtonsColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // match chip height
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      child: Text('Return',style: TextStyle(color: AppColors.blackColor),)
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