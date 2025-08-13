import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class InvoicePrintPage extends StatelessWidget {
  final Map<String, dynamic> inv;
  const InvoicePrintPage({super.key, required this.inv});

  // --- Helpers ---
  String _s(dynamic v) => (v == null) ? '' : v.toString();
  String _money(num? v) => NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 2)
      .format((v ?? 0).toDouble());
  String _dateIsoToLocal(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('dd-MMM-yyyy hh:mm a').format(dt.toLocal());
  }

  Future<Uint8List> _buildPdf(final PdfPageFormat format) async {
    final doc = pw.Document();

    // Try loading logo if present
    pw.ImageProvider? logoImage;
    final logoName = _s(inv['businessUnitLogoUrl']); // e.g. "file.jpg" from your API
    // If you have a full URL, use that; otherwise skip
    if (logoName.isNotEmpty) {
      try {
        // Replace with your real logo URL builder if needed
        // final url = '${ApiService.imageBaseUrl}$logoName';
        // final netImg = await networkImage(url);
        // logoImage = netImg;
      } catch (_) {}
    }

    final businessName = _s(inv['businessUnitName']);
    final businessAddress = _s(inv['businessUnitAddress']);
    final companyName = _s(inv['name']); // company location name (e.g., Topsun-1)

    final docNumber = inv['docNumber']?.toString() ?? '';
    final docDate = _dateIsoToLocal(_s(inv['docDate']));

    final customerName = _s(inv['customerName']);
    final customerAddress = _s(inv['deliveryAddress']).isNotEmpty
        ? _s(inv['deliveryAddress'])
        : _s(inv['customerAddress']);
    final customerMobile = _s(inv['mobileNumber']);

    final stockLocation = _s(inv['stockLocationName']);

    final cashReceived = (inv['cashReceived'] as num?)?.toDouble() ?? 0.0;
    final bankReceived = (inv['bankReceived'] as num?)?.toDouble() ?? 0.0;
    final accountNameBank = _s(inv['accountNameBank']);

    final details = (inv['invoiceDetails'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    num subTotal = 0, discountTotal = 0, taxTotal = 0, freightTotal = 0, grandTotal = 0;
    for (final row in details) {
      subTotal += (row['amount'] as num?) ?? 0;
      discountTotal += (row['discountAmount'] as num?) ?? 0;
      taxTotal += (row['taxAmount'] as num?) ?? 0;
      freightTotal += (row['freightCharges'] as num?) ?? 0;
      grandTotal += (row['totalAmount'] as num?) ?? 0;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                pw.Container(
                  width: 64,
                  height: 64,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName.isNotEmpty ? businessName : companyName,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    if (businessAddress.isNotEmpty)
                      pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 10)),
                    if (stockLocation.isNotEmpty)
                      pw.Text('Stock: $stockLocation', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('SALES INVOICE',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  if (docNumber.isNotEmpty) pw.Text('Invoice #: $docNumber'),
                  if (docDate.isNotEmpty) pw.Text('Date: $docDate'),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 10),
          pw.Divider(),

          // Customer
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(customerName),
                    if (customerAddress.isNotEmpty) pw.Text(customerAddress, maxLines: 2),
                    if (customerMobile.isNotEmpty) pw.Text('Mobile: $customerMobile'),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Entered By', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(_s(inv['userIdEnter'])),
                    pw.Text('Created: ${_dateIsoToLocal(_s(inv['createdDate']))}'),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),

          // Items Table
          pw.Table(
            border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey500),
            columnWidths: {
              0: const pw.FlexColumnWidth(4), // Item
              1: const pw.FlexColumnWidth(2), // Batch
              2: const pw.FlexColumnWidth(1), // Qty
              3: const pw.FlexColumnWidth(2), // Rate
              4: const pw.FlexColumnWidth(2), // Amount
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _th('Item'),
                  _th('Batch'),
                  _th('Qty'),
                  _th('Rate'),
                  _th('Amount'),
                ],
              ),
              ...details.map((d) => pw.TableRow(
                children: [
                  _td('${_s(d['skuName'])}  (${_s(d['packingName'])})'),
                  _td(_s(d['batchNumber'])),
                  _td(_s(d['quantity'])),
                  _td(_money(d['rate'] as num?)),
                  _td(_money(d['totalAmount'] as num?)),
                ],
              )),
            ],
          ),

          pw.SizedBox(height: 10),

          // Totals
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.Container(
                width: 240,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _kv('Sub Total', _money(subTotal)),
                    _kv('Discount', _money(discountTotal)),
                    _kv('Tax', _money(taxTotal)),
                    _kv('Freight', _money(freightTotal)),
                    pw.Divider(),
                    _kv('Grand Total', _money(grandTotal), bold: true),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 10),
          pw.Divider(),

          // Payments
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Payment Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    _kv('Cash Received', _money(cashReceived)),
                    if (bankReceived > 0) _kv('Bank Received', _money(bankReceived)),
                    if (bankReceived > 0 && accountNameBank.isNotEmpty)
                      pw.Text('Bank: $accountNameBank', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),

          pw.SizedBox(height: 16),
          pw.Text('Thank you for your business!',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
        ],
      ),
    );

    return doc.save();
  }

  // Table header cell
  pw.Widget _th(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  );

  // Table data cell
  pw.Widget _td(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, maxLines: 2, overflow: pw.TextOverflow.span),
  );

  // Key-Value row (right column summary)
  pw.Widget _kv(String k, String v, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(k, style: pw.TextStyle(fontSize: 10)),
        pw.Text(
          v,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Preview')),
      body: PdfPreview(
        build: _buildPdf,
        canChangeOrientation: true,
        canChangePageFormat: true,
        pdfFileName: 'invoice_${inv['docNumber'] ?? ''}.pdf',
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
