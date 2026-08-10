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
  /// Galleries currently retained by this controller. Tracked so [onClose]
  /// can release each exactly once, and so re-retaining the same gallery
  /// (e.g. on re-init) is a no-op rather than double-counting.
  final Set<int> _retainedGalleryGids = <int>{};

  /// Retain the gallery's [images] list. Idempotent per gid — calling twice
  /// with the same gid retains once. Triggers a lazy reload if the list was
  /// evicted; the returned future completes when the list is resident (or
  /// immediately if it already is).
  ///
  /// The owner label passed to [GalleryDownloadInfo.retainImages] is this
  /// controller's [runtimeType], so evict-block logs name the concrete
  /// consumer (e.g. `ReadPageLogic`, `SuperResolutionService`).
  ///
  /// Returns false if the gallery is not in the download service (never
  /// downloaded / deleted) — caller should handle by skipping sync reads.
  Future<bool> retainGalleryImages(int gid) async {
    if (!_retainedGalleryGids.add(gid)) {
      return true;  // already retained
    }
    final GalleryDownloadInfo? info = galleryDownloadService.galleryDownloadInfos[gid];
    if (info == null) {
      _retainedGalleryGids.remove(gid);
      return false;
    }
    await info.ensureImagesLoaded();
    info.retainImages(owner: runtimeType.toString());
    return true;
  }

  /// Release a single gallery's retain held by this controller. Use this for
  /// long-running operations that want to release mid-lifetime (e.g. a
  /// singleton service processing one gallery at a time). Per-page controllers
  /// usually rely on [onClose] instead.
  void releaseGalleryImages(int gid) {
    if (!_retainedGalleryGids.remove(gid)) {
      return;
    }
    final GalleryDownloadInfo? info = galleryDownloadService.galleryDownloadInfos[gid];
    info?.releaseImages(owner: runtimeType.toString());
  }

  /// Release all retains held by this controller. Called automatically from
  /// [onClose]; subclasses overriding [onClose] must call `super.onClose()`.
  void _releaseAllRetains() {
    final String owner = runtimeType.toString();
    for (final int gid in _retainedGalleryGids) {
      final GalleryDownloadInfo? info = galleryDownloadService.galleryDownloadInfos[gid];
      info?.releaseImages(owner: owner);
    }
    _retainedGalleryGids.clear();
  }

  @override
  void onClose() {
    _releaseAllRetains();
    super.onClose();
  }
}
