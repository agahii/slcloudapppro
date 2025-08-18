import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Model/chart_account.dart';
import 'api_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Local models
// ──────────────────────────────────────────────────────────────────────────────

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

  factory DiscountPolicy.fromMap(Map<String, dynamic> m) => DiscountPolicy(
    id: m['id'] ?? '',
    discountPolicyName: m['discountPolicyName'] ?? '',
  );
}

enum PaymentMode { cash, bankCheque }

class CollectionTxn {
  ChartAccount? customer;
  DiscountPolicy? policy;
  double? amount;

  CollectionTxn({this.customer, this.policy, this.amount});
}

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen>
    with TickerProviderStateMixin {
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

  // ── Data loaders ────────────────────────────────────────────────────────────

  Future<void> _loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final mid = prefs.getString('provisionalReceiptManagerID') ?? '';
    setState(() => _managerID = mid);
  }

  Future<void> _loadBanksFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
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
      // ignore
    } finally {
      setState(() => _loadingPolicies = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _addRow() => setState(() => _rows.add(CollectionTxn()));
  void _removeRow(int i) {
    setState(() {
      if (_rows.length > 1) _rows.removeAt(i);
    });
  }

  double _grandTotal() =>
      _rows.fold(0.0, (sum, r) => sum + ((r.amount ?? 0.0)));

  bool _validate() {
    if (_mode == PaymentMode.bankCheque && _selectedBank == null) {
      _showSnack('Please select a bank for Bank Cheque mode.');
      return false;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── UI pieces ───────────────────────────────────────────────────────────────

  Widget _sectionCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _chipToggle({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(.10) : cs.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withOpacity(.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: selected ? cs.primary : cs.onSurface),
            if (icon != null) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, {IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary, size: 18),
          ),
        if (icon != null) const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
    );
  }

  Widget _divider() => const SizedBox(height: 10);

  // One transaction row
  Widget _buildTxnRow(int index) {
    final row = _rows[index];
    final cs = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topCenter,
      child: _sectionCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row header with index + remove
            Row(
              children: [
                Text(
                  'Transaction ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(.9),
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(.08),
                  ),
                  onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.redAccent,
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer
            DropdownSearch<ChartAccount>(
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
                  isDense: true,
                ),
              ),
              onChanged: (c) => setState(() => row.customer = c),
            ),

            _divider(),

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
                        isDense: true,
                      ),
                    ),
                    onChanged: (p) => setState(() => row.policy = p),
                    enabled: !_loadingPolicies,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: TextFormField(
                    initialValue: row.amount?.toStringAsFixed(2) ?? '',
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                      prefixText: 'Rs. ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => row.amount = double.tryParse(v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Submit payload preview (same functionality)
  Map<String, dynamic> _buildPayload() {
    return {
      "paymentMode": _mode == PaymentMode.cash ? "CASH" : "BANK_CHEQUE",
      "bankId": _mode == PaymentMode.bankCheque ? _selectedBank?.id : null,
      "transactions": _rows
          .map((r) => {
        "customerId": r.customer?.id,
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
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Payload Preview'),
          content: SingleChildScrollView(
            child: Text(const JsonEncoder.withIndent('  ').convert(payload)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCheque = _mode == PaymentMode.bankCheque;

    return Scaffold(
      backgroundColor: cs.surfaceVariant.withOpacity(.15),
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        centerTitle: false,
        title: const Text('Collections',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top section: payment mode + bank
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header('Payment', icon: Icons.payments_rounded),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _chipToggle(
                          label: 'Cash',
                          icon: Icons.money_rounded,
                          selected: _mode == PaymentMode.cash,
                          onTap: () => setState(() => _mode = PaymentMode.cash),
                        ),
                        _chipToggle(
                          label: 'Bank Cheque',
                          icon: Icons.account_balance_rounded,
                          selected: _mode == PaymentMode.bankCheque,
                          onTap: () =>
                              setState(() => _mode = PaymentMode.bankCheque),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: isCheque ? 1 : .55,
                      child: AbsorbPointer(
                        absorbing: !isCheque,
                        child: DropdownSearch<BankAccount>(
                          items: _banks,
                          itemAsString: (b) => b.accountName,
                          selectedItem: _selectedBank,
                          popupProps:
                          const PopupProps.menu(showSearchBox: true),
                          dropdownDecoratorProps:
                          const DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: 'Bank',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          onChanged: (b) => setState(() => _selectedBank = b),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Transactions list
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Row(
                        children: [
                          _header('Transactions', icon: Icons.list_alt_rounded),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            onPressed: _addRow,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverList.builder(
                      itemCount: _rows.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildTxnRow(i),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 90)),
                  ],
                ),
              ),
            ),

            // Sticky total + save
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withOpacity(.3),
                  ),
                ),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 12).copyWith(top: 10),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total: ${_moneyFmt.format(_grandTotal())}',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.save_outlined),
                      label: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
