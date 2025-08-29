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
          {
            'operator': 'contains',
            'value': '',
            'field': 'ipAddress',
            'ignoreCase': true,
          }
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
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                    child: ElevatedButton(
                      onPressed: () => _openForm(),
                      child: const Text('Add New'),
                    ),
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('No Allowed IPs.'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('IP Address')),
                              DataColumn(label: Text('Description')),
                              DataColumn(label: Text('Is Active')),
                              DataColumn(label: Text('Valid Until')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _items.map((ip) {
                              return DataRow(cells: [
                                DataCell(Text(ip.ipAddress)),
                                DataCell(Text(ip.desc)),
                                DataCell(Icon(ip.isActive ? Icons.check : Icons.close)),
                                DataCell(Text(_fmtDate(ip.validUntil))),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _openForm(data: ip),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _confirmDelete(ip),
                                    ),
                                  ],
                                )),
                              ]);
                            }).toList(),
                          ),
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
                        ),
                      ],
                    ),
                  ),
              ],
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
                    _validUntil != null ? _validUntil!.toLocal().toString() : 'Select date'),
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        Text(editing ? 'Updated successfully' : 'Added successfully')));
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

