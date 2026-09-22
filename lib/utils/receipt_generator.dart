import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models/transaction_model.dart';
import '../data/models/payment_model.dart';
import '../data/models/store_model.dart';
import 'formatters.dart';

class ReceiptGenerator {
  /// Generate and share a debt/credit transaction receipt
  static Future<void> shareTransactionReceipt({
    required Store store,
    required DebtTransaction transaction,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            _header(store),
            pw.SizedBox(height: 12),
            _divider(),
            pw.SizedBox(height: 8),

            pw.Text('DEBT TRANSACTION RECEIPT',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 8),

            _row('Transaction ID', transaction.transactionId),
            _row('Date', AppFormatter.dateTime(transaction.transactionDate)),
            if (transaction.dueDate != null)
              _row('Due Date', AppFormatter.date(transaction.dueDate!)),
            _divider(),
            pw.SizedBox(height: 6),

            pw.Text('Customer',
                style: pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
            pw.Text(transaction.customerName,
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Items
            if (transaction.items.isNotEmpty) ...[
              pw.Text('Items',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              ...transaction.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${item.itemName} × ${item.quantity} ${item.unit}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Text(
                          AppFormatter.currency(item.totalPrice,
                              symbol: store.currencySymbol),
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  )),
              _divider(),
              pw.SizedBox(height: 4),
            ],

            _totalRow('Total Amount', transaction.totalAmount,
                store.currencySymbol, bold: true),
            _totalRow('Amount Paid', transaction.amountPaid,
                store.currencySymbol),
            _totalRow('Remaining Balance', transaction.remainingBalance,
                store.currencySymbol,
                bold: true,
                color: transaction.remainingBalance > 0
                    ? PdfColors.red700
                    : PdfColors.green700),

            if (transaction.notes != null) ...[
              pw.SizedBox(height: 8),
              pw.Text('Note: ${transaction.notes}',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic)),
            ],

            pw.SizedBox(height: 12),
            _divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                transaction.remainingBalance <= 0
                    ? '✓ FULLY PAID — Thank you!'
                    : 'Thank you! Please settle your balance.',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: transaction.remainingBalance <= 0
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 4),
            _footer(),
          ],
        ),
      ),
    );

    await _saveAndShare(pdf,
        'receipt_${transaction.transactionId.replaceAll('-', '_')}.pdf');
  }

  /// Generate and share a payment receipt
  static Future<void> sharePaymentReceipt({
    required Store store,
    required Payment payment,
    required double remainingBalance,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(store),
            pw.SizedBox(height: 12),
            _divider(),
            pw.SizedBox(height: 8),

            pw.Text('PAYMENT RECEIPT',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 8),

            _row('Payment ID', payment.paymentId),
            _row('Transaction Ref', payment.txTransactionId),
            _row('Date', AppFormatter.dateTime(payment.paymentDate)),
            _row('Method', payment.paymentMethodLabel),
            if (payment.referenceNumber != null)
              _row('Reference', payment.referenceNumber!),
            _divider(),
            pw.SizedBox(height: 6),

            pw.Text('Customer',
                style: pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
            pw.Text(payment.customerName,
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),

            // Amount paid (big)
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('Amount Paid',
                      style: pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
                  pw.Text(
                    AppFormatter.currency(payment.amount,
                        symbol: store.currencySymbol),
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            _totalRow('Remaining Balance', remainingBalance,
                store.currencySymbol,
                bold: true,
                color: remainingBalance <= 0
                    ? PdfColors.green700
                    : PdfColors.red700),

            if (payment.notes != null) ...[
              pw.SizedBox(height: 8),
              pw.Text('Note: ${payment.notes}',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic)),
            ],

            pw.SizedBox(height: 12),
            _divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                remainingBalance <= 0
                    ? '✓ FULLY PAID — Debt cleared!'
                    : 'Balance remaining: ${AppFormatter.currency(remainingBalance, symbol: store.currencySymbol)}',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: remainingBalance <= 0
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: remainingBalance <= 0
                        ? PdfColors.green700
                        : null),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 4),
            _footer(),
          ],
        ),
      ),
    );

    await _saveAndShare(pdf,
        'payment_${payment.paymentId.replaceAll('-', '_')}.pdf');
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static pw.Widget _header(Store store) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          store.name,
          style: pw.TextStyle(
              fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        if (store.address != null)
          pw.Text(store.address!,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        if (store.phone != null)
          pw.Text(store.phone!,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    );
  }

  static pw.Widget _footer() {
    return pw.Center(
      child: pw.Text(
        'Generated by UtangMate • ${AppFormatter.dateTime(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _divider() =>
      pw.Divider(thickness: 0.5, color: PdfColors.grey400);

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    double amount,
    String symbol, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: bold ? 10 : 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color ?? PdfColors.black)),
          pw.Text(
            AppFormatter.currency(amount, symbol: symbol),
            style: pw.TextStyle(
                fontSize: bold ? 11 : 10,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? PdfColors.black),
          ),
        ],
      ),
    );
  }

  static Future<void> _saveAndShare(
      pw.Document pdf, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Receipt from UtangMate',
    );
  }
}
