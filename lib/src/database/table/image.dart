import 'package:drift/drift.dart';
import 'package:jhentai/src/database/table/gallery_downloaded.dart';

class Image extends Table {
  @override
  String? get tableName => 'image';

  IntColumn get gid => integer().references(GalleryDownloaded, #gid)();

  TextColumn get url => text()();

  IntColumn get serialNo => integer().named('serialNo')();

  TextColumn get path => text()();

  TextColumn get imageHash => text().named('imageHash')();

  IntColumn get downloadStatusIndex => integer().named('downloadStatusIndex')();

  @override
  Set<Column<Object>>? get primaryKey => {gid, serialNo};
}
