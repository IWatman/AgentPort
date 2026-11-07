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

  /// Optional per-conversation model override.
  TextColumn get model => text().nullable()();

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

  /// JSON list of image or text-file attachments.
  TextColumn get attachmentsJson => text().nullable()();

  /// OpenAI `tool_call_id` for a tool-result message.
  TextColumn get toolCallId => text().nullable()();

  /// `complete`, `stopped`, or `error`.
  TextColumn get status => text().withDefault(const Constant('complete'))();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A Claude-compatible plugin marketplace.
class MarketplaceEntries extends Table {
  @override
  String get tableName => 'marketplaces';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get description => text().withDefault(const Constant(''))();

  /// Repository or page the user added, for display and re-resolution.
  TextColumn get sourceUrl => text()();

  /// Direct URL of `.claude-plugin/marketplace.json`.
  TextColumn get manifestUrl => text()();

  BoolColumn get builtIn => boolean().withDefault(const Constant(false))();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  TextColumn get etag => text().nullable()();

  IntColumn get lastSyncedAt => integer().nullable()();

  TextColumn get lastError => text().nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A plugin listed by a marketplace.
///
/// Catalog metadata is refreshed from the network. Installation state is local
/// and survives catalog refreshes.
class MarketplacePluginEntries extends Table {
  @override
  String get tableName => 'marketplace_plugins';

  TextColumn get id => text()();

  TextColumn get marketplaceId =>
      text().references(MarketplaceEntries, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  TextColumn get displayName => text().nullable()();

  TextColumn get description => text().withDefault(const Constant(''))();

  TextColumn get author => text().nullable()();

  TextColumn get category => text().nullable()();

  TextColumn get homepage => text().nullable()();

  TextColumn get version => text().nullable()();

  /// Raw `source` value from the marketplace manifest.
  TextColumn get sourceJson => text()();

  /// `path`, `git-subdir`, `url`, or `command`.
  TextColumn get sourceKind => text()();

  TextColumn get sourceUrl => text().nullable()();

  TextColumn get sourcePath => text().nullable()();

  TextColumn get sourceRef => text().nullable()();

  TextColumn get sourceSha => text().nullable()();

  BoolColumn get installed => boolean().withDefault(const Constant(false))();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// `unknown`, `none`, `remote`, `stdio`, `mixed`, `unsupported`, or `error`.
  TextColumn get mcpStatus => text().withDefault(const Constant('unknown'))();

  /// Parsed server configurations, without secrets.
  TextColumn get mcpConfigJson => text().nullable()();

  IntColumn get mcpCheckedAt => integer().nullable()();

  /// Remote server configs captured at install time for change detection.
  TextColumn get installedConfigJson => text().nullable()();

  BoolColumn get needsReconsent =>
      boolean().withDefault(const Constant(false))();

  TextColumn get lastError => text().nullable()();

  IntColumn get lastSeenAt => integer()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// An installed remote MCP server.
///
/// Secrets are never stored here. Header names and placeholder expressions are
/// kept so the authorization flow can ask for the missing values.
class McpServerEntries extends Table {
  @override
  String get tableName => 'mcp_servers';

  TextColumn get id => text()();

  TextColumn get pluginId => text().nullable().references(
    MarketplacePluginEntries,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get marketplaceId => text().nullable()();

  TextColumn get name => text()();

  TextColumn get url => text()();

  /// `http` or `sse`.
  TextColumn get transport => text()();

  /// `oauth`, `api-key`, `none`, or `unknown`.
  TextColumn get authType => text()();

  /// JSON array of header names that require values.
  TextColumn get headerNamesJson => text().nullable()();

  TextColumn get configHash => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  BoolColumn get needsReconsent =>
      boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tools discovered from an installed MCP server.
class McpToolEntries extends Table {
  @override
  String get tableName => 'mcp_tools';

  TextColumn get id => text()();

  TextColumn get serverId =>
      text().references(McpServerEntries, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  TextColumn get description => text().withDefault(const Constant(''))();

  TextColumn get schemaJson => text()();

  BoolColumn get needsApproval => boolean().withDefault(const Constant(true))();

  IntColumn get discoveredAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    SettingEntries,
    ProviderEntries,
    Conversations,
    Messages,
    MarketplaceEntries,
    MarketplacePluginEntries,
    McpServerEntries,
    McpToolEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(providerEntries);
        await migrator.createTable(conversations);
        await migrator.createTable(messages);
      }
      if (from < 3) {
        await migrator.createTable(marketplaceEntries);
        await migrator.createTable(marketplacePluginEntries);
        await migrator.createTable(mcpServerEntries);
      }
      if (from < 4) {
        await migrator.createTable(mcpToolEntries);
        await migrator.addColumn(messages, messages.toolCallId);
      }
      if (from < 5) {
        await migrator.addColumn(conversations, conversations.model);
        await migrator.addColumn(messages, messages.attachmentsJson);
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
