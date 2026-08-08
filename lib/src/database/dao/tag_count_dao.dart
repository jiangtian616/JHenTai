import '../database.dart';

class TagCountDao {
  static const int _batchSize = 500;

  /// Rebuilds the whole tag-count table in a single transaction, 500 rows per
  /// batch. The previous 10 ms delay between batches served no UI purpose:
  /// drift runs all statements on a background isolate
  /// (`NativeDatabase.createInBackground`), so the main isolate never blocks
  /// on these inserts.
  static Future<void> replaceTagCount(List<TagCountData> tagCountData) {
    return appDb.transaction(() async {
      await deleteAllTagCount();

      for (int i = 0; i < tagCountData.length; i += _batchSize) {
        await appDb.batch((batch) {
          batch.insertAll(appDb.tagCount, tagCountData.skip(i).take(_batchSize).toList());
        });
      }
    });
  }

  static Future<List<TagCountData>> batchSelectTagCount(List<String> namespaceWithKeys) {
    return (appDb.select(appDb.tagCount)..where((tbl) => tbl.namespaceWithKey.isIn(namespaceWithKeys))).get();
  }

  static Future<int> insertTagCount(TagCountData tagCountData) {
    return appDb.into(appDb.tagCount).insert(tagCountData);
  }

  static Future<int> deleteAllTagCount() {
    return appDb.delete(appDb.tagCount).go();
  }
}
