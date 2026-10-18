import 'package:drift/drift.dart';

import '../../model/gallery_image.dart';
import '../database.dart';

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

  /// Returns cover images (serialNo == 0) for all galleries, keyed by gid.
  /// Used at startup to populate [GalleryDownloadInfo.coverImage] without
  /// loading every image into memory.
  static Future<Map<int, GalleryImage>> selectCoverImages() async {
    final List<ImageData> rows = await (appDb.select(appDb.image)..where((tbl) => tbl.serialNo.equals(0))).get();
    return {for (final d in rows) d.gid: GalleryImage.fromImageData(d)};
  }

  /// Returns downloaded-image counts per gid, **only for galleries whose own
  /// status is not `downloaded`**. Fully-downloaded galleries are skipped
  /// because [_instantiateFromDB] uses [GalleryDownloadedData.pageCount]
  /// directly for them — counting their image rows would be wasted work.
  /// For a library where most galleries are downloaded, this can cut the
  /// scanned row count by an order of magnitude at startup.
  static Future<Map<int, int>> selectDownloadedCountsByGid() async {
    final Expression<int> countExp = appDb.image.serialNo.count();
    final query = appDb.selectOnly(appDb.image)
      ..join([
        innerJoin(appDb.galleryDownloaded, appDb.galleryDownloaded.gid.equalsExp(appDb.image.gid)),
      ])
      ..addColumns([appDb.image.gid, countExp])
      ..where(
        appDb.image.downloadStatusIndex.equals(4) & appDb.galleryDownloaded.downloadStatusIndex.isNotIn([4]),
      )
      ..groupBy([appDb.image.gid]);
    final List<TypedResult> rows = await query.get();
    return {
      for (final row in rows) row.read(appDb.image.gid)!: row.read(countExp)!,
    };
  }

  static Future<int> insertImage(ImageData image) {
    return appDb.into(appDb.image).insert(image);
  }

  /// Batch-insert all images for a gallery in a single transaction. Used by
  /// `restoreTasks` to persist hundreds of image rows without N round-trips.
  static Future<void> batchInsertImages(List<ImageData> images) async {
    if (images.isEmpty) {
      return;
    }
    await appDb.batch((b) => b.insertAll(appDb.image, images));
  }

  static Future<int> updateImage(ImageCompanion image) {
    return (appDb.update(appDb.image)..where((tbl) => tbl.gid.equals(image.gid.value) & tbl.serialNo.equals(image.serialNo.value))).write(image);
  }

  /// Batch-update image status for a gallery: all images whose status matches
  /// [from] are updated to [to]. Used by pause/resume to persist per-image
  /// status so a restart doesn't leave stale `downloading` rows on a paused
  /// gallery.
  static Future<int> updateImageStatusByGallery(int gid, int fromStatusIndex, int toStatusIndex) {
    return (appDb.update(appDb.image)..where((tbl) => tbl.gid.equals(gid) & tbl.downloadStatusIndex.equals(fromStatusIndex)))
        .write(ImageCompanion(downloadStatusIndex: Value(toStatusIndex)));
  }

  /// Batch-update image status across multiple galleries: all images whose
  /// status matches [from] AND whose gid is in [gids] are updated to [to].
  /// Used by pauseAll/resumeAll to avoid N per-gallery DB round-trips.
  static Future<int> updateImageStatusByGids(Iterable<int> gids, int fromStatusIndex, int toStatusIndex) {
    final List<int> gidList = gids.toList();
    if (gidList.isEmpty) return Future.value(0);
    return (appDb.update(appDb.image)..where((tbl) => tbl.downloadStatusIndex.equals(fromStatusIndex) & tbl.gid.isIn(gidList)))
        .write(ImageCompanion(downloadStatusIndex: Value(toStatusIndex)));
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
