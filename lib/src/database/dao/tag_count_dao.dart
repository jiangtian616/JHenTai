import '../database.dart';

class TagCountDao {
  static const int _batchSize = 200;

  static Future<void> updateTagCount(List<TagCountData> tagCountData) {
    return appDb.transaction(() async {
      await appDb.deleteAllTagCount();

      for (int i = 0; i < tagCountData.length; i += _batchSize) {
        await appDb.batch((batch) {
          batch.insertAll(appDb.tagCount, tagCountData.skip(i).take(_batchSize).toList());
        });

        await Future.delayed(const Duration(milliseconds: 10));
      }
    });
  }

  static Future<List<TagCountData>> batchSelectTagCount(List<String> namespaceWithKeys) {
    return (appDb.select(appDb.tagCount)..where((tbl) => tbl.namespaceWithKey.isIn(namespaceWithKeys))).get();
  }
}
