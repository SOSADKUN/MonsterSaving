import 'package:saving_monster/core/localization/strings.dart';
import 'support/localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:saving_monster/app/state.dart';
import 'package:saving_monster/core/database/database.dart';
import 'package:saving_monster/core/services/finance.dart';
import 'package:saving_monster/features/transactions/transaction_form.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:saving_monster/core/models/ledger.dart';
import 'package:saving_monster/core/services/tng_parser.dart';
import 'package:saving_monster/core/services/tng_phone.dart';

PdfPageRawText fixture({
  bool rotated = false,
  String type = 'Payment',
  String amount = 'RM14.40',
}) {
  final text = StringBuffer();
  final boxes = <PdfRect>[];
  void cell(String s, int col, int row) {
    for (var i = 0; i < s.length; i++) {
      final x = col * 100 + i * 4.0;
      final y = 40 + row * 50.0;
      text.write(s[i]);
      boxes.add(
        rotated
            ? PdfRect(y, x + 4, y + 8, x)
            : PdfRect(x, 600 - y, x + 4, 592 - y),
      );
    }
    text.write(' ');
    boxes.add(const PdfRect(0, 0, 0, 0));
  }

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
  for (var i = 0; i < headers.length; i++) {
    cell(headers[i], i, 0);
  }
  final values = [
    '23/10/2026',
    'Success',
    type,
    'UNIQUE12345',
    'Cafe',
    'DETAIL123',
    amount,
    'RM32.30',
  ];
  for (var i = 0; i < values.length; i++) {
    cell(values[i], i, 1);
  }
  return PdfPageRawText(text.toString(), boxes);
}

void main() {
  setUpAll(loadTestTranslations);
  testWidgets(
    'Other-payment form records a historical statement day without debiting snapshot twice',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.save(
        Ledger(
          profile: {
            'opening': 10000,
            'openingDate': '2026-10-24',
            'salary': 0,
            'payday': 25,
            'target': 0,
            'goal': 0,
            'saved': 0,
            'coverage': null,
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      await container.read(ledgerProvider.future);
      var completed = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TransactionForm(
                  type: 'expense',
                  initialDate: DateTime(2026, 10, 23),
                  onDone: () => completed = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, '7.50');
      await tester.tap(find.text(tr('transaction_form.014')));
      await tester.pumpAndSettle();
      expect(find.text(tr('transaction_form.002')), findsOneWidget);
      await tester.tap(find.text(tr('widgets.003')));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      final ledger = await db.load();
      expect(completed, isTrue);
      expect(ledger.entries.single.date, '2026-10-23');
      expect(ledger.entries.single.method, 'Cash');
      expect(ledger.entries.single.amount, 750);
      expect(Finance.calculate(ledger, DateTime(2026, 10, 28)).balance, 10000);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await db.close();
    },
  );
  test('Phone normalization removes one Malaysian trunk prefix', () {
    expect(TngPhone.password('016 123 4567'), '161234567');
    expect(TngPhone.password('+60 16 123 4567'), '161234567');
    expect(() => TngPhone.password('123'), throwsFormatException);
  });
  test(
    'Table columns distinguish expense from wallet balance in both orientations',
    () {
      for (final rotated in [false, true]) {
        final row = TngParser.parsePage(fixture(rotated: rotated), 600).single;
        expect(row.amount, 1440);
        expect(row.walletBalance, 3230);
        expect(row.date, '2026-10-23');
        expect(row.suggestedType, 'expense');
        expect(row.description, 'Cafe');
      }
    },
  );
  test(
    'Unknown transfers require review, and fingerprints survive reimport and deletion',
    () {
      final first = TngParser.parsePage(fixture(), 600).single;
      final repeat = TngParser.parsePage(fixture(rotated: true), 600).single;
      expect(first.fingerprint, repeat.fingerprint);
      expect(
        TngParser.parsePage(
          fixture(type: 'Transfer'),
          600,
        ).single.suggestedType,
        isNull,
      );
      expect(
        () => TngParser.parsePage(fixture(amount: 'not-money'), 600),
        throwsFormatException,
      );
      final l = Ledger(
        profile: {
          'opening': 0,
          'openingDate': '2026-10-01',
          'salary': 0,
          'payday': 25,
          'target': 0,
          'goal': 0,
          'saved': 0,
          'coverage': null,
        },
      );
      l.fingerprints.add(first.fingerprint);
      l.entries.add(
        Entry(
          id: 'import-1',
          date: first.date,
          type: 'expense',
          amount: first.amount,
          method: 'TNG',
          source: 'tng-pdf',
          fingerprint: first.fingerprint,
          importData: first.metadata,
        ),
      );
      final copy = l.copy();
      expect(copy.entries.single.importData!['reference'], first.reference);
      copy.entries.clear();
      expect(copy.copy().fingerprints.contains(repeat.fingerprint), isTrue);
    },
  );
}
