import 'package:drift/drift.dart';

import '../database.dart';

class ArchiveDao {
  static Future<List<ArchiveDownloadedData>> selectArchives() {
    return (appDb.select(appDb.archiveDownloaded)..orderBy([(archive) => OrderingTerm(expression: archive.sortOrder)])).get();
  }

  static Future<int> insertArchive(ArchiveDownloadedData archive) {
    return appDb.into(appDb.archiveDownloaded).insert(archive);
  }

  static Future<int> updateArchive(ArchiveDownloadedCompanion archive) {
    return (appDb.update(appDb.archiveDownloaded)..where((a) => a.gid.equals(archive.gid.value))).write(archive);
  }

  static Future<int> reGroupArchive(String oldGroupName, String newGroupName) {
    return (appDb.update(appDb.archiveDownloaded)..where((a) => a.groupName.equals(oldGroupName)))
        .write(ArchiveDownloadedCompanion(groupName: Value(newGroupName)));
  }

  static Future<int> deleteArchive(int gid) {
    return (appDb.delete(appDb.archiveDownloaded)..where((archive) => archive.gid.equals(gid))).go();
  }

  static Future<int> updateArchiveStatus(int oldStatusIndex, int newStatusCode) {
    return (appDb.update(appDb.archiveDownloaded)..where((a) => a.archiveStatusCode.equals(oldStatusIndex)))
        .write(ArchiveDownloadedCompanion(archiveStatusCode: Value(newStatusCode)));
  }

  static Future<List<ArchiveDownloadedOldData>> selectOldArchives() {
    return (appDb.select(appDb.archiveDownloadedOld)..orderBy([(archive) => OrderingTerm(expression: archive.sortOrder)])).get();
  }

  static Future<int> updateOldArchive(ArchiveDownloadedOldCompanion archive) {
    return (appDb.update(appDb.archiveDownloadedOld)..where((a) => a.gid.equals(archive.gid.value))).write(archive);
  }
}
