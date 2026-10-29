import '../localization/strings.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../models/ledger.dart';
part 'database.g.dart';

class Snapshots extends Table {
  IntColumn get id => integer()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Snapshots])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'saving_monster',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.dart.js'),
                onResult: (result) {
                  if (result.chosenImplementation ==
                          WasmStorageImplementation.inMemory ||
                      result.chosenImplementation ==
                          WasmStorageImplementation.unsafeIndexedDb) {
                    throw StateError(tr('database.001'));
                  }
                },
              ),
            ),
      );
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      throw StateError(tr('common.migrationError', {'from': from, 'to': to}));
    },
  );
  Future<Ledger> load() async {
    final row = await (select(
      snapshots,
    )..where((s) => s.id.equals(1))).getSingleOrNull();
    return row == null ? Ledger() : Ledger.decode(row.payload);
  }

  Future<void> save(Ledger l, {Ledger? expected}) => transaction(() async {
    if (expected != null) {
      final stored = await load();
      if (jsonEncode(stored.toJson()) != jsonEncode(expected.toJson())) {
        throw StateError(tr('database.002'));
      }
    }
    await into(snapshots).insertOnConflictUpdate(
      SnapshotsCompanion.insert(
        id: const Value(1),
        payload: jsonEncode(l.toJson()),
      ),
    );
  });
}
