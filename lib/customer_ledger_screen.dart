import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'Model/customer.dart';
import 'Model/ledger_entry.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  final ScrollController _scroll = ScrollController();
  String managerIDSalesOrder = '';
  // filters
  Customer? _selectedCustomer;
  DateTime? _fromDate;
  DateTime? _toDate;

  // paging
  bool isLoading = false;
  bool hasMore = true;
  int page = 1;
  final int pageSize = 30;

  // data
  final List<LedgerEntry> _rows = [];

  // formatters
  final _dateFmt = DateFormat('dd-MMM-yyyy');
  final _moneyFmt = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadManagerID();
    _restoreLastCustomer();
  }



  Future<void> _loadManagerID() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      managerIDSalesOrder = prefs.getString('salesPurchaseOrderManagerID')?.trim() ?? '';
    });
  }





  Future<void> _restoreLastCustomer() async {
    // Optional: restore last selected customer
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('lastCustomerID');
    final lastName = prefs.getString('lastCustomerName');
    if (lastId != null && lastName != null) {
      setState(() {
        _selectedCustomer = Customer(id: lastId, customerName: lastName, customerAddress: ''); // adjust fields to your Customer model
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!hasMore || isLoading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadNextPage();
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

  Future<List<Customer>> _searchCustomers(String filter) async {
    final q = (filter).trim();

    // block calls until we have managerID + enough chars
    if (managerIDSalesOrder.isEmpty) return [];
    if (q.length < 3) return [];

    try {
      return await ApiService.fetchCustomers(managerIDSalesOrder, q);
    } catch (e) {
      debugPrint('Customer search failed: $e');
      return [];
    }
  }

  Future<void> _onLoadPressed() async {
    if (_selectedCustomer == null || _fromDate == null || _toDate == null) return;

    // persist last selected
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastCustomerID', _selectedCustomer!.id);
    await prefs.setString('lastCustomerName', _selectedCustomer!.customerName);

    setState(() {
      page = 1;
      hasMore = true;
      _rows.clear();
    });
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_selectedCustomer == null || _fromDate == null || _toDate == null) return;

    setState(() => isLoading = true);
    try {
      final items = await ApiService.fetchCustomerLedger(
        customerID: _selectedCustomer!.id,
        fromDate: _fromDate!,
        toDate: _toDate!,
        page: page,
        pageSize: pageSize,
      );
      setState(() {
        _rows.addAll(items);
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

  Future<void> _onRefresh() async {
    if (_selectedCustomer == null || _fromDate == null || _toDate == null) return;
    setState(() {
      page = 1;
      hasMore = true;
      _rows.clear();
    });
    await _loadNextPage();
  }

  String _fmtDate(DateTime? d) => d == null ? '' : _dateFmt.format(d);
  String _money(num v) => _moneyFmt.format(v.toDouble());

  @override
  Widget build(BuildContext context) {
    final allowLoad = _selectedCustomer != null && _fromDate != null && _toDate != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Ledger')),
      body: Column(
        children: [
          // ---- Filters ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer
                DropdownSearch<Customer>(
                  enabled: managerIDSalesOrder.isNotEmpty,
                  asyncItems: (filter) => _searchCustomers(filter ?? ''),
                  itemAsString: (c) => c.customerName,
                  selectedItem: _selectedCustomer,
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    isFilterOnline: true,
                    searchDelay: const Duration(milliseconds: 800),
                    searchFieldProps: TextFieldProps(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search customers...',
                      ),
                    ),
                    emptyBuilder: (ctx, str) {
                      final typed = (str ?? '').trim();
                      if (typed.length < 3) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Type at least 3 characters to search...'),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No customers found'),
                      );
                    },
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Customer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  onChanged: (val) => setState(() => _selectedCustomer = val),
                ),

                const SizedBox(height: 8),

                // Dates row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickFromDate,
                        child: InputDecorator(
                          isEmpty: _fromDate == null,
                          decoration: const InputDecoration(
                            labelText: 'From',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                              _fromDate == null ? 'Select date' : _fmtDate(_fromDate)),
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
                            labelText: 'To',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                              _toDate == null ? 'Select date' : _fmtDate(_toDate)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Load button on separate line
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: allowLoad ? _onLoadPressed : null,
                    icon: const Icon(Icons.download),
                    label: const Text('Load'),
                  ),
                ),
              ],
            ),
          ),


          const Divider(height: 1),

          // ---- List ----
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                controller: _scroll,
                itemCount: _rows.length + (isLoading ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i >= _rows.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final row = _rows[i];

                  // Styling like a cash-book: date + doc on top, narration,
                  // right-aligned amounts, color-coded Dr/Cr, bold balance
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: Date + doc
                            Row(
                              children: [
                                Text(
                                  _fmtDate(row.docDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${row.docType ?? ''} ${row.docNo ?? ''}'.trim(),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                if (row.datePosting != null)
                                  Text(
                                    'Posting: ${_fmtDate(row.datePosting)}',
                                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            if ((row.narration ?? '').isNotEmpty)
                              Text(
                                row.narration!,
                                style: const TextStyle(color: Colors.black87),
                              ),

                            const SizedBox(height: 8),

                            // Amounts
                            // Amounts
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Debit',
                                        style: TextStyle(color: Colors.red.shade700),
                                      ),
                                      Text(
                                        _money(row.debit),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black, // <-- make debit value black
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Credit',
                                        style: TextStyle(color: Colors.green.shade700),
                                      ),
                                      Text(
                                        _money(row.credit),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black, // <-- make credit value black
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),


                            const SizedBox(height: 6),
                            const Divider(height: 12),

                            // Balance (bold)
                            Row(
                              children: [
                                const Text('Balance', style: TextStyle(color: Colors.black54)),
                                const Spacer(),
                                Text(
                                  _money(row.balance),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
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
}
