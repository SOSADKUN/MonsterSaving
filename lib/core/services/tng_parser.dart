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

class TngTableLayout {
  const TngTableLayout(this.columns, this.orientation, this.headerEnd);
  final List<double> columns;
  final int orientation, headerEnd;

  PdfRect orient(PdfRect rect) => switch (orientation) {
    1 => PdfRect(rect.bottom, -rect.left, rect.top, -rect.right),
    2 => PdfRect(-rect.top, rect.right, -rect.bottom, rect.left),
    3 => PdfRect(-rect.right, -rect.bottom, -rect.left, -rect.top),
    _ => rect,
  };
}

class TngParser {
  /// Continuation pages in date-range exports do not repeat the table headers.
  static TngTableLayout? readLayout(PdfPageRawText page) {
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
    final header = RegExp(r'\bDate\s+Status\b').firstMatch(text);
    if (header == null) return null;
    final start = header.start;
    final positions = <int>[];
    var cursor = start;
    for (final h in headers) {
      final pattern = h.split(' ').map(RegExp.escape).join(r'\s+');
      final match = RegExp(pattern).firstMatch(text.substring(cursor));
      final i = match == null ? -1 : cursor + match.start;
      if (match == null || i < 0 || i >= page.charRects.length) {
        throw FormatException(tr('tng_parser.002'));
      }
      positions.add(i);
      cursor = i + match.group(0)!.length;
    }
    final first = page.charRects[positions.first];
    final last = page.charRects[positions.last];
    final dx = last.left - first.left;
    final dy = last.top - first.top;
    // Preserve the orientation and column positions across landscape pages.
    final orientation = dy.abs() > dx.abs()
        ? (dy > 0 ? 1 : 2)
        : (dx >= 0 ? 0 : 3);
    final layout = TngTableLayout(const [], orientation, cursor);
    final xs = positions
        .map((i) => layout.orient(page.charRects[i]).left - 2)
        .toList();
    for (var i = 1; i < xs.length; i++) {
      if (xs[i] <= xs[i - 1]) throw FormatException(tr('tng_parser.003'));
    }
    return TngTableLayout(List.unmodifiable(xs), orientation, cursor);
  }

  static List<TngTransaction> parsePage(
    PdfPageRawText page,
    double pageHeight, {
    TngTableLayout? continuationLayout,
  }) {
    final text = page.fullText;
    final ownLayout = readLayout(page);
    final layout = ownLayout ?? continuationLayout;
    if (layout == null) throw FormatException(tr('tng_parser.001'));
    final cursor = ownLayout?.headerEnd ?? 0;
    final rects = page.charRects.map(layout.orient).toList();
    final xs = layout.columns;
    final dates = RegExp(r'\b\d{1,2}/\d{1,2}/\d{4}\b').allMatches(text).where((
      m,
    ) {
      final r = rects[m.start];
      return m.start >= cursor && r.left >= xs[0] && r.left < xs[1];
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

  static ({DateTime start, DateTime end})? readPeriod(String text) {
    final headerEnd = RegExp(r'\bDate\s+Status\b').firstMatch(text)?.start;
    final header = text
        .substring(0, headerEnd ?? (text.length < 4096 ? text.length : 4096))
        .replaceAll(RegExp(r'\s+'), ' ');
    final words = RegExp(
      r'\b(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})\s*[-–]\s*(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})\b',
    ).firstMatch(header);
    DateTime date(String day, String month, String year) {
      final d = int.parse(day), m = int.parse(month), y = int.parse(year);
      final value = DateTime(y, m, d);
      if (value.day != d || value.month != m || value.year != y) {
        throw FormatException(tr('tng_parser.005'));
      }
      return value;
    }

    if (words != null) {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final firstMonth = months[words[2]!.substring(0, 3).toLowerCase()];
      final lastMonth = months[words[5]!.substring(0, 3).toLowerCase()];
      if (firstMonth == null || lastMonth == null) return null;
      return (
        start: date(words[1]!, '$firstMonth', words[3]!),
        end: date(words[4]!, '$lastMonth', words[6]!),
      );
    }
    final numeric = RegExp(
      r'\b(\d{1,2})/(\d{1,2})/(\d{4})\s*[-–]\s*(\d{1,2})/(\d{1,2})/(\d{4})\b',
    ).firstMatch(header);
    if (numeric == null) return null;
    return (
      start: date(numeric[1]!, numeric[2]!, numeric[3]!),
      end: date(numeric[4]!, numeric[5]!, numeric[6]!),
    );
  }
}
