import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class TagDao {
  static Future<List<TagData>> selectTagByNamespaceAndKey(String namespace, String key) async {
    return (appDb.select(appDb.tag)..where((tag) => tag.namespace.equals(namespace) & tag.key.equals(key))).get();
  }

  static Future<List<TagData>> selectTagsByKey(String key) {
    return (appDb.select(appDb.tag)..where((tag) => tag.key.equals(key))).get();
  }

  static Future<List<TagData>> selectAllTags() {
    return (appDb.select(appDb.tag)).get();
  }

  static Future<List<TagData>> searchTags(String pattern, int limit) {
    return (appDb.select(appDb.tag)
          ..where((tag) => tag.key.like(pattern) | tag.tagName.like(pattern))
          ..limit(limit))
        .get();
  }

  static Future<int> insertTag(TagData tag) {
    return appDb.into(appDb.tag).insert(tag);
  }

  static Future<int> deleteAllTags() {
    return appDb.delete(appDb.tag).go();
  }
}
