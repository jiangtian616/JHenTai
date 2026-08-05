import '../../database/dao/gallery_image_dao.dart';
import '../../database/database.dart';
import '../../model/gallery_image.dart';
import 'gallery_download_service.dart';

/// Per-gallery image index + full-data cache. Owns the two-tier lazy-loading
/// lifecycle:
///   - **Index** (always resident): `List<GalleryImageIndex?>` mirroring DB
///     rows. Slot 0 (cover) loaded at startup; full index lazy-loads on first
///     access to the gallery.
///   - **Cache** (lazy + evictable): `Map<int, GalleryImage>` with runtime
///     fields (reloadKey, originalImageUrl, dimensions). Pre-loaded when a
///     download starts; evicted when the gallery reaches `downloaded`.
///
/// External callers should prefer the typed accessors ([indexAt], [imageAt])
/// over touching the raw fields.
class GalleryImageCache {
  final int gid;
  final int pageCount;
  final GalleryDownloadProgress downloadProgress;

  GalleryImageCache({
    required this.gid,
    required this.pageCount,
    required this.downloadProgress,
    List<GalleryImageIndex?>? initialIndices,
  }) : imageIndices = initialIndices ?? List.generate(pageCount, (_) => null);

  /// Lightweight index per serialNo. Always resident. slot=null = no DB row.
  List<GalleryImageIndex?> imageIndices;

  /// Full GalleryImage data (url/reloadKey/originalImageUrl/dimensions). Lazy-loaded.
  Map<int, GalleryImage>? imagesCache;
  Future<void>? _imagesCacheLoadingFuture;
  bool _imageIndicesLoaded = false;

  /// Synchronous index read (path, downloadStatus, imageHash, url). O(1).
  GalleryImageIndex? indexAt(int serialNo) {
    return serialNo >= 0 && serialNo < imageIndices.length ? imageIndices[serialNo] : null;
  }

  /// Lazy-load the full imageIndices for this gallery from DB. Idempotent.
  Future<void> ensureImageIndicesLoaded() async {
    if (_imageIndicesLoaded) return;
    if (_imagesCacheLoadingFuture != null) {
      return _imagesCacheLoadingFuture!;
    }
    final List<GalleryImageIndex> rows = await GalleryImageDao.selectImageIndicesByGid(gid);
    for (final idx in rows) {
      if (idx.serialNo < imageIndices.length) {
        imageIndices[idx.serialNo] = idx;
      }
    }
    for (int i = 0; i < imageIndices.length; i++) {
      downloadProgress.hasDownloaded[i] =
          imageIndices[i]?.downloadStatus == DownloadStatus.downloaded;
    }
    _imageIndicesLoaded = true;
  }

  /// Lazy-load the full imagesCache from DB. Idempotent + concurrent-safe.
  Future<void> ensureImagesCacheLoaded() async {
    if (imagesCache != null) return;
    if (_imagesCacheLoadingFuture != null) return _imagesCacheLoadingFuture!;
    _imagesCacheLoadingFuture = _loadImagesCache().whenComplete(() {
      _imagesCacheLoadingFuture = null;
    });
    return _imagesCacheLoadingFuture!;
  }

  Future<void> _loadImagesCache() async {
    await ensureImageIndicesLoaded();
    final List<ImageData> rows = await GalleryImageDao.selectImagesByGalleryId(gid);
    imagesCache = {
      for (final d in rows)
        d.serialNo: GalleryImage(
          url: d.url,
          path: d.path,
          imageHash: d.imageHash.isEmpty ? null : d.imageHash,
          downloadStatus: DownloadStatus.values[d.downloadStatusIndex],
        ),
    };
  }

  /// Evict the full-data cache after download completes. Index is retained.
  void evictImagesCache() {
    imagesCache = null;
  }

  /// Read the full [GalleryImage] for [serialNo]. Triggers lazy-load if needed.
  Future<GalleryImage?> imageAt(int serialNo) async {
    if (indexAt(serialNo) == null) return null;
    await ensureImagesCacheLoaded();
    return imagesCache?[serialNo];
  }

  /// Synchronously read a resident full [GalleryImage], or null if cache is evicted.
  GalleryImage? imageAtSync(int serialNo) {
    return imagesCache?[serialNo];
  }

  /// Write a freshly parsed/created [GalleryImage] at [serialNo]: update index + cache.
  void upsertImage(int serialNo, GalleryImage image) {
    imageIndices[serialNo] = GalleryImageIndex(
      serialNo: serialNo,
      url: image.url,
      path: image.path,
      downloadStatus: image.downloadStatus,
      imageHash: image.imageHash,
    );
    imagesCache?[serialNo] = image;
  }

  /// Update index downloadStatus. Mirrors to cache if resident.
  void updateImageStatus(int serialNo, DownloadStatus status) {
    final GalleryImageIndex? idx = imageIndices[serialNo];
    if (idx != null) {
      idx.downloadStatus = status;
    }
    imagesCache?[serialNo]?.downloadStatus = status;
  }

  /// Update index path. Mirrors to cache if resident.
  void updateImagePath(int serialNo, String? newPath) {
    final GalleryImageIndex? idx = imageIndices[serialNo];
    if (idx != null) {
      idx.path = newPath;
    }
    imagesCache?[serialNo]?.path = newPath;
  }

  /// Clear an image slot (re-parse scenario): drop index + cache entry.
  void clearImage(int serialNo) {
    imageIndices[serialNo] = null;
    imagesCache?.remove(serialNo);
  }
}
