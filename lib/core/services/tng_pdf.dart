import '../localization/strings.dart';
import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';
import 'tng_parser.dart';

class TngPdf {
  static Future<List<TngTransaction>> extract(
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
        rows.addAll(TngParser.parsePage(raw, page.height));
      }
      if (rows.map((r) => r.fingerprint).toSet().length != rows.length) {
        throw FormatException(tr('tng_pdf.005'));
      }
      return rows;
    } finally {
      await doc.dispose();
    }
  }
}
