import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'jhentai-schema-merge-migration-',
    );
    pathService.tempDir = tempDir;
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<File> createCurrentDatabase() async {
    final File file = File('${tempDir.path}${Platform.pathSeparator}db.sqlite');
    final AppDb db = AppDb(executor: NativeDatabase(file));
    await db.customSelect('SELECT 1').getSingle();
    await db.close();
    return file;
  }

  Future<void> expectMergedSchema(File file) async {
    final AppDb db = AppDb(executor: NativeDatabase(file));
    try {
      await db.customSelect('SELECT 1').getSingle();

      final tables =
          await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table' "
                "AND name IN ('smart_cache_stat', 'reader_bookmark')",
              )
              .get();
      expect(tables.map((row) => row.data['name']).toSet(), {
        'smart_cache_stat',
        'reader_bookmark',
      });

      final imageColumns =
          await db.customSelect('PRAGMA table_info(image)').get();
      expect(
        imageColumns.map((row) => row.data['name']),
        contains('originalImageUrl'),
      );
    } finally {
      await db.close();
    }
  }

  test(
    'upstream schema 25 gains Fork tables without duplicating image column',
    () async {
      final File file = await createCurrentDatabase();
      final sqlite.Database raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE smart_cache_stat');
        raw.execute('DROP TABLE reader_bookmark');
        raw.execute('PRAGMA user_version = 25');
      } finally {
        raw.dispose();
      }

      await expectMergedSchema(file);
    },
  );

  test(
    'Fork schema 26 gains upstream image column without duplicating tables',
    () async {
      final File file = await createCurrentDatabase();
      final sqlite.Database raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('ALTER TABLE image DROP COLUMN originalImageUrl');
        raw.execute('PRAGMA user_version = 26');
      } finally {
        raw.dispose();
      }

      await expectMergedSchema(file);
    },
  );
}
