import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import 'gallery_download_service.dart';

/// Mixin for [GetxController]s that need synchronous access to a gallery's
/// full [GalleryDownloadInfo.images] list (read page, details page,
/// thumbnails page, super-resolution, etc.).
///
/// Calling [retainGalleryImages] increments the gallery's refcount so the
/// list stays resident — even if the download completes mid-consumption,
/// eviction is deferred until this controller's [onClose] releases.
///
/// Usage:
/// ```dart
/// class ReadPageLogic extends GetxController with GalleryImagesRetainer {
///   @override
///   void onInit() {
///     super.onInit();
///     retainGalleryImages(readPageInfo.gid!);  // fire-and-forget
///   }
///   // onClose is handled by the mixin — releases automatically.
/// }
/// ```
///
/// For controllers that need to await the load before first use (e.g. read
/// page, which reads images synchronously in the state ctor), call
/// [retainGalleryImages] in `onInit` and await the returned future:
/// ```dart
///   @override
///   Future<void> onInit() async {
///     super.onInit();
///     await retainGalleryImages(gid);
///     // now images is guaranteed resident
///   }
/// ```
mixin GalleryImagesRetainer on GetxController {
  /// Galleries currently retained by this controller, mapped to how many
  /// times each was retained. [onClose] releases each retain count exactly,
  /// so a controller may retain the same gallery multiple times (e.g. a
  /// singleton service running concurrent consumers over the same gallery)
  /// without leaking or under-releasing.
  final Map<int, int> _retainedGalleryGids = <int, int>{};

  /// Retain the gallery's [images] list. Each call increments this
  /// controller's retain count for [gid] — pair every retain with a
  /// matching [releaseGalleryImages] (or rely on [onClose], which releases
  /// all). Triggers a lazy reload if the list was evicted; the returned
  /// future completes when the list is resident (or immediately if it
  /// already is).
  ///
  /// The owner label passed to [GalleryDownloadInfo.retainImages] is this
  /// controller's [runtimeType], so evict-block logs name the concrete
  /// consumer (e.g. `ReadPageLogic`, `SuperResolutionService`).
  ///
  /// Returns false if the gallery is not in the download service (never
  /// downloaded / deleted) — caller should handle by skipping sync reads.
  Future<bool> retainGalleryImages(int gid) async {
    _retainedGalleryGids[gid] = (_retainedGalleryGids[gid] ?? 0) + 1;
    final GalleryDownloadInfo? info = galleryDownloadService.galleryDownloadInfos[gid];
    if (info == null) {
      /// The gallery is gone — nothing to retain on, and any previously
      /// tracked retains are moot (the info object is being collected).
      _retainedGalleryGids.remove(gid);
      return false;
    }

    /// Retain BEFORE loading so [evictImages] is blocked for the whole load.
    /// Retaining after the await would leave a window where a concurrent
    /// evict (e.g. the gallery's last image finishing download) sees an
    /// empty [_imageResidents], evicts `images`, and [retainImages]'s
    /// fire-and-forget reload wouldn't be awaited — the list could be null
    /// at return. Once retained, eviction can't interrupt the load below.
    info.retainImages(owner: runtimeType.toString());

    /// If [retainImages] fired a reload (list was evicted), await it so the
    /// caller can rely on `images` being resident at return.
    await info.ensureImagesLoaded();
    return true;
  }

  /// Release one retain of [gid] held by this controller. Use this for
  /// long-running operations that want to release mid-lifetime (e.g. a
  /// singleton service processing one gallery at a time). Per-page controllers
  /// usually rely on [onClose] instead.
  void releaseGalleryImages(int gid) {
    final int? count = _retainedGalleryGids[gid];
    if (count == null || count == 0) {
      return;
    }
    if (count == 1) {
      _retainedGalleryGids.remove(gid);
    } else {
      _retainedGalleryGids[gid] = count - 1;
    }
    final GalleryDownloadInfo? info = galleryDownloadService.galleryDownloadInfos[gid];
    info?.releaseImages(owner: runtimeType.toString());
  }

  /// Release all retains held by this controller. Called automatically from
  /// [onClose]; subclasses overriding [onClose] must call `super.onClose()`.
  void _releaseAllRetains() {
    final String owner = runtimeType.toString();
    for (final MapEntry<int, int> entry in _retainedGalleryGids.entries) {
      final GalleryDownloadInfo? info = galleryDownloadService.galleryDownloadInfos[entry.key];
      for (int i = 0; i < entry.value; i++) {
        info?.releaseImages(owner: owner);
      }
    }
    _retainedGalleryGids.clear();
  }

  @override
  void onClose() {
    _releaseAllRetains();
    super.onClose();
  }
}
