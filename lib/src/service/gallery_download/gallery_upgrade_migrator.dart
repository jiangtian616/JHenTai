part of 'gallery_download_service.dart';

/// Handles copying image data (bytes + metadata + super-resolution info) from
/// an old gallery version to a new one during a gallery update. Locates
/// matching images by [imageHash] and reuses their downloaded bytes instead of
/// re-downloading.
///
/// Holds a back-reference to [GalleryDownloadService] for DB writes, progress
/// updates, and metadata persistence — the migrator is an orchestration layer
/// over the service's primitives, not an independent data store.
class _GalleryUpgradeMigrator {
  final GalleryDownloadService _service;

  _GalleryUpgradeMigrator(this._service);

  /// Bulk-copy matching images by hash. Called once per gallery update after
  /// [fetchImageHashes] returns. Iterates all serialNos; for each, finds the
  /// matching old image (by hash), copies bytes, and marks the new image as
  /// downloaded.
  Future<void> copyImageInfosFromImageHashes(GalleryDownloadInfo newGallery, List<String> imageHashes) async {
    GalleryDownloadInfo? oldGallery = _service.galleries.firstWhereOrNull((e) => e.galleryUrl == newGallery.oldVersionGalleryUrl);
    if (oldGallery == null) {
      return;
    }

    /// The old gallery's image list may have been evicted from memory
    /// (download complete / read page close), so sync reads below would find
    /// nothing. Reload from DB first so byte-copy can locate old images.
    await oldGallery.ensureImagesLoaded();

    for (int serialNo = 0; serialNo < newGallery.pageCount; serialNo++) {
      if (_service._taskHasBeenPausedOrRemoved(newGallery)) {
        break;
      }

      if (newGallery.imageAtSync(serialNo)?.downloadStatus == DownloadStatus.downloaded) {
        continue;
      }

      int? oldImageSerialNo = oldGallery.images?.firstIndexWhereOrNull((e) => e?.imageHash == imageHashes[serialNo]);
      if (oldImageSerialNo == null) {
        continue;
      }

      GalleryImage? oldImage = oldGallery.imageAtSync(oldImageSerialNo);
      if (oldImage == null) {
        continue;
      }

      /// Path extension depends on the actual download URL. Old gallery may
      /// have `downloadOriginalImage=true` and stored `fullimg.php`→`jpg` on
      /// disk; we must use the same URL when recomputing the path for the new
      /// gallery so the extension matches.
      final String oldDownloadUrl = _downloadUrlFor(oldGallery.toGalleryDownloadedData(), oldImage);
      GalleryImage newImage = oldImage.copyWith(
        path: DownloadPathResolver.computeImageDownloadRelativePath(newGallery.toGalleryDownloadedData(), oldDownloadUrl, serialNo),
        downloadStatus: DownloadStatus.downloaded,
      );

      log.download('Copy old image, new serialNo: $serialNo');
      io.File oldFile = io.File(path.join(pathService.getVisibleDir().path, oldImage.path!));
      await oldFile.copy(path.join(pathService.getVisibleDir().path, newImage.path!));

      if (newGallery.imageAtSync(serialNo) == null) {
        await _service._saveNewImageInfoInDatabase(newImage, serialNo, newGallery.gid);
        newGallery.upsertImage(serialNo, newImage);
      } else {
        await _service._updateImageStatus(newGallery, newImage, serialNo, DownloadStatus.downloaded);
      }

      await _service._updateProgressAfterImageDownloaded(newGallery, serialNo);

      await superResolutionService.copyImageInfo(oldGallery.toGalleryDownloadedData(), newGallery.toGalleryDownloadedData(), oldImageSerialNo, serialNo);
    }

    _service._saveGalleryMetadataInDisk(newGallery);
  }

