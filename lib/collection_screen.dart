import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Model/chart_account.dart';
import 'api_service.dart';

// --- Local models ---

class BankAccount {
  final String id;
  final String accountName;
  BankAccount({required this.id, required this.accountName});

  factory BankAccount.fromMap(Map<String, dynamic> m) =>
      BankAccount(id: m['id'] ?? '', accountName: m['accountName'] ?? '');
}

class DiscountPolicy {
  final String id;
  final String discountPolicyName;
  DiscountPolicy({required this.id, required this.discountPolicyName});

  factory DiscountPolicy.fromMap(Map<String, dynamic> m) =>
      DiscountPolicy(id: m['id'] ?? '', discountPolicyName: m['discountPolicyName'] ?? '');
}

enum PaymentMode { cash, bankCheque }

class CollectionTxn {
  ChartAccount? customer; // Using your ChartAccount model
  DiscountPolicy? policy;
  double? amount;

  CollectionTxn({this.customer, this.policy, this.amount});
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  // Payment mode + bank
  PaymentMode _mode = PaymentMode.bankCheque; // bank first on screen
  BankAccount? _selectedBank;
  List<BankAccount> _banks = [];

  // Manager for provisional receipt
  String _managerID = '';

  // Policies cache
  bool _loadingPolicies = false;
  List<DiscountPolicy> _policies = [];

  // Txn rows
  final List<CollectionTxn> _rows = [CollectionTxn()];
  final _moneyFmt =
  NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 2);

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
    _loadBanksFromPrefs();
    _loadPolicies();
  }

  Future<void> _loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    // read provisionalReceiptManagerID, fallback to ''
    final mid = prefs.getString('provisionalReceiptManagerID') ?? '';
    setState(() => _managerID = mid);
  }

  Future<void> _loadBanksFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Expecting a JSON-encoded list under the key "provisionalReceiptDebitAccountsVM"
    final raw = prefs.getString('provisionalReceiptDebitAccountsVM');
    if (raw == null) {
      setState(() => _banks = []);
      return;
    }
    try {
      final List<dynamic> arr = jsonDecode(raw);
      final parsed = arr
          .map((e) => BankAccount.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      setState(() {
        _banks = parsed;
        if (_banks.isNotEmpty) _selectedBank = _banks.first;
      });
    } catch (_) {
      setState(() => _banks = []);
    }
  }

  Future<void> _loadPolicies() async {
    setState(() => _loadingPolicies = true);
    try {
      final list = await ApiService.getDiscountPolicyPOS();
      setState(() => _policies = list);
    } catch (_) {
      // ignore and show empty
    } finally {
      setState(() => _loadingPolicies = false);
    }
  }

  void _addRow() => setState(() => _rows.add(CollectionTxn()));
  void _removeRow(int i) {
    setState(() {
      if (_rows.length > 1) _rows.removeAt(i);
    });
  }

  double _grandTotal() =>
      _rows.fold(0.0, (sum, r) => sum + ((r.amount ?? 0.0)));

  bool _validate() {
    if (_mode == PaymentMode.bankCheque) {
      if (_selectedBank == null) {
        _showSnack('Please select a bank for Bank Cheque mode.');
        return false;
      }
    }
    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      if (r.customer == null) {
        _showSnack('Row ${i + 1}: Please select a customer.');
        return false;
      }
      if (r.policy == null) {
        _showSnack('Row ${i + 1}: Please select a policy.');
        return false;
      }
      if (r.amount == null || r.amount! <= 0) {
        _showSnack('Row ${i + 1}: Please enter a valid amount.');
        return false;
      }
    }
    return true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Build one transaction row (customer, policy, amount, delete)
  Widget _buildTxnRow(int index) {
    final row = _rows[index];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Customer
            Row(
              children: [
                Expanded(
                  child: DropdownSearch<ChartAccount>(
                    // 👇 Same pattern as in your HomeScreen:
                    asyncItems: (String filter) async {
                      if (_managerID.isEmpty) return <ChartAccount>[];

                      final q = filter.trim();
                      if (q.length < 3) return <ChartAccount>[];

                      return await ApiService.getProvisionalReceiptCreditAccounts(
                        managerID: _managerID,
                        searchKey: q,
                      );
                    },
                    itemAsString: (c) => c.accountName,
                    selectedItem: row.customer,
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      isFilterOnline: true,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: "🔍 Search customer...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Customer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    onChanged: (c) => setState(() => row.customer = c),
                  ),
                ),
                const SizedBox(width: 10),
                // Delete
                IconButton(
                  onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Policy + Amount
            Row(
              children: [
                Expanded(
                  child: DropdownSearch<DiscountPolicy>(
                    items: _policies,
                    itemAsString: (p) => p.discountPolicyName,
                    selectedItem: row.policy,
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Policy',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    onChanged: (p) => setState(() => row.policy = p),
                    enabled: !_loadingPolicies,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    initialValue: row.amount?.toStringAsFixed(2) ?? '',
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      setState(() => row.amount = parsed);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Optional: build a payload preview for submit
  Map<String, dynamic> _buildPayload() {
    return {
      "paymentMode": _mode == PaymentMode.cash ? "CASH" : "BANK_CHEQUE",
      "bankId": _mode == PaymentMode.bankCheque ? _selectedBank?.id : null,
      "transactions": _rows
          .map((r) => {
        "customerId": r.customer?.id, // ChartAccount.id
        "policyId": r.policy?.id,
        "amount": r.amount,
      })
          .toList(),
      "grandTotal": _grandTotal(),
    };
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _submitting = true);
    try {
      final payload = _buildPayload();
      // TODO: post to your final endpoint when ready.
      // await ApiService.submitCollections(payload);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Payload Preview'),
          content: SingleChildScrollView(
            child: Text(const JsonEncoder.withIndent('  ').convert(payload)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        ),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCheque = _mode == PaymentMode.bankCheque;

    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Payment mode
            Row(
              children: [
                const Text('Payment Mode:'),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Cash'),
                  selected: _mode == PaymentMode.cash,
                  onSelected: (_) => setState(() => _mode = PaymentMode.cash),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Bank Cheque'),
                  selected: _mode == PaymentMode.bankCheque,
                  onSelected: (_) =>
                      setState(() => _mode = PaymentMode.bankCheque),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bank dropdown (first on screen; disabled if cash)
            DropdownSearch<BankAccount>(
              items: _banks,
              itemAsString: (b) => b.accountName,
              selectedItem: _selectedBank,
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Bank',
                  border: OutlineInputBorder(),
                ),
              ),
              popupProps: const PopupProps.menu(showSearchBox: true),
              onChanged:
              isCheque ? (b) => setState(() => _selectedBank = b) : null,
              enabled: isCheque,
            ),

            const SizedBox(height: 12),

            // Transactions
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (_, i) => _buildTxnRow(i),
              ),
            ),

            // Footer row: Add btn + total + submit
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Transaction'),
                ),
                const Spacer(),
                Text(
                  'Total: ${_moneyFmt.format(_grandTotal())}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
