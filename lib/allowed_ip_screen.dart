import 'dart:io';
import 'package:flutter/material.dart';

import 'Model/allowed_ip.dart';
import 'api_service.dart';

class AllowedIpScreen extends StatefulWidget {
  const AllowedIpScreen({super.key});

  @override
  State<AllowedIpScreen> createState() => _AllowedIpScreenState();
}

class _AllowedIpScreenState extends State<AllowedIpScreen> {
  int _page = 1;
  final int _pageSize = 20;
  bool _loading = false;
  List<AllowedIp> _items = [];
  int _totalRecords = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sort = [
        {'dir': 'asc', 'field': 'ipAddress'},
      ];
      final filter = {
        'logic': 'and',
        'filters': [
          // add filters if needed
        ],
      };
      final res = await ApiService.getAllowedIps(
        page: _page,
        pageSize: _pageSize,
        sort: sort,
        filter: filter,
      );
      setState(() {
        _items = res.items;
        _totalRecords = res.totalRecords;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasPrev => _page > 1;
  bool get _hasNext => (_page * _pageSize) < _totalRecords;

  Future<void> _openForm({AllowedIp? data}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AllowedIpForm(ip: data),
    );
    if (ok == true) {
      _load();
    }
  }

  Future<void> _confirmDelete(AllowedIp ip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text('Are you sure you want to delete this Allowed IP?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService.deleteAllowedIp(ip.id);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Deleted')));
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Allowed IPs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add New'),
              ),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('No Allowed IPs.'))
                : LayoutBuilder(
              builder: (ctx, constraints) {
                // Responsive grid: 1 col (phones), 2 cols (tablets), 3+ cols (wide)
                int crossAxisCount = 1;
                if (constraints.maxWidth >= 1200) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth >= 900) {
                  crossAxisCount = 3;
                } else if (constraints.maxWidth >= 600) {
                  crossAxisCount = 2;
                }

                return RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // Slightly wide cards to fit more content
                      childAspectRatio: crossAxisCount == 1 ? 2.0 : 1.6,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      return _AllowedIpCard(
                        item: item,
                        fmtDate: _fmtDate,
                        onEdit: () => _openForm(data: item),
                        onDelete: () => _confirmDelete(item),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _hasPrev
                        ? () {
                      setState(() => _page--);
                      _load();
                    }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous',
                  ),
                  Text('Page $_page'),
                  IconButton(
                    onPressed: _hasNext
                        ? () {
                      setState(() => _page++);
                      _load();
                    }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AllowedIpCard extends StatelessWidget {
  final AllowedIp item;
  final String Function(DateTime?) fmtDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AllowedIpCard({
    required this.item,
    required this.fmtDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isExpired = item.validUntil != null && item.validUntil!.isBefore(DateTime.now());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit, // tap card to edit (optional)
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: IP + actions
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.ipAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete),
                    onPressed: onDelete,
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Description
              if ((item.desc).trim().isNotEmpty)
                Text(
                  item.desc,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),

              const SizedBox(height: 10),

              // Chips row: Active/Inactive, ValidUntil, Expired flag
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(item.isActive ? 'Active' : 'Inactive'),
                    avatar: Icon(
                      item.isActive ? Icons.check_circle : Icons.cancel,
                      size: 18,
                    ),
                    backgroundColor: item.isActive
                        ? cs.primaryContainer
                        : cs.tertiaryContainer,
                    labelStyle: TextStyle(
                      color: item.isActive
                          ? cs.onPrimaryContainer
                          : cs.onTertiaryContainer,
                    ),
                  ),
                  if (item.validUntil != null)
                    Chip(
                      label: Text('Valid: ${fmtDate(item.validUntil)}'),
                      avatar: const Icon(Icons.schedule, size: 18),
                      backgroundColor: cs.secondaryContainer,
                      labelStyle: TextStyle(color: cs.onSecondaryContainer),
                    ),
                  if (isExpired)
                    Chip(
                      label: const Text('Expired'),
                      backgroundColor: cs.errorContainer,
                      labelStyle: TextStyle(color: cs.onErrorContainer),
                    ),
                ],
              ),

              const Spacer(),

              // Footer meta (ID) if you want to show more data:
              Text(
                'ID: ${item.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllowedIpForm extends StatefulWidget {
  final AllowedIp? ip;
  const _AllowedIpForm({this.ip});

  @override
  State<_AllowedIpForm> createState() => _AllowedIpFormState();
}

class _AllowedIpFormState extends State<_AllowedIpForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ip;
  late TextEditingController _desc;
  bool _isActive = true;
  DateTime? _validUntil;

  @override
  void initState() {
    super.initState();
    final data = widget.ip;
    _ip = TextEditingController(text: data?.ipAddress ?? '');
    _desc = TextEditingController(text: data?.desc ?? '');
    _isActive = data?.isActive ?? true;
    _validUntil = data?.validUntil;
  }

  @override
  void dispose() {
    _ip.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_validUntil ?? now),
    );
    if (time == null) return;
    setState(() {
      _validUntil = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String? _validateIp(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (InternetAddress.tryParse(v.trim()) == null) return 'Invalid IP';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.ip != null;
    return AlertDialog(
      title: Text(editing ? 'Update Allowed IP' : 'Add Allowed IP'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _ip,
                decoration: const InputDecoration(labelText: 'IP Address'),
                validator: _validateIp,
              ),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLength: 200,
              ),
              SwitchListTile(
                title: const Text('Is Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Valid Until'),
                subtitle: Text(
                  _validUntil != null ? _validUntil!.toLocal().toString() : 'Select date',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate() || _validUntil == null) {
              return;
            }
            try {
              if (editing) {
                await ApiService.updateAllowedIp(
                  id: widget.ip!.id,
                  ipAddress: _ip.text.trim(),
                  desc: _desc.text.trim(),
                  isActive: _isActive,
                  validUntil: _validUntil!,
                );
              } else {
                await ApiService.addAllowedIp(
                  ipAddress: _ip.text.trim(),
                  desc: _desc.text.trim(),
                  isActive: _isActive,
                  validUntil: _validUntil!,
                );
              }
              if (context.mounted) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(editing ? 'Updated successfully' : 'Added successfully')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
