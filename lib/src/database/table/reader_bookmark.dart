import 'package:drift/drift.dart';

/// Tombstone-capable page bookmarks for the future unified LAN history
/// payload. Composite identity permits multiple bookmarks per gallery.
@TableIndex(
  name: 'idx_reader_bookmark_gallery_page',
  columns: {#galleryKey, #pageIndex},
)
class ReaderBookmarkTable extends Table {
  @override
  String? get tableName => 'reader_bookmark';

  TextColumn get galleryKey => text()();

  IntColumn get pageIndex => integer()();

  TextColumn get createdAt => text()();

  TextColumn get updatedAt => text()();

  TextColumn get note => text().nullable()();

  TextColumn get sourceDeviceId => text().nullable()();

  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {galleryKey, pageIndex};
}
