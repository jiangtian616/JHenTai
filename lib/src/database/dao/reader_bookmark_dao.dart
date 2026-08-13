import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class ReaderBookmarkDao {
  static Future<List<ReaderBookmarkTableData>> selectByGalleryKey(
    String galleryKey,
  ) {
    return (appDb.select(appDb.readerBookmarkTable)
          ..where((tbl) => tbl.galleryKey.equals(galleryKey))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.pageIndex)]))
        .get();
  }

  static Future<int> upsert(ReaderBookmarkTableCompanion bookmark) {
    return appDb
        .into(appDb.readerBookmarkTable)
        .insertOnConflictUpdate(bookmark);
  }
}
