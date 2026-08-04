import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:path/path.dart' as path;

import '../database/database.dart';
import '../model/gallery_image.dart';
import 'download_path_resolver.dart';
import 'gallery_download_service.dart';
import 'log.dart';
import 'path_service.dart';
import 'super_resolution_service.dart';

/// Handles copying image data (bytes + metadata + super-resolution info) from
/// an old gallery version to a new one during a gallery update. Locates
/// matching images by [imageHash] and reuses their downloaded bytes instead of
/// re-downloading.
///
/// Holds a back-reference to [GalleryDownloadService] for DB writes, progress
/// updates, and metadata persistence — the migrator is an orchestration layer
/// over the service's primitives, not an independent data store.
class GalleryUpgradeMigrator {
  final GalleryDownloadService _service;

  GalleryUpgradeMigrator(this._service);

  /// Bulk-copy matching images by hash. Called once per gallery update after
  /// [fetchImageHashes] returns. Iterates all serialNos; for each, finds the
  /// matching old image (by hash), copies bytes, and marks the new image as
  /// downloaded.
  Future<void> copyImageInfosFromImageHashes(GalleryDownloadedData newGallery, List<String> imageHashes) async {
    GalleryDownloadedData? oldGallery = _service.gallerys.firstWhereOrNull((e) => e.galleryUrl == newGallery.oldVersionGalleryUrl);
    if (oldGallery == null) {
      return;
    }

    for (int serialNo = 0; serialNo < newGallery.pageCount; serialNo++) {
      if (_service.taskHasBeenPausedOrRemoved(newGallery)) {
        break;
      }

      GalleryDownloadInfo newGalleryDownloadInfo = _service.galleryDownloadInfos[newGallery.gid]!;
      if (newGalleryDownloadInfo.indexAt(serialNo)?.downloadStatus == DownloadStatus.downloaded) {
        continue;
      }

      int? oldImageSerialNo = _service.galleryDownloadInfos[oldGallery.gid]?.imageIndices.firstIndexWhereOrNull((e) => e?.imageHash == imageHashes[serialNo]);
      if (oldImageSerialNo == null) {
        continue;
      }

      GalleryImageIndex? oldIdx = _service.galleryDownloadInfos[oldGallery.gid]!.indexAt(oldImageSerialNo);
      if (oldIdx == null) {
        continue;
      }
      GalleryImage oldImage = oldIdx.toGalleryImage();

      GalleryImage newImage = oldImage.copyWith(
        path: DownloadPathResolver.computeImageDownloadRelativePath(newGallery, oldImage.url, serialNo),
        downloadStatus: DownloadStatus.downloaded,
      );

      log.download('Copy old image, new serialNo: $serialNo');
      io.File oldFile = io.File(path.join(pathService.getVisibleDir().path, oldImage.path!));
      await oldFile.copy(path.join(pathService.getVisibleDir().path, newImage.path!));

      if (newGalleryDownloadInfo.indexAt(serialNo) == null) {
        await _service.saveNewImageInfoInDatabase(newImage, serialNo, newGallery.gid);
        newGalleryDownloadInfo.upsertImage(serialNo, newImage);
      } else {
        await _service.updateImageStatus(newGallery, newImage, serialNo, DownloadStatus.downloaded);
      }

      await _service.updateProgressAfterImageDownloaded(newGallery, serialNo);

      await superResolutionService.copyImageInfo(oldGallery, newGallery, oldImageSerialNo, serialNo);
    }

    _service.saveGalleryMetadataInDisk(newGallery);
  }

  /// Try to copy a single image's info using its href's originImageHash.
  /// Called from [_parseImageUrlTask] before parsing the image URL — if the
  /// old gallery has a matching image, we skip the parse entirely.
  Future<void> tryCopyImageInfoFromHref(String oldVersionGalleryUrl, GalleryDownloadedData newGallery, int newImageSerialNo) {
    final String? newImageHash = _service.galleryDownloadInfos[newGallery.gid]!.imageHrefs[newImageSerialNo]!.originImageHash;
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
  /// Called from [_downloadImageTask] after parsing the image URL — if the
  /// old gallery has a matching image, we skip the download entirely.
  Future<void> tryCopyImageInfoFromImage(String oldVersionGalleryUrl, GalleryDownloadedData newGallery, int newImageSerialNo) {
    final String? hash = _service.galleryDownloadInfos[newGallery.gid]!.indexAt(newImageSerialNo)?.imageHash;
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
    required GalleryDownloadedData newGallery,
    required int newImageSerialNo,
    required String? newImageHash,
    required DownloadStatus? newImageDownloadStatus,
    required bool preSaveNewImage,
  }) async {
    if (newImageHash == null) {
      return;
    }
    GalleryDownloadedData? oldGallery = _service.gallerys.firstWhereOrNull((e) => e.galleryUrl == oldVersionGalleryUrl);
    if (oldGallery == null) {
      return;
    }

    int? oldImageSerialNo = _service.galleryDownloadInfos[oldGallery.gid]?.imageIndices.firstIndexWhereOrNull((e) => e?.imageHash == newImageHash);
    if (oldImageSerialNo == null) {
      return;
    }

    GalleryImageIndex? oldIdx = _service.galleryDownloadInfos[oldGallery.gid]!.indexAt(oldImageSerialNo);
    if (oldIdx == null) {
      return;
    }
    GalleryImage oldImage = oldIdx.toGalleryImage();

    if (preSaveNewImage) {
      GalleryImage newImage = oldImage.copyWith(
        path: DownloadPathResolver.computeImageDownloadRelativePath(newGallery, oldImage.url, newImageSerialNo),
        downloadStatus: newImageDownloadStatus!,
      );
      await _service.saveNewImageInfoInDatabase(newImage, newImageSerialNo, newGallery.gid);
      _service.galleryDownloadInfos[newGallery.gid]!.upsertImage(newImageSerialNo, newImage);
    }

    await _copyImageInfo(oldImage, newGallery, newImageSerialNo);
    await superResolutionService.copyImageInfo(oldGallery, newGallery, oldImageSerialNo, newImageSerialNo);
  }

  Future<void> _copyImageInfo(GalleryImage oldImage, GalleryDownloadedData newGallery, int newImageSerialNo) async {
    log.download('Copy old image, new serialNo: $newImageSerialNo');

    GalleryImage newImage = _service.galleryDownloadInfos[newGallery.gid]!.indexAt(newImageSerialNo)!.toGalleryImage();

    io.File oldFile = io.File(path.join(pathService.getVisibleDir().path, oldImage.path!));
    await oldFile.copy(path.join(pathService.getVisibleDir().path, newImage.path!));

    await _service.updateImageStatus(newGallery, newImage, newImageSerialNo, DownloadStatus.downloaded);

    await _service.updateProgressAfterImageDownloaded(newGallery, newImageSerialNo);
  }
}
