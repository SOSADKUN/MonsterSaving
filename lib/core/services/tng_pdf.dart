import '../localization/strings.dart';
import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';
import 'tng_parser.dart';
import '../models/ledger.dart';

class TngStatement {
  const TngStatement({
    required this.transactions,
    required this.start,
    required this.end,
  });
  final List<TngTransaction> transactions;
  final DateTime start, end;
}

class TngPdf {
  static Future<List<TngTransaction>> extract(
    Uint8List bytes,
    String password,
  ) async => (await extractStatement(bytes, password)).transactions;

  static Future<TngStatement> extractStatement(
    Uint8List bytes,
    String password,
  ) async {
    if (bytes.length > 20 * 1024 * 1024 ||
        bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw FormatException(tr('tng_pdf.001'));
    }
    await pdfrxFlutterInitialize();
    final doc = await PdfDocument.openData(
      bytes,
      sourceName: 'local-tng-statement',
      passwordProvider: createSimplePasswordProvider(password),
    );
    try {
      if (doc.pages.length > 100) throw FormatException(tr('tng_pdf.002'));
      final rows = <TngTransaction>[];
      TngTableLayout? layout;
      ({DateTime start, DateTime end})? period;
      for (final page in doc.pages) {
        final raw = await page.loadText();
        if (raw == null || raw.fullText.trim().isEmpty) {
          throw FormatException(tr('tng_pdf.003'));
        }
        if (rows.isEmpty &&
            !raw.fullText
                .replaceAll(RegExp(r'\s+'), ' ')
                .contains('TNG WALLET TRANSACTION HISTORY')) {
          throw FormatException(tr('tng_pdf.004'));
        }
        if (rows.isEmpty) period = TngParser.readPeriod(raw.fullText);
        layout = TngParser.readLayout(raw) ?? layout;
        rows.addAll(
          TngParser.parsePage(raw, page.height, continuationLayout: layout),
        );
      }
      if (rows.map((r) => r.fingerprint).toSet().length != rows.length) {
        throw FormatException(tr('tng_pdf.005'));
      }
      if (rows.isEmpty) throw FormatException(tr('tng_parser.004'));
      final dates = rows.map((row) => row.date).toList()..sort();
      final start = period?.start ?? DateTime.parse(dates.first);
      final end = period?.end ?? DateTime.parse(dates.last);
      if (end.isBefore(start) ||
          rows.any((row) {
            final date = DateTime.parse(row.date);
            return date.isBefore(start) || date.isAfter(end);
          })) {
        throw FormatException(tr('tng_pdf.periodMismatch'));
      }
      final periodDays = DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
      // Keep explicit range-review coverage bounded even for malformed metadata.
      if (periodDays > 3660) throw FormatException(tr('tng_pdf.rangeTooLong'));
      return TngStatement(transactions: rows, start: day(start), end: day(end));
    } finally {
      await doc.dispose();
    }
  }
}
