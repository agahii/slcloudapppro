import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slcloudapppro/Model/cash_book.dart';
import 'api_service.dart';

class MyCashBookScreen extends StatefulWidget {
  const MyCashBookScreen({super.key});

  @override
  State<MyCashBookScreen> createState() => _MyCashBookScreenState();
}

class _MyCashBookScreenState extends State<MyCashBookScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  // paging
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  final int pageSize = 20;

  // filters
  String searchKey = "";

  // data
  final List<CashBookEntry> _rows = [];

  // identity (accountID for cash book)
  String? _accountID; // Prefer reading "cashBookID" from SharedPreferences (UserVM has CashBookID)

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !isLoading &&
          hasMore) {
        _fetchCashBook();
      }
    });
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    // try your saved key; change the key name to match how you store it
    _accountID = prefs.getString('cashBookID') ;

    // Optional: fall back to a default account ID if you use one
    // _accountID ??= "<DEFAULT_ACCOUNT_ID>";

    if (_accountID == null || _accountID!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash Book accountID not found in preferences.')),
      );
      return;
    }
    _fetchCashBook(initial: true);
  }

  Future<void> _fetchCashBook({bool initial = false}) async {
    if (_accountID == null || _accountID!.isEmpty) return;

    if (initial) {
      setState(() {
        currentPage = 1;
        hasMore = true;
        _rows.clear();
      });
    }
    if (!hasMore) return;

    setState(() => isLoading = true);
    try {
      final list = await ApiService.fetchMyCashBook(
        accountID: _accountID!,
        page: currentPage,
        pageSize: pageSize,
        searchKey: searchKey,
      );

      setState(() {
        _rows.addAll(list);
        currentPage++;
        if (list.length < pageSize) hasMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading cash book: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load cash book: $e')),
      );
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _refresh() async => _fetchCashBook(initial: true);

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
  }

  String _fmtAmount(double v) {
    // simple two-decimal format; localize if you prefer
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My Cash Book')),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Narration / Ref / Cheque...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchKey = "");
                    _fetchCashBook(initial: true);
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                setState(() => searchKey = _searchController.text.trim());
                _fetchCashBook(initial: true);
              },
            ),
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _rows.isEmpty && !isLoading
                  ? const Center(child: Text("No entries found"))
                  : ListView.builder(
                controller: _scrollController,
                itemCount: _rows.length + (isLoading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _rows.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final row = _rows[i];
                  final isDebit = row.debit > 0;
                  final amount = isDebit ? row.debit : row.credit;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Date + type chip
                          Row(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.event, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    _fmtDate(row.datePosting.toLocal()),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDebit
                                      ? Colors.green.withOpacity(.1)
                                      : Colors.red.withOpacity(.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDebit ? Colors.green : Colors.red,
                                  ),
                                ),
                                child: Text(
                                  isDebit ? 'DEBIT' : 'CREDIT',
                                  style: TextStyle(
                                    color: isDebit ? Colors.green[800] : Colors.red[800],
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Narration
                          Text(
                            row.narration.isEmpty ? '—' : row.narration,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Ref + Cheque + Amount
                          Row(
                            children: [
                              if (row.refNumber.isNotEmpty) ...[
                                const Icon(Icons.confirmation_number, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  row.refNumber,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (row.chequeNumber.isNotEmpty) ...[
                                const Icon(Icons.payments, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  row.chequeNumber,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(width: 12),
                              ],
                              const Spacer(),
                              Text(
                                _fmtAmount(amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: isDebit ? Colors.green[800] : Colors.red[800],
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
    );
  }
}
