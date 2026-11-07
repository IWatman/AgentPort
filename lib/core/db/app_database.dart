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

/// An AI provider configured by the user.
///
/// The API key itself is stored in the Android Keystore; [apiKeyRef] is only
/// the lookup key.
class ProviderEntries extends Table {
  @override
  String get tableName => 'providers';

  TextColumn get id => text()();

  TextColumn get name => text()();

  /// `deepseek` or `openai`.
  TextColumn get type => text()();

  TextColumn get baseUrl => text()();

  TextColumn get model => text()();

  TextColumn get apiKeyRef => text()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Conversations extends Table {
  TextColumn get id => text()();

  /// Empty until the first user message arrives.
  TextColumn get title => text().withDefault(const Constant(''))();

  TextColumn get providerId => text().nullable().references(
    ProviderEntries,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get systemPrompt => text().nullable()();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();

  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();

  /// `system`, `user`, `assistant`, or `tool`.
  TextColumn get role => text()();

  TextColumn get content => text().withDefault(const Constant(''))();

  TextColumn get reasoning => text().nullable()();

  TextColumn get toolCallsJson => text().nullable()();

  /// `complete`, `stopped`, or `error`.
  TextColumn get status => text().withDefault(const Constant('complete'))();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [SettingEntries, ProviderEntries, Conversations, Messages],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(providerEntries);
        await migrator.createTable(conversations);
        await migrator.createTable(messages);
      }
    },
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
