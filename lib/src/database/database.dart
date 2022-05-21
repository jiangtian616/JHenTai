import 'dart:io' as io;

import 'package:drift/drift.dart';

import 'package:drift/native.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@DriftDatabase(include: {'gallery_downloaded.drift', 'archive_downloaded.drift', 'tag.drift'})
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 2;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = io.File(p.join(PathSetting.appSupportDir.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

AppDb appDb = AppDb();
