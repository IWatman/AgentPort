import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Key/value storage for app settings.
///
/// Typed settings live in code, so adding a setting does not require a schema
/// migration. Sensitive values never go here — use [SecureStore] instead.
class SettingEntries extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [SettingEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Opens the encrypted database in a background isolate.
///
/// [keyHex] is a 32-byte SQLCipher key encoded as hex. The raw-key syntax
/// (`x'...'`) avoids escaping problems and skips key derivation.
AppDatabase openEncryptedDatabase({
  required File file,
  required String keyHex,
}) {
  return AppDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute('PRAGMA key = "x\'$keyHex\'";');
        database.execute('PRAGMA cipher_memory_security = ON;');
        database.execute('PRAGMA journal_mode = WAL;');
      },
    ),
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be provided during bootstrap.');
});
