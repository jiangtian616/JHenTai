import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/database/dao/reader_bookmark_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/path_service.dart';

void main() {
  late AppDb testDb;
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('jh-bookmark-db');
    pathService.tempDir = temp;
    testDb = AppDb(executor: NativeDatabase.memory());
    appDb = testDb;
  });

  tearDown(() async {
    await testDb.close();
    await temp.delete(recursive: true);
  });

  test(
    'reader bookmark table persists multiple pages and tombstones',
    () async {
      final DateTime now = DateTime.now().toUtc();
      await ReaderBookmarkDao.upsert(
        ReaderBookmarkTableCompanion.insert(
          galleryKey: 'gallery',
          pageIndex: 3,
          createdAt: now.toIso8601String(),
          updatedAt: now.toIso8601String(),
          note: const Value('reserved'),
        ),
      );
      await ReaderBookmarkDao.upsert(
        ReaderBookmarkTableCompanion.insert(
          galleryKey: 'gallery',
          pageIndex: 7,
          createdAt: now.toIso8601String(),
          updatedAt: now.toIso8601String(),
          deletedAt: Value(now.toIso8601String()),
        ),
      );

      final rows = await ReaderBookmarkDao.selectByGalleryKey('gallery');
      expect(rows.map((row) => row.pageIndex), <int>[3, 7]);
      expect(rows.first.note, 'reserved');
      expect(rows.last.deletedAt, isNotNull);
    },
  );
}
