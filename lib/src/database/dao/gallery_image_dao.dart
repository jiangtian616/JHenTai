import 'package:drift/drift.dart';

import '../database.dart';
import '../../service/gallery_download_service.dart' show DownloadStatus;

class GalleryImageDao {
  static Future<List<ImageData>> selectImages() {
    return appDb.select(appDb.image).get();
  }

  static Future<List<ImageData>> selectImagesByGalleryId(int gid) {
    return (appDb.select(appDb.image)
          ..where((tbl) => tbl.gid.equals(gid))
          ..orderBy([(image) => OrderingTerm(expression: image.serialNo)]))
        .get();
  }

  /// Select images for a specific gallery (alias for selectImagesByGalleryId)
  static Future<List<ImageData>> selectImagesByGid(int gid) {
    return selectImagesByGalleryId(gid);
  }

  /// Get download progress summary for all galleries without loading image data.
  /// Returns a map of gid -> (downloadedCount, totalCount).
  static Future<Map<int, ({int downloadedCount, int totalCount})>> selectDownloadProgressSummary() async {
    final result = await appDb.customSelect('''
      SELECT gid,
             COUNT(*) as total,
             SUM(CASE WHEN downloadStatusIndex = ${DownloadStatus.downloaded.index} THEN 1 ELSE 0 END) as downloaded
      FROM image
      GROUP BY gid
    ''').get();

    return Map.fromEntries(result.map((row) => MapEntry(
      row.read<int>('gid'),
      (downloadedCount: row.read<int>('downloaded'), totalCount: row.read<int>('total')),
    )));
  }

  static Future<int> insertImage(ImageData image) {
    return appDb.into(appDb.image).insert(image);
  }

  static Future<int> updateImage(ImageCompanion image) {
    return (appDb.update(appDb.image)..where((tbl) => tbl.gid.equals(image.gid.value) & tbl.serialNo.equals(image.serialNo.value))).write(image);
  }

  static Future<int> resetImageUrl(int gid, int imageIndex) {
    return (appDb.update(appDb.image)..where((tbl) => tbl.gid.equals(gid) & tbl.serialNo.equals(imageIndex))).write(const ImageCompanion(url: Value.absent()));
  }

  static Future<int> deleteImage(int gid, int serialNo) {
    return (appDb.delete(appDb.image)..where((tbl) => tbl.gid.equals(gid) & tbl.serialNo.equals(serialNo))).go();
  }

  static Future<int> deleteImagesWithGid(int gid) {
    return (appDb.delete(appDb.image)..where((tbl) => tbl.gid.equals(gid))).go();
  }
}
