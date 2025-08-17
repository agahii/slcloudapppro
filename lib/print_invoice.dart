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
  String _money(num? v) => NumberFormat.currency(
    locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 2,
  ).format((v ?? 0).toDouble());
  String _dateIsoToLocal(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('dd-MMM-yyyy hh:mm a').format(dt.toLocal());
  }

  Future<Uint8List> _buildPdf(final PdfPageFormat format) async {
    final doc = pw.Document();

    final businessName = _s(inv['businessUnitName']).isNotEmpty
        ? _s(inv['businessUnitName'])
        : _s(inv['name']);
    final businessAddress = _s(inv['businessUnitAddress']);
    final stockLocation = _s(inv['stockLocationName']);

    final docNumber = _s(inv['docNumber']);
    final docDate = _dateIsoToLocal(_s(inv['docDate']));
    final customerName = _s(inv['customerName']);
    final customerAddress = _s(inv['deliveryAddress']).isNotEmpty
        ? _s(inv['deliveryAddress'])
        : _s(inv['customerAddress']);
    final customerMobile = _s(inv['mobileNumber']);

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

    // Styles (small for thermal)
    final base = pw.TextStyle(fontSize: 9);
    final small = pw.TextStyle(fontSize: 8, color: PdfColors.grey700);
    final bold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    final boldSmall = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

    pw.Widget dash() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Container(height: 0.8, color: PdfColors.grey600),
    );

    pw.Widget lineKV(String k, String v,
        {pw.TextStyle? kStyle, pw.TextStyle? vStyle}) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(k, style: kStyle ?? small)),
          pw.Text(v, style: vStyle ?? small),
        ],
      );
    }

    pw.Widget itemRow(Map<String, dynamic> d) {
      final name = '${_s(d["skuName"])} (${_s(d["packingName"])})';
      final batch = _s(d['batchNumber']);
      final qty = _s(d['quantity']);
      final rate = _money(d['rate'] as num?);
      final amt = _money(d['totalAmount'] as num?);

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name, style: base),
          if (batch.isNotEmpty) pw.Text('Batch: $batch', style: small),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('$qty × $rate', style: boldSmall),
              pw.Text(amt, style: boldSmall),
            ],
          ),
        ],
      );
    }

    // Use Page (NOT MultiPage) for roll formats (infinite height).
    final pageTheme = pw.PageTheme(
      pageFormat: format.copyWith(
        marginLeft: 4 * PdfPageFormat.mm,
        marginRight: 4 * PdfPageFormat.mm,
        marginTop: 4 * PdfPageFormat.mm,
        marginBottom: 6 * PdfPageFormat.mm,
      ),
    );

    doc.addPage(
      pw.Page(
        pageTheme: pageTheme,
        // Important: shrink-wrap content so it works with infinite-height pages
        build: (context) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Text(businessName, style: bold),
            if (businessAddress.isNotEmpty) pw.Text(businessAddress, style: small),
            if (stockLocation.isNotEmpty) pw.Text('Stock: $stockLocation', style: small),
            dash(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SALES INVOICE', style: bold),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (docNumber.isNotEmpty) pw.Text('No: $docNumber', style: small),
                    if (docDate.isNotEmpty) pw.Text(docDate, style: small),
                  ],
                ),
              ],
            ),
            dash(),

            // Customer
            pw.Text('Bill To', style: boldSmall),
            if (customerName.isNotEmpty) pw.Text(customerName, style: base),
            if (customerAddress.isNotEmpty)
              pw.Text(customerAddress, style: small, maxLines: 2),
            if (customerMobile.isNotEmpty)
              pw.Text('Mobile: $customerMobile', style: small),
            dash(),

            // Items (plain Column with separators)
            ...[
              for (int i = 0; i < details.length; i++) ...[
                itemRow(details[i]),
                if (i != details.length - 1) pw.SizedBox(height: 6),
              ]
            ],

            dash(),

            // Totals
            lineKV('Sub Total', _money(subTotal)),
            if (discountTotal != 0) lineKV('Discount', _money(discountTotal)),
            if (taxTotal != 0) lineKV('Tax', _money(taxTotal)),
            if (freightTotal != 0) lineKV('Freight', _money(freightTotal)),
            pw.SizedBox(height: 2),
            lineKV('Grand Total', _money(grandTotal),
                kStyle: boldSmall, vStyle: boldSmall),

            dash(),

            // Payment Summary
            pw.Text('Payment Summary', style: boldSmall),
            lineKV('Cash Received', _money(cashReceived)),
            if (bankReceived > 0) lineKV('Bank Received', _money(bankReceived)),
            if (bankReceived > 0 && accountNameBank.isNotEmpty)
              pw.Text('Bank: $accountNameBank', style: small),

            pw.SizedBox(height: 8),
            pw.Text('Thank you for your business!',
                style: small.copyWith(fontStyle: pw.FontStyle.italic)),
          ],
        ),
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    // Default to 80mm roll; you can still expose 57mm if you want.
    final pageFormats = <String, PdfPageFormat>{
      '80 mm (roll80)': PdfPageFormat.roll80,
      '57 mm (roll57)': PdfPageFormat.roll57,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Preview')),
      body: PdfPreview(
        build: (format) => _buildPdf(format),
        initialPageFormat: PdfPageFormat.roll80,
        pageFormats: pageFormats,
        canChangePageFormat: true,
        canChangeOrientation: false,
        pdfFileName: 'invoice_${inv['docNumber'] ?? ''}.pdf',
      ),
    );
  }
}
