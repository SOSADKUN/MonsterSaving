import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:saving_monster/app/state.dart';
import 'package:saving_monster/core/database/database.dart';
import 'package:saving_monster/core/localization/strings.dart';
import 'package:saving_monster/core/models/ledger.dart';
import 'package:saving_monster/features/settings/settings.dart';
import 'support/localization.dart';

void main() {
  setUpAll(loadTestTranslations);
  setUp(() => AppStrings.language = 'en');
  test(
    'Catalogs have matching keys and placeholders with Simplified Chinese copy',
    () async {
      final en =
          jsonDecode(await rootBundle.loadString('assets/i18n/en.json'))
              as Map<String, dynamic>;
      final zh =
          jsonDecode(await rootBundle.loadString('assets/i18n/zh_CN.json'))
              as Map<String, dynamic>;
      expect(en.keys.toSet(), zh.keys.toSet());
      Set<String> placeholders(String text) => RegExp(
        r'\{[A-Za-z0-9_]+\}',
      ).allMatches(text).map((m) => m[0]!).toSet();
      for (final key in en.keys) {
        expect(en[key], isA<String>(), reason: key);
        expect(zh[key], isNotEmpty, reason: key);
        expect(placeholders(en[key]), placeholders(zh[key]), reason: key);
        if (key != 'language.chinese') {
          expect(
            RegExp(r'[\u3400-\u9fff]').hasMatch(en[key]),
            isFalse,
            reason: key,
          );
        }
        expect(
          RegExp(r'[請記餘儲設錢獸總匯額發備還週體]').hasMatch(zh[key]),
          isFalse,
          reason: key,
        );
      }
      expect(
        AppStrings.text('shell.035', {'p0': 'A', 'p1': 'B', 'p2': 3}),
        'A → B · 3 days left',
      );
    },
  );
  test(
    'Language is portable, validates allowed values and defaults old backups to English',
    () {
      final ledger = Ledger(language: 'zh_CN');
      expect(ledger.copy().language, 'zh_CN');
      final old = ledger.toJson()..remove('language');
      expect(Ledger.decode(jsonEncode(old)).language, 'en');
      expect(
        () =>
            Ledger.decode(jsonEncode(ledger.toJson()..['language'] = 'zh_TW')),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'Settings switches immediately, keeps unsaved form values and persists the language',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      await db.save(
        Ledger(
          profile: {
            'opening': 10000,
            'openingDate': '2026-10-01',
            'salary': 200000,
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
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final language = ref.watch(languageProvider);
              return MaterialApp(
                locale: language == 'en'
                    ? const Locale('en')
                    : const Locale('zh', 'CN'),
                supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: SettingsPanel(onHistory: () {}, onSalary: () {}),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(
        find.text(AppStrings.catalogs['en']!['settings.011']!),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).first, '123.45');
      await tester.tap(find.text(tr('language.english')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('language.chinese')).last);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.catalogs['zh_CN']!['settings.011']!),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.catalogs['zh_CN']!['language.label']!),
        findsOneWidget,
      );
      expect(find.text('123.45'), findsOneWidget);
      expect((await db.load()).language, 'zh_CN');
      expect((await db.load()).profile!['salary'], 200000);
      await tester.tap(find.text(tr('language.chinese')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('language.english')).last);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.catalogs['en']!['settings.011']!),
        findsOneWidget,
      );
      expect(find.text('123.45'), findsOneWidget);
      expect((await db.load()).language, 'en');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await db.close();
    },
  );
}
