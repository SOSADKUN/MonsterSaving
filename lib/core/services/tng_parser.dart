import '../localization/strings.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import '../models/ledger.dart';

class TngTransaction {
  final String date,
      status,
      transactionType,
      reference,
      description,
      details,
      fingerprint;
  final int amount, walletBalance;
  TngTransaction({
    required this.date,
    required this.status,
    required this.transactionType,
    required this.reference,
    required this.description,
    required this.details,
    required this.amount,
    required this.walletBalance,
  }) : fingerprint = sha256
           .convert(
             utf8.encode(
               'tng-v1|$date|${reference.replaceAll(RegExp(r'\s+'), '')}|$amount|${transactionType.toLowerCase()}',
             ),
           )
           .toString();
  String? get suggestedType {
    if (status.toLowerCase() != 'success' &&
        status.toLowerCase() != 'successful') {
      return null;
    }
    switch (transactionType.toLowerCase()) {
      case 'payment':
      case 'duitnow qr':
        return 'expense';
      case 'refund':
      case 'payment refund':
        return 'refund';
      default:
        return null;
    }
  }

  Map<String, dynamic> get metadata => {
    'format': 'tng-table-v1',
    'status': status,
    'transactionType': transactionType,
    'reference': reference,
    'details': details,
    'walletBalance': walletBalance,
  };
}

class TngParser {
  static List<TngTransaction> parsePage(
    PdfPageRawText page,
    double pageHeight,
  ) {
    final text = page.fullText;
    const headers = [
      'Date',
      'Status',
      'Transaction Type',
      'Reference',
      'Description',
      'Details',
      'Amount (RM)',
      'Wallet Balance',
    ];
    final start = text.indexOf('Date Status');
    if (start < 0) throw FormatException(tr('tng_parser.001'));
    final positions = <int>[];
    var cursor = start;
    for (final h in headers) {
      final i = text.indexOf(h, cursor);
      if (i < 0 || i >= page.charRects.length) {
        throw FormatException(tr('tng_parser.002'));
      }
      positions.add(i);
      cursor = i + h.length;
    }
    final first = page.charRects[positions.first];
    final last = page.charRects[positions.last];
    final dx = last.left - first.left;
    final dy = last.top - first.top;
    // PDF text boxes remain in unrotated coordinates, including landscape statements.
    PdfRect orient(PdfRect r) {
      if (dy.abs() > dx.abs()) {
        return dy > 0
            ? PdfRect(r.bottom, -r.left, r.top, -r.right)
            : PdfRect(-r.top, r.right, -r.bottom, r.left);
      }
      return dx >= 0 ? r : PdfRect(-r.right, -r.bottom, -r.left, -r.top);
    }

    final rects = page.charRects.map(orient).toList();
    final xs = positions.map((i) => rects[i].left - 2).toList();
    for (var i = 1; i < xs.length; i++) {
      if (xs[i] <= xs[i - 1]) throw FormatException(tr('tng_parser.003'));
    }
    final dates = RegExp(r'\b\d{2}/\d{2}/\d{4}\b').allMatches(text).where((m) {
      final r = rects[m.start];
      return m.start > cursor && r.left >= xs[0] && r.left < xs[1];
    }).toList();
    if (dates.isEmpty) throw FormatException(tr('tng_parser.004'));
    final result = <TngTransaction>[];
    for (var row = 0; row < dates.length; row++) {
      final current = dates[row];
      final y = -rects[current.start].top - 3;
      var end = row + 1 < dates.length
          ? -rects[dates[row + 1].start].top - 3
          : double.infinity;
      final footer = text.indexOf('*This', current.end);
      if (footer >= 0) {
        final fy = -rects[footer].top - 3;
        if (fy > y && fy < end) end = fy;
      }
      String column(int col) {
        final b = StringBuffer();
        double? previousY;
        for (
          var i = current.start;
          i < text.length && i < page.charRects.length;
          i++
        ) {
          final r = rects[i];
          final cy = -r.top;
          final x = (r.left + r.right) / 2;
          if (text[i] == '\r' ||
              text[i] == '\n' ||
              r.isEmpty ||
              cy < y ||
              cy >= end ||
              x < xs[col] ||
              (col + 1 < xs.length && x >= xs[col + 1])) {
            continue;
          }
          if (previousY != null && (cy - previousY).abs() > 7) b.write(' ');
          b.write(text[i]);
          previousY = cy;
        }
        return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      }

      final dateParts = current.group(0)!.split('/');
      final d = DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
      );
      if (d.day != int.parse(dateParts[0]) ||
          d.month != int.parse(dateParts[1])) {
        throw FormatException(tr('tng_parser.005'));
      }
      int amount(String s) {
        final m = RegExp(
          r'^RM\s*([0-9,]+\.\d{2})$',
          caseSensitive: false,
        ).firstMatch(s);
        if (m == null) throw FormatException(tr('tng_parser.006'));
        return cents(m.group(1)!.replaceAll(',', ''));
      }

      final reference = column(3).replaceAll(RegExp(r'\s+'), '');
      if (reference.length < 6 || column(1).isEmpty || column(2).isEmpty) {
        throw FormatException(tr('tng_parser.007'));
      }
      final parsed = TngTransaction(
        date: dateKey(d),
        status: column(1),
        transactionType: column(2),
        reference: reference,
        description: column(4),
        details: column(5),
        amount: amount(column(6)),
        walletBalance: amount(column(7)),
      );
      if (parsed.amount <= 0) throw FormatException(tr('tng_parser.008'));
      result.add(parsed);
    }
    return result;
  }
}
