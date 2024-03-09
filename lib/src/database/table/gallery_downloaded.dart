import 'package:drift/drift.dart';

@TableIndex(name: 'g_idx_insert_time', columns: {#insertTime})
@TableIndex(name: 'g_idx_sort_order', columns: {#sortOrder})
@TableIndex(name: 'g_idx_group_name', columns: {#groupName})
class GalleryDownloaded extends Table {
  @override
  String? get tableName => 'gallery_downloaded_v2';

  IntColumn get gid => integer()();

  TextColumn get token => text()();

  TextColumn get title => text()();

  TextColumn get category => text()();

  IntColumn get pageCount => integer()();

  TextColumn get galleryUrl => text()();

  TextColumn get oldVersionGalleryUrl => text().nullable()();

  TextColumn get uploader => text().nullable()();

  TextColumn get publishTime => text()();

  IntColumn get downloadStatusIndex => integer()();

  TextColumn get insertTime => text()();

  BoolColumn get downloadOriginalImage => boolean().withDefault(const Constant(false))();

  IntColumn get priority => integer()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get groupName => text()();

  @override
  Set<Column<Object>>? get primaryKey => {gid};
}

class GalleryDownloadedOld extends Table {
  @override
  String? get tableName => 'gallery_downloaded';

  IntColumn get gid => integer()();

  TextColumn get token => text()();

  TextColumn get title => text()();

  TextColumn get category => text()();

  IntColumn get pageCount => integer().named('pageCount')();

  TextColumn get galleryUrl => text().named('galleryUrl')();

  TextColumn get oldVersionGalleryUrl => text().named('oldVersionGalleryUrl').nullable()();

  TextColumn get uploader => text().nullable()();

  TextColumn get publishTime => text().named('publishTime')();

  IntColumn get downloadStatusIndex => integer().named('downloadStatusIndex')();

  TextColumn get insertTime => text().named('insertTime').nullable()();

  BoolColumn get downloadOriginalImage => boolean().named('downloadOriginalImage').withDefault(const Constant(false))();

  IntColumn get priority => integer().nullable()();

  IntColumn get sortOrder => integer().named('sortOrder').withDefault(const Constant(0))();

  TextColumn get groupName => text().named('groupName').nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {gid};
}
