import 'dart:async';
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
  // ── Top banner state ────────────────────────────────────────────────────────
  String? _topMsg; // null = hidden
  bool _topIsError = false; // false = success/info, true = error
  Timer? _topMsgTimer;

  void _showTopMessage(
      String msg, {
        bool isError = false,
        bool autoHide = true,
        Duration hideAfter = const Duration(seconds: 3),
      }) {
    _topMsgTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _topMsg = msg;
      _topIsError = isError;
    });
    if (autoHide && !isError) {
      _topMsgTimer = Timer(hideAfter, () {
        if (!mounted) return;
        setState(() => _topMsg = null);
      });
    }
  }

  // ── Data/state ─────────────────────────────────────────────────────────────
  BankAccount? _selectedBank;
  List<BankAccount> _banks = [];
  final TextEditingController _detailsCtrl = TextEditingController();

  String _managerID = '';
  String _employeeID = '';

  bool _loadingPolicies = false;
  List<DiscountPolicy> _policies = [];

  // rows must be reassignable so we can replace the whole list after save
  List<CollectionTxn> _rows = [CollectionTxn()];

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

  @override
  void dispose() {
    _topMsgTimer?.cancel();
    _detailsCtrl.dispose();
    super.dispose();
  }

  // ── Loaders ────────────────────────────────────────────────────────────────

  Future<void> _loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final mid = prefs.getString('provisionalReceiptManagerID') ?? '';
    final emp = prefs.getString('employeeID') ?? '';
    if (!mounted) return;
    setState(() {
      _managerID = mid;
      _employeeID = emp;
    });
  }

  Future<void> _loadBanksFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('provisionalReceiptDebitAccountsVM');
    if (raw == null) {
      if (!mounted) return;
      setState(() => _banks = []);
      return;
    }
    try {
      final List<dynamic> arr = jsonDecode(raw);
      final parsed = arr
          .map((e) => BankAccount.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _banks = parsed;
        // select nothing by default; validator + _canSave will gate the button
        _selectedBank = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _banks = []);
    }
  }

  Future<void> _loadPolicies() async {
    if (!mounted) return;
    setState(() => _loadingPolicies = true);
    try {
      final list = await ApiService.getDiscountPolicyPOS();
      if (!mounted) return;
      setState(() => _policies = list);
    } catch (_) {
      // ignore
    } finally {
      if (!mounted) return;
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

  bool _isRowValid(CollectionTxn r) =>
      r.customer != null && r.policy != null && (r.amount ?? 0) > 0;

  bool get _canSave =>
      !_submitting &&
          _selectedBank != null &&
          _rows.isNotEmpty &&
          _rows.every(_isRowValid);

  bool _validate() {
    if (_selectedBank == null) {
      _showTopMessage('Please select a bank.', isError: true, autoHide: false);
      return false;
    }
    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      if (r.customer == null) {
        _showTopMessage('Row ${i + 1}: Please select a customer.',
            isError: true, autoHide: false);
        return false;
      }
      if (r.policy == null) {
        _showTopMessage('Row ${i + 1}: Please select a policy.',
            isError: true, autoHide: false);
        return false;
      }
      if (r.amount == null || r.amount! <= 0) {
        _showTopMessage('Row ${i + 1}: Please enter a valid amount.',
            isError: true, autoHide: false);
        return false;
      }
    }
    return true;
  }

  // ── Top banner widget ──────────────────────────────────────────────────────

  Widget _topBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: (_topMsg == null)
          ? const SizedBox.shrink() // no space when hidden
          : Padding(
        key: const ValueKey('top-banner'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _topIsError
                ? const Color(0xFFFFEBEE)
                : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _topIsError
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF43A047),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _topIsError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 18,
                color: _topIsError
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _topMsg!,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _topIsError
                        ? const Color(0xFFB71C1C)
                        : const Color(0xFF1B5E20),
                  ),
                ),
              ),
              if (!_topIsError)
                IconButton(
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _topMsg = null),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

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
              key: ValueKey('cust_${row.hashCode}'), // <-- forces fresh widget
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
                    key: ValueKey('pol_${row.hashCode}'), // <-- fresh widget
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
                    key: ValueKey('amt_${row.hashCode}'), // <-- fresh widget
                    initialValue: row.amount?.toStringAsFixed(2) ?? '',
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                      prefixText: 'Rs. ',
                      border: OutlineInputBorder(),
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

  Map<String, dynamic> _buildPayload() {
    return {
      "instrumentNumber": "",
      "masterNarration": _detailsCtrl.text.trim(),
      "fK_VoucherManagerMaster_ID": _managerID,
      "fK_ChartOfAccounts_ID": _selectedBank?.id,
      "fK_Employee_ID": _employeeID,
      "provisionalReceiptDetailsPOSInp": _rows
          .map((r) => {
        "fK_ChartOfAccounts_ID": r.customer?.id,
        "fK_DiscountPolicy_ID": r.policy?.id,
        "amount": r.amount,
      })
          .toList(),
    };
  }

  Future<void> _submit() async {
    // Gating + validator for safety
    if (!_validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final payload = _buildPayload();
      final resp = await ApiService.addProvisionalReceipt(payload);

      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (!ok) {
        final msg = ApiService.extractServerMessage(resp);
        if (!mounted) return;
        _showTopMessage('❌ $msg', isError: true, autoHide: false); // permanent
        return;
      }

      if (!mounted) return;

      // Success UX: show then auto-hide
      _showTopMessage('✅ Saved successfully!',
          isError: false, autoHide: true);

      // Reset inputs safely
      FocusScope.of(context).unfocus();
      _detailsCtrl.clear();

      setState(() {
        _rows = [CollectionTxn()]; // new object -> fresh keys -> cleared fields
        _selectedBank = null;      // set to null to visually clear bank
      });

    } catch (e) {
      if (!mounted) return;
      _showTopMessage('❌ Failed to save: $e',
          isError: true, autoHide: false); // permanent
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            _topBanner(),

            // Bank section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header('Bank/Collection Account',
                        icon: Icons.account_balance_rounded),
                    const SizedBox(height: 12),
                    DropdownSearch<BankAccount>(
                      items: _banks,
                      itemAsString: (b) => b.accountName,
                      selectedItem: _selectedBank,
                      popupProps: const PopupProps.menu(showSearchBox: true),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Select Bank/Collection Account',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      onChanged: (b) => setState(() => _selectedBank = b),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _detailsCtrl,
                      maxLines: 2,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Details / Narration',
                        hintText:
                        'e.g. Received via cheque #123456 from customer',
                        border: OutlineInputBorder(),
                        isDense: true,
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
                          _header('Transactions',
                              icon: Icons.list_alt_rounded),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                            ),
                            onPressed: _addRow,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),

                    // Key each row subtree so clearing rows actually rebuilds inputs
                    SliverList.builder(
                      itemCount: _rows.length,
                      itemBuilder: (_, i) => KeyedSubtree(
                        key: ObjectKey(_rows[i]),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildTxnRow(i),
                        ),
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
                      onPressed: _canSave ? _submit : null, // gated by validity
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
