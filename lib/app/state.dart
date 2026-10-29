import '../core/localization/strings.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database.dart';
import '../core/models/ledger.dart';
import '../core/services/nightly_reminder.dart';

final languageProvider = NotifierProvider<LanguageController, String>(
  LanguageController.new,
);

class LanguageController extends Notifier<String> {
  @override
  String build() => AppStrings.language;
  void sync(String code) {
    AppStrings.language = code;
    state = code;
  }

  Future<void> select(String code) => ref
      .read(ledgerProvider.notifier)
      .change((ledger) => ledger.language = code);
}

final databaseProvider = Provider((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
final ledgerProvider = AsyncNotifierProvider<LedgerController, Ledger>(
  LedgerController.new,
);

class LedgerController extends AsyncNotifier<Ledger> {
  bool _busy = false;
  @override
  Future<Ledger> build() async {
    final ledger = await ref.watch(databaseProvider).load();
    ref.read(languageProvider.notifier).sync(ledger.language);
    return ledger;
  }

  Future<void> change(void Function(Ledger) edit) async {
    if (_busy) {
      throw StateError(tr('state.001'));
    }
    _busy = true;
    try {
      final next = state.requireValue.copy();
      edit(next);
      final validated = Ledger.decode(jsonEncode(next.toJson()));
      await ref
          .read(databaseProvider)
          .save(validated, expected: state.requireValue);
      final languageChanged = AppStrings.language != validated.language;
      ref.read(languageProvider.notifier).sync(validated.language);
      state = AsyncData(validated);
      if (languageChanged && validated.profile?['reminderEnabled'] == true) {
        try {
          await NightlyReminder.instance.configure(
            enabled: true,
            minute: validated.profile!['reminderMinute'] as int? ?? 1260,
          );
        } catch (_) {
          /* Language persists even if the OS rejects scheduling. */
        }
      }
    } finally {
      _busy = false;
    }
  }
}
