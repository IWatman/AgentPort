import 'dart:io';

import 'package:agentport/core/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates a v1 database to the current schema', () async {
    final directory = await Directory.systemTemp.createTemp('agentport-db-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/v1.sqlite');

    final legacy = sqlite3.open(file.path);
    legacy.execute(
      'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);',
    );
    legacy.execute('PRAGMA user_version = 1;');
    legacy.close();

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    await database.customSelect('SELECT model FROM conversations').get();
    await database.customSelect('SELECT attachments_json FROM messages').get();
    await database.customSelect('SELECT tool_call_id FROM messages').get();
    await database.customSelect('SELECT name FROM mcp_tools').get();
    await database.customSelect('SELECT name FROM marketplaces').get();

    expect(database.schemaVersion, 6);
  });
}
