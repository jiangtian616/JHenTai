import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as path;

import '../database/database.dart';
import 'download_path_resolver.dart';
import 'gallery_download_service.dart';
import 'log.dart';

/// Owns gallery metadata JSON persistence: debounced writes, immediate flush,
/// and disk reads for restore. The in-memory state lives in
/// [GalleryDownloadService.galleryDownloadInfos]; this class only handles
/// serializing that state to/from `metadata` files on disk.
class GalleryMetadataStore {
  static const String metadataFileName = 'metadata';
  static const Duration _metadataDebounce = Duration(milliseconds: 500);

  final GalleryDownloadService _service;

  /// Per-gallery debounce timers for metadata writes. Each image-status change
  /// schedules a write; rapid successive changes coalesce into one disk write.
  final Map<int, Timer> _metadataSaveTimers = {};
  final Map<int, Future<void>> _metadataWrites = {};

  GalleryMetadataStore(this._service);

  /// Schedule a debounced metadata write. Safe to call from sync contexts.
  void save(GalleryDownloadedData gallery) {
    if (!_service.galleryDownloadInfos.containsKey(gallery.gid)) {
      return;
    }
    _metadataSaveTimers[gallery.gid]?.cancel();
    _metadataSaveTimers[gallery.gid] = Timer(_metadataDebounce, () {
      _metadataSaveTimers.remove(gallery.gid);
      _metadataWrites[gallery.gid] = _write(gallery).whenComplete(() {
        _metadataWrites.remove(gallery.gid);
      });
    });
  }

  /// Cancel any pending debounced write and flush the latest state to disk now.
  Future<void> flush(GalleryDownloadedData gallery) async {
    _metadataSaveTimers[gallery.gid]?.cancel();
    _metadataSaveTimers.remove(gallery.gid);
    await _metadataWrites[gallery.gid];
    await _write(gallery);
  }

  /// Cancel any pending writes for a gallery that's being deleted.
  void cancel(int gid) {
    _metadataSaveTimers.remove(gid)?.cancel();
  }

  Future<void> _write(GalleryDownloadedData gallery) async {
    final info = _service.galleryDownloadInfos[gallery.gid];
    if (info == null) {
      return;
    }

    /// Serialize from imageIndices (always resident) — full-data cache may be
    /// evicted, but index mirrors the DB columns (url/path/hash/status) which
    /// is everything metadata JSON needs to restore. Runtime-only fields
    /// (reloadKey, originalImageUrl, dimensions) are intentionally dropped;
    /// they're re-parsed on demand after restore.
    final List<Map<String, dynamic>?> imagesJson = info.imageIndices
        .map((idx) => idx?.toGalleryImage().toJson())
        .toList();

    Map<String, Object> metadata = {
      'gallery': gallery
          .copyWith(
            downloadStatusIndex: info.downloadProgress.downloadStatus.index,
            priority: info.priority,
            groupName: info.group,
          )
          .toJson(),
      'images': jsonEncode(imagesJson),
    };

    try {
      io.File file = io.File(
        path.join(DownloadPathResolver.computeGalleryDownloadAbsolutePath(gallery), metadataFileName),
      );
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(metadata));
    } catch (e, st) {
      log.error('Save gallery metadata failed, gid: ${gallery.gid}', e, st);
    }
  }

  /// Read + parse the metadata file in [galleryDir]. Returns null if the file
  /// is missing or unparseable. Compatibility back-fills (for fields added in
  /// later versions) are applied to the gallery map before returning.
  Map<String, dynamic>? read(io.Directory galleryDir) {
    io.File metadataFile = io.File(path.join(galleryDir.path, metadataFileName));
    if (!metadataFile.existsSync()) {
      return null;
    }

    try {
      Map metadata = jsonDecode(metadataFile.readAsStringSync());

      /// compatible with new field
      (metadata['gallery'] as Map).putIfAbsent('downloadOriginalImage', () => false);
      (metadata['gallery'] as Map).putIfAbsent('sortOrder', () => 0);
      if ((metadata['gallery'] as Map)['insertTime'] == null) {
        (metadata['gallery'] as Map)['insertTime'] = DateTime.now().toString();
      }
      if ((metadata['gallery'] as Map)['priority'] == null) {
        (metadata['gallery'] as Map)['priority'] =
            GalleryDownloadService.defaultDownloadGalleryPriority;
      }
      if ((metadata['gallery'] as Map)['groupName'] == null) {
        (metadata['gallery'] as Map)['groupName'] = 'default';
      }
      if (metadata['tags'] == null) {
        (metadata['gallery'] as Map)['tags'] = '';
      }
      if (metadata['tagRefreshTime'] == null) {
        (metadata['gallery'] as Map)['tagRefreshTime'] = DateTime.now().toString();
      }

      return {
        'gallery': metadata['gallery'],
        'images': metadata['images'],
      };
    } catch (e, st) {
      log.error('Read gallery metadata failed: ${metadataFile.path}', e, st);
      return null;
    }
  }
}
