import 'dart:io' as io;

import 'package:drift/drift.dart';

import 'package:drift/native.dart';
import 'package:jhentai/src/exception/upload_exception.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@DriftDatabase(include: {'gallery_downloaded.drift', 'archive_downloaded.drift', 'tag.drift'})
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (Migrator m, int from, int to) async {
        Log.info('Database version: $from -> $to');
        try {
          if (from < 2) {
            await m.alterTable(TableMigration(image));
          }
        } on Exception catch (e) {
          Log.error(e);
          Log.upload(e, extraInfos: {'from': from, 'to': to});
          throw UploadException(e);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = io.File(p.join(PathSetting.appSupportDir.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

AppDb appDb = AppDb();
