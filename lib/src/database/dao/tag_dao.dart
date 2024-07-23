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

  static Future<List<TagData>> searchFullTags(String namespacePattern, String keyPattern) {
    return (appDb.select(appDb.tag)
          ..where((tag) =>
              (tag.namespace.like(namespacePattern) | tag.translatedNamespace.like(namespacePattern)) &
              (tag.key.like(keyPattern) | tag.tagName.like(keyPattern))))
        .get();
  }

  static Future<List<TagData>> searchFullTagsIncludeIntro(String namespacePattern, String keyPattern) {
    return (appDb.select(appDb.tag)
          ..where((tag) =>
              (tag.namespace.like(namespacePattern) | tag.translatedNamespace.like(namespacePattern)) &
              (tag.key.like(keyPattern) | tag.tagName.like(keyPattern) | tag.intro.like(keyPattern))))
        .get();
  }

  static Future<List<TagData>> searchTags(String pattern) {
    return (appDb.select(appDb.tag)..where((tag) => tag.key.like(pattern) | tag.tagName.like(pattern))).get();
  }

  static Future<List<TagData>> searchTagsIncludeIntro(String pattern) {
    return (appDb.select(appDb.tag)..where((tag) => tag.key.like(pattern) | tag.tagName.like(pattern) | tag.intro.like(pattern))).get();
  }

  static Future<int> insertTag(TagData tag) {
    return appDb.into(appDb.tag).insert(tag);
  }

  static Future<int> deleteAllTags() {
    return appDb.delete(appDb.tag).go();
  }
}
