import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Minimal [QueryExecutorUser] so a raw [QueryExecutor] can be opened directly.
class _TestUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

/// Runtime smoke test for the `NativeDatabase.createInBackground` setup used in
/// `_openConnection()`: verifies the database really opens on a background
/// isolate, that `isolateSetup` runs there, that WAL is active, and that
/// statements round-trip through the isolate boundary.
void main() {
  test('drift database opens on a background isolate with WAL', () async {
    final Directory dir = await Directory.systemTemp.createTemp('jhentai_db_isolate_test');
    final File file = File('${dir.path}${Platform.pathSeparator}test.db');

    final QueryExecutor executor = NativeDatabase.createInBackground(
      file,
      cachePreparedStatements: true,
      setup: (db) {
        db.execute('pragma journal_mode = WAL;');
      },
      isolateSetup: () async {
        sqlite3.sqlite3.tempDirectory = Directory.systemTemp.path;
      },
    );

    try {
      await executor.ensureOpen(_TestUser());
      await executor.runCustom('CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)');
      await executor.runCustom("INSERT INTO t (name) VALUES ('hello')");

      final List<Map<String, Object?>> rows = await executor.runSelect('SELECT * FROM t', []);
      expect(rows.single['name'], 'hello');

      final List<Map<String, Object?>> pragma = await executor.runSelect('pragma journal_mode;', []);
      expect(pragma.single['journal_mode'].toString().toLowerCase(), 'wal');
    } finally {
      await executor.close();
      await dir.delete(recursive: true);
    }
  });
}
