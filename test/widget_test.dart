import 'package:saving_monster/core/localization/strings.dart';
import 'support/localization.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saving_monster/app/state.dart';
import 'package:saving_monster/app/shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:saving_monster/core/models/ledger.dart';
import 'package:saving_monster/core/services/finance.dart';
import 'package:saving_monster/core/database/database.dart';

Ledger sample() => Ledger(
  profile: {
    'opening': 100000,
    'openingDate': '2026-02-01',
    'salary': 300000,
    'payday': 31,
    'lastSalary': null,
    'target': 20000,
    'goal': 1000000,
    'saved': 0,
    'coverage': null,
  },
);
void main() {
  setUpAll(loadTestTranslations);
  test('Clamped payday uses local calendar, inclusive remaining days', () {
    final l = sample();
    final f = Finance.calculate(l, DateTime(2026, 2, 28));
    expect(f.start, DateTime(2026, 2, 28));
    expect(f.end, DateTime(2026, 3, 31));
    expect(f.remainingDays, 31);
    expect(Finance.calculate(l, DateTime(2026, 3, 30)).remainingDays, 1);
    expect(Finance.payday(2024, 2, 31), DateTime(2024, 2, 29));
  });
  test(
    'Snapshot, confirmed income, historical edits, negative budget and savings',
    () {
      final l = sample();
      l.entries = [
        Entry(id: 'pre', date: '2026-01-31', type: 'salary', amount: 300000),
        Entry(id: 'e', date: '2026-02-05', type: 'expense', amount: 90000),
        Entry(id: 'r', date: '2026-02-06', type: 'refund', amount: 5000),
      ];
      var f = Finance.calculate(l, DateTime(2026, 2, 10));
      expect(f.balance, 15000);
      expect(f.income, 300000);
      expect(f.spending, 90000);
      expect(f.available, -5000);
      l.entries.removeWhere((e) => e.id == 'e');
      expect(Finance.calculate(l, DateTime(2026, 2, 10)).balance, 105000);
      l.profile!['target'] = 50000;
      expect(l.entries.length, 2);
      expect(Finance.calculate(l, DateTime(2026, 2, 10)).balance, 105000);
    },
  );
  test(
    'Backup validates version, dates and ownership; rewards survive deletion',
    () {
      final l = sample();
      l.achievements.add('record:2026-02-03');
      l.inventory.add('flower');
      expect(l.coins, -10);
      expect(
        () => Ledger.decode(jsonEncode(l.toJson())),
        throwsFormatException,
      );
      l.inventory.clear();
      l.achievements.add('record:2026-02-03');
      expect(l.exp, 25);
      final restored = Ledger.decode(jsonEncode(l.toJson()));
      expect(restored.exp, 25);
      final j = l.toJson()..['version'] = 2;
      expect(() => Ledger.decode(jsonEncode(j)), throwsFormatException);
    },
  );
  test('Schema v1 creates, atomically saves, reopens and rolls back', () async {
    final directory = await Directory.systemTemp.createTemp(
      'saving-monster-test-',
    );
    final file = File('${directory.path}/ledger.sqlite');
    final executor = NativeDatabase(file);
    final db = AppDatabase(executor);
    final l = sample();
    await db.save(l);
    expect((await db.load()).profile!['opening'], 100000);
    await expectLater(
      db.transaction(() async {
        await db.save(Ledger());
        throw StateError('rollback');
      }),
      throwsStateError,
    );
    expect((await db.load()).profile!['opening'], 100000);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      1,
    );
    await db.close();
    final reopened = AppDatabase(NativeDatabase(file));
    expect((await reopened.load()).profile!['opening'], 100000);
    final stale = await reopened.load();
    final updated = stale.copy()..profile!['target'] = 25000;
    await reopened.save(updated, expected: stale);
    await expectLater(reopened.save(stale, expected: stale), throwsStateError);
    expect((await reopened.load()).profile!['target'], 25000);
    await reopened.close();
    await directory.delete(recursive: true);
  });
  testWidgets('Guest startup and mobile dashboard render without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    await db.save(sample());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(tr('shell.009')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip(tr('shell.044')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(tr('shell.002')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