  /// Try to copy a single image's info using its href's originImageHash.
  /// Called from [parseImageUrlTask] before parsing the image URL — if the
  /// old gallery has a matching image, we skip the parse entirely.
  Future<void> tryCopyImageInfoFromHref(String oldVersionGalleryUrl, GalleryDownloadInfo newGallery, int newImageSerialNo) {
    final String? newImageHash = newGallery.imageHrefs[newImageSerialNo]!.originImageHash;
    return _tryCopyImageInfo(
      oldVersionGalleryUrl: oldVersionGalleryUrl,
      newGallery: newGallery,
      newImageSerialNo: newImageSerialNo,
      newImageHash: newImageHash,
      newImageDownloadStatus: DownloadStatus.downloading,
      preSaveNewImage: true,
    );
  }

  /// If two images' [imageHash] is equal, they are the same image.
  /// Called from [downloadImageTask] after parsing the image URL — if the
  /// old gallery has a matching image, we skip the download entirely.
  Future<void> tryCopyImageInfoFromImage(String oldVersionGalleryUrl, GalleryDownloadInfo newGallery, int newImageSerialNo) {
    final String? hash = newGallery.imageAtSync(newImageSerialNo)?.imageHash;
    if (hash == null) {
      return Future.value();
    }
    final String newImageHash = hash;
    return _tryCopyImageInfo(
      oldVersionGalleryUrl: oldVersionGalleryUrl,
      newGallery: newGallery,
      newImageSerialNo: newImageSerialNo,
      newImageHash: newImageHash,
      newImageDownloadStatus: null,
      preSaveNewImage: false,
    );
  }

  /// Shared core: locate the matching old image by hash, optionally persist a fresh
  /// [GalleryImage] row for the new gallery, then copy bytes + super-resolution info.
  Future<void> _tryCopyImageInfo({
    required String oldVersionGalleryUrl,
    required GalleryDownloadInfo newGallery,
    required int newImageSerialNo,
    required String? newImageHash,
    required DownloadStatus? newImageDownloadStatus,
    required bool preSaveNewImage,
  }) async {
    if (newImageHash == null) {
      return;
    }
    GalleryDownloadInfo? oldGallery = _service.galleries.firstWhereOrNull((e) => e.galleryUrl == oldVersionGalleryUrl);
    if (oldGallery == null) {
      return;
    }

    /// Same evict-concern as [copyImageInfosFromImageHashes]: reload the old
    /// gallery's image list from DB before the sync reads below.
    await oldGallery.ensureImagesLoaded();

    int? oldImageSerialNo = oldGallery.images?.firstIndexWhereOrNull((e) => e?.imageHash == newImageHash);
    if (oldImageSerialNo == null) {
      return;
    }

    GalleryImage? oldImage = oldGallery.imageAtSync(oldImageSerialNo);
    if (oldImage == null) {
      return;
    }

    if (preSaveNewImage) {
      final String oldDownloadUrl = _downloadUrlFor(oldGallery.toGalleryDownloadedData(), oldImage);
      GalleryImage newImage = oldImage.copyWith(
        path: DownloadPathResolver.computeImageDownloadRelativePath(newGallery.toGalleryDownloadedData(), oldDownloadUrl, newImageSerialNo),
        downloadStatus: newImageDownloadStatus!,
      );
      await _service._saveNewImageInfoInDatabase(newImage, newImageSerialNo, newGallery.gid);
      newGallery.upsertImage(newImageSerialNo, newImage);
    }

    await _copyImageInfo(oldImage, newGallery, newImageSerialNo);
    await superResolutionService.copyImageInfo(oldGallery.toGalleryDownloadedData(), newGallery.toGalleryDownloadedData(), oldImageSerialNo, newImageSerialNo);
  }

  Future<void> _copyImageInfo(GalleryImage oldImage, GalleryDownloadInfo newGallery, int newImageSerialNo) async {
    log.download('Copy old image, new serialNo: $newImageSerialNo');

    GalleryImage newImage = newGallery.imageAtSync(newImageSerialNo)!;

    io.File oldFile = io.File(path.join(pathService.getVisibleDir().path, oldImage.path!));
    await oldFile.copy(path.join(pathService.getVisibleDir().path, newImage.path!));

    await _service._updateImageStatus(newGallery, newImage, newImageSerialNo, DownloadStatus.downloaded);

    await _service._updateProgressAfterImageDownloaded(newGallery, newImageSerialNo);
  }
}
