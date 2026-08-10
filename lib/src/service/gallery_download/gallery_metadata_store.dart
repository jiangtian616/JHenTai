part of 'gallery_download_service.dart';

/// Owns gallery metadata JSON persistence: throttled writes, immediate flush,
/// and disk reads for restore. The in-memory state lives in
/// [GalleryDownloadService.galleryDownloadInfos]; this class only handles
/// serializing that state to/from `metadata` files on disk.
class _GalleryMetadataStore {
  static const String metadataFileName = 'metadata';

  /// Throttle window. The first [save] after a gallery becomes dirty starts
  /// a periodic timer; subsequent saves within the window just refresh the
  /// dirty flag. The timer fires once per window, writes if dirty, and stops
  /// itself once the gallery goes clean. This guarantees that even under
  /// continuous `save` calls (e.g. an image-status change every 300ms) the
  /// metadata file is written at most once per [_throttleInterval] — never
  /// starved like a pure trailing debounce would be.
  static const Duration _throttleInterval = Duration(milliseconds: 500);

  final GalleryDownloadService _service;

  /// Per-gallery periodic timers. Set on first dirty mark; cancelled once the
  /// gallery goes clean (no writes pending, no new dirty marks since last flush).
  final Map<int, Timer> _metadataSaveTimers = {};

  /// Per-gallery dirty flags. Set by [save], cleared by [_flushPendingWrite].
  /// Only the latest state is read at write time (from
  /// [GalleryDownloadService.galleryDownloadInfos]), so we don't need to
  /// capture the gallery object here.
  final Set<int> _dirty = {};

  /// In-flight writes per gallery. [flush] awaits these before doing its own
  /// write so the on-disk state never goes backwards.
  final Map<int, Future<void>> _metadataWrites = {};

  _GalleryMetadataStore(this._service);

  /// Mark [gallery] dirty and ensure a throttle timer is running. Safe to call
  /// from sync contexts. The actual disk write happens at most once per
  /// [_throttleInterval]; rapid successive calls coalesce.
  void save(GalleryDownloadInfo gallery) {
    final int gid = gallery.gid;
    if (!_service.galleryDownloadInfos.containsKey(gid)) {
      return;
    }
    _dirty.add(gid);
    _metadataSaveTimers.putIfAbsent(gid, () {
      return Timer.periodic(_throttleInterval, (_) => _flushPendingWrite(gid));
    });
  }

  /// Drain the dirty flag for [gid] and write the current in-memory state.
  /// Called by the periodic timer.
  void _flushPendingWrite(int gid) {
    if (!_dirty.remove(gid)) {
      /// No changes since the last write — stop the timer so the gallery
      /// doesn't keep getting polled.
      _metadataSaveTimers.remove(gid)?.cancel();
      return;
    }
    final GalleryDownloadInfo? info = _service.galleryDownloadInfos[gid];
    if (info == null) {
      _metadataSaveTimers.remove(gid)?.cancel();
      return;
    }
    _metadataWrites[gid] = _write(info).whenComplete(() {
      _metadataWrites.remove(gid);
    });
  }

  /// Cancel any pending throttled write and flush the latest state to disk now.
  Future<void> flush(GalleryDownloadInfo gallery) async {
    final int gid = gallery.gid;
    _metadataSaveTimers.remove(gid)?.cancel();
    _dirty.remove(gid);
    await _metadataWrites[gid];
    await _write(gallery);
  }

  /// Cancel any pending writes for a gallery that's being deleted.
  void cancel(int gid) {
    _metadataSaveTimers.remove(gid)?.cancel();
    _dirty.remove(gid);
  }

  Future<void> _write(GalleryDownloadInfo gallery) async {
    final GalleryDownloadInfo info = gallery;

    /// Serialize from [info.images]. If images has been evicted (gallery fully
    /// downloaded and not currently being read), reload from DB so the on-disk
    /// metadata stays complete. This is rare for completed galleries — save
    /// is triggered by image-status or config changes, which don't fire on
    /// evicted galleries except for rare events like group/priority change.
    await info.ensureImagesLoaded();

    final List<GalleryImage?>? images = info.images;
    final List<Map<String, dynamic>?> imagesJson = images?.map((img) => img?.toJson()).toList() ?? <Map<String, dynamic>?>[];

    Map<String, Object> metadata = {
      'gallery': gallery.toGalleryDownloadedData().toJson(),
      'images': jsonEncode(imagesJson),
    };

    try {
      io.File file = io.File(
        path.join(DownloadPathResolver.computeGalleryDownloadAbsolutePath(gallery.toGalleryDownloadedData()), metadataFileName),
      );
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(metadata));
    } catch (e, st) {
      log.error('Save gallery metadata failed, gid: ${gallery.gid}', e, st);
    }
  }

  /// Parsed metadata for a single gallery's restore. The store has applied
  /// all compatibility back-fills (missing fields, sanitizedTitle, recomputed
  /// image paths after download-location change, and the downloaded-status
  /// sanity check).
  ///
  /// Static so it can run in a background isolate via [Isolate.run] — the
  /// method has no instance state, only static deps (path/jsonDecode/
  /// DownloadPathResolver/model fromJson).
  static ({GalleryDownloadedData gallery, List<GalleryImage?> images})? readForRestore(io.Directory galleryDir) {
    final Map<String, dynamic>? raw = read(galleryDir);
    if (raw == null) {
      return null;
    }

    GalleryDownloadedData gallery = GalleryDownloadedData.fromJson(raw['gallery']);

    /// Back-fill sanitizedTitle for metadata files written before this field was introduced.
    if (gallery.sanitizedTitle == null) {
      final int reservedBytes = utf8.encode('${gallery.gid} - ').length;
      gallery = gallery.copyWith(
        sanitizedTitle: Value(DownloadPathResolver.computeSanitizedGalleryTitle(gallery.title, reservedBytes)),
      );
    }

    List<GalleryImage?> images = (jsonDecode(raw['images']) as List).map((_map) => _map == null ? null : GalleryImage.fromJson(_map)).toList();

    /// To deal with changed download location, compute download path again.
    for (int serialNo = 0; serialNo < images.length; serialNo++) {
      if (images[serialNo] == null) {
        continue;
      }
      images[serialNo]!.path = DownloadPathResolver.computeImageDownloadRelativePath(gallery, _downloadUrlFor(gallery, images[serialNo]!), serialNo);
      images[serialNo]!.imageHash ??= '';
    }

    /// For some reason, downloaded status is not updated correctly, check it again
    if (gallery.downloadStatusIndex != DownloadStatus.downloaded.index) {
      int downloadedImageCount = images.fold(0, (total, image) => total + (image?.downloadStatus == DownloadStatus.downloaded ? 1 : 0));
      if (downloadedImageCount == gallery.pageCount) {
        gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.downloaded.index);
      }
    }

    return (gallery: gallery, images: images);
  }

  /// Read + parse the metadata file in [galleryDir]. Returns null if the file
  /// is missing or unparseable. Compatibility back-fills (for fields added in
  /// later versions) are applied to the gallery map before returning.
  ///
  /// Static so it can run in a background isolate (see [readForRestore]).
  static Map<String, dynamic>? read(io.Directory galleryDir) {
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
        (metadata['gallery'] as Map)['priority'] = GalleryDownloadService.defaultDownloadGalleryPriority;
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
