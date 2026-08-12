import 'dart:async';
import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/widget/eh_action_sheet_text.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/service/image_inpainting_service.dart';
import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/image_cache_util.dart';
import 'package:jhentai/src/utils/permission_util.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart';
import 'package:photo_view/photo_view.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../exception/eh_image_exception.dart';
import '../../../../model/gallery_image.dart';
import '../../../../model/image_translation.dart';
import '../../../../model/read_page_info.dart';
import '../../../../service/log.dart';
import '../../../../setting/read_setting.dart';
import '../../../../utils/screen_size_util.dart';
import '../../read_page_logic.dart';
import '../../read_page_state.dart';

abstract class BaseLayoutLogic extends GetxController
    with GetTickerProviderStateMixin {
  static const String pageId = 'pageId';

  final ReadPageLogic readPageLogic = Get.find<ReadPageLogic>();
  final ReadPageState readPageState = Get.find<ReadPageLogic>().state;

  Timer? autoModeTimer;
  Worker? doubleTapGestureSwitcherListener;
  Worker? tapDragGestureSwitcherListener;
  Worker? showScrollBarListener;

  @override
  void onInit() {
    doubleTapGestureSwitcherListener = ever(
      readSetting.enableDoubleTapToScaleUp,
      (value) => updateSafely([pageId]),
    );
    tapDragGestureSwitcherListener = ever(
      readSetting.enableTapDragToScaleUp,
      (value) => updateSafely([pageId]),
    );
    showScrollBarListener = ever(
      readSetting.showScrollBar,
      (value) => updateSafely([pageId]),
    );
    super.onInit();
  }

  @override
  void onClose() {
    autoModeTimer?.cancel();
    doubleTapGestureSwitcherListener?.dispose();
    tapDragGestureSwitcherListener?.dispose();
    showScrollBarListener?.dispose();
    super.onClose();
  }

  /// Tap left region or click right arrow key. If read direction is right-to-left, we should call [toNext], otherwise [toPrev]
  void toLeft();

  /// Tap right region or click right arrow key. If read direction is right-to-left, we should call [toPrev], otherwise [toNext]
  void toRight();

  /// to prev image or screen
  void toPrev();

  /// to next image or screen
  void toNext();

  void toImageIndex(int imageIndex) {
    if (readSetting.enablePageTurnAnime.isFalse) {
      jump2ImageIndex(imageIndex);
    } else {
      scroll2ImageIndex(imageIndex);
    }
  }

  @mustCallSuper
  void scroll2ImageIndex(int imageIndex, [Duration? duration]) {
    readPageLogic.update([readPageLogic.sliderId]);
  }

  @mustCallSuper
  void jump2ImageIndex(int imageIndex) {
    readPageLogic.syncThumbnails(imageIndex);
    readPageLogic.update([readPageLogic.sliderId]);
  }

  PhotoViewScaleState scaleStateCycle(PhotoViewScaleState actual) {
    switch (actual) {
      case PhotoViewScaleState.initial:
        return PhotoViewScaleState.zoomedIn;
      default:
        return PhotoViewScaleState.initial;
    }
  }

  void toggleDisplayFirstPageAlone() {}

  void enterAutoMode();

  @mustCallSuper
  void closeAutoMode() {
    autoModeTimer?.cancel();
  }

  void onPointerScroll(PointerScrollEvent value) {
    final ctrlPressed = HardwareKeyboard.instance.logicalKeysPressed.any(
      (key) =>
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight,
    );
    if (ctrlPressed) {
      return;
    }

    if (value.scrollDelta.dy > 0) {
      toNext();
    } else if (value.scrollDelta.dy < 0) {
      toPrev();
    }
  }

  /// Unified entry point for online image context menus.
  /// Dispatches to [showOnlineDesktopContextMenu] on desktop or [showOnlineMobileBottomMenu] on mobile.
  void showOnlineImageContextMenu(
    int index,
    BuildContext context, {
    Offset? position,
  }) {
    if (styleSetting.isInDesktopLayout && position != null) {
      showOnlineDesktopContextMenu(
        index: index,
        context: context,
        position: position,
      );
    } else {
      showOnlineMobileBottomMenu(index, context);
    }
  }

  String _bookmarkActionLabel(int index) =>
      readPageLogic.isPageBookmarked(index)
          ? 'removeBookmark'.tr
          : 'addBookmark'.tr;

  Future<void> _toggleBookmark(int index) =>
      readPageLogic.togglePageBookmark(index);

  void _dismissMobileContextMenu(BuildContext sheetContext) {
    Navigator.of(sheetContext, rootNavigator: true).pop();
  }

  /// Desktop right-click context menu for online images.
  Future<void> showOnlineDesktopContextMenu({
    required int index,
    required BuildContext context,
    required Offset position,
  }) async {
    final selected = await showMenu<String>(
      context: context,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(value: 'reload', child: Text('reload'.tr)),
        PopupMenuItem(value: 'copyImage', child: Text('copyImage'.tr)),
        PopupMenuItem(
          value: 'copy_eh_page_url',
          child: Text('copyEHPageUrl'.tr),
        ),
        PopupMenuItem(
          value: 'translate_image',
          child: Text('translateImageText'.tr),
        ),
        PopupMenuItem(
          value: 'current_page_super_resolution',
          child: Text('currentPageSuperResolution'.tr),
        ),
        PopupMenuItem(
          value: 'toggle_bookmark',
          child: Text(_bookmarkActionLabel(index)),
        ),
        PopupMenuItem(
          value: 'save',
          child: Text('${'save'.tr}(${'resampleImage'.tr})'),
        ),
        if (readPageState.images[index]!.originalImageUrl != null &&
            userSetting.hasLoggedIn())
          PopupMenuItem(
            value: 'save_original',
            child: Text('${'save'.tr}(${'originalImage'.tr})'),
          ),
        PopupMenuItem(value: 'open_read_setting', child: Text('setting'.tr)),
      ],
    );

    switch (selected) {
      case 'reload':
        readPageLogic.reloadImage(index);
        break;
      case 'copyImage':
        copyOnlineImage(index);
        break;
      case 'copy_eh_page_url':
        copyEHPageUrl(index);
        break;
      case 'translate_image':
        translateImage(index, context);
        break;
      case 'current_page_super_resolution':
        readPageLogic.superResolveCurrentImage(index);
        break;
      case 'toggle_bookmark':
        await _toggleBookmark(index);
        break;
      case 'save':
        await saveOnlineImage(index);
        break;
      case 'save_original':
        await saveOriginalOnlineImage(index);
        break;
      case 'open_read_setting':
        readPageLogic.openReadSetting(context);
        break;
    }
  }

  /// Mobile bottom action sheet for online images.
  void showOnlineMobileBottomMenu(int index, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder:
          (sheetContext) => CupertinoActionSheet(
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                child: ehActionSheetText('reload'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  readPageLogic.reloadImage(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('share'.tr),
                onPressed: () async {
                  _dismissMobileContextMenu(sheetContext);
                  shareOnlineImage(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('copyImage'.tr),
                onPressed: () async {
                  _dismissMobileContextMenu(sheetContext);
                  copyOnlineImage(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('copyEHPageUrl'.tr),
                onPressed: () async {
                  _dismissMobileContextMenu(sheetContext);
                  copyEHPageUrl(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('translateImageText'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  translateImage(index, context);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('currentPageSuperResolution'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  readPageLogic.superResolveCurrentImage(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText(_bookmarkActionLabel(index)),
                onPressed: () async {
                  _dismissMobileContextMenu(sheetContext);
                  await _toggleBookmark(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('${'save'.tr}(${'resampleImage'.tr})'),
                onPressed: () async {
                  _dismissMobileContextMenu(sheetContext);
                  saveOnlineImage(index);
                },
              ),
              if (readPageState.images[index]!.originalImageUrl != null &&
                  userSetting.hasLoggedIn())
                CupertinoActionSheetAction(
                  child: ehActionSheetText(
                    '${'save'.tr}(${'originalImage'.tr})',
                  ),
                  onPressed: () async {
                    _dismissMobileContextMenu(sheetContext);
                    saveOriginalOnlineImage(index);
                  },
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              child: ehActionSheetText('cancel'.tr),
              onPressed: () => _dismissMobileContextMenu(sheetContext),
            ),
          ),
    );
  }

  String _getDownloadedImageAbsolutePath(int index) {
    return GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(
      readPageState.images[index]!.path!,
    );
  }

  String _getArchiveImageAbsolutePath(int index) {
    return join(
      pathService.getVisibleDir().path,
      readPageState.images[index]!.path!,
    );
  }

  /// OCR stage of a page's translation: builds the request, fetches the image
  /// (online mode) and runs recognition. Returns the recognized source for
  /// [translateRecognizedImage], or null when the page should be skipped
  /// (image unavailable / no text / already translated).
  Future<RecognizedImage?> recognizeImage(
    int index,
    BuildContext context, {
    bool force = false,
  }) async {
    final GalleryImage? image = readPageState.images[index];
    if (image == null) {
      return null;
    }

    final ReadMode mode = readPageState.readPageInfo.mode;
    final ImageTranslationRequest? request = await _buildTranslationRequest(
      index,
      image,
      mode,
    );
    if (request == null) {
      return null;
    }

    readPageState.imageTranslationRequests[index] = request;
    imageTranslationService.queue(request.cacheKey);
    updateSafely([BaseLayoutLogic.pageId]);
    return imageTranslationService.recognizeImage(request, force: force);
  }

  /// Translation stage of a page's translation: translates the recognized
  /// source text and refreshes the overlay.
  Future<void> translateRecognizedImage(
    int index,
    BuildContext context,
    RecognizedImage recognized,
  ) async {
    final ImageTranslationRequest? request =
        readPageState.imageTranslationRequests[index];
    if (request == null) {
      return;
    }
    await imageTranslationService.translateRecognizedText(request, recognized);
    updateSafely([BaseLayoutLogic.pageId]);
  }

  /// Produces an optional repaired-background derivative after translation.
  /// It runs after OCR/translation so large native inference sessions do not
  /// overlap on memory-constrained mobile devices.
  Future<void> repairTranslatedImage(int index, {bool force = false}) async {
    final ImageProcessingDisplayMode mode =
        imageTranslationSetting.imageProcessingDisplayMode.value;
    if (mode == ImageProcessingDisplayMode.overlay) return;
    final ImageTranslationRequest? request =
        readPageState.imageTranslationRequests[index];
    final String? sourcePath = request?.imagePath;
    if (request == null || sourcePath == null) return;
    if (imageTranslationService.resultFor(request.cacheKey).status !=
        ImageTranslationStatus.success) {
      return;
    }
    imageInpaintingService.setDisplayMode(mode);
    await imageInpaintingService.detectAndRepair(
      requestKey: request.cacheKey,
      sourcePath: sourcePath,
      force: force,
    );
    updateSafely([BaseLayoutLogic.pageId]);
  }

  /// Hydrates a persistent result when a page enters the viewport. This only
  /// reads an already cached source file; it never downloads an image and
  /// never removes the persistent translation result.
  Future<void> hydrateTranslation(int index) async {
    final GalleryImage? image = readPageState.images[index];
    if (image == null) return;
    final ImageTranslationRequest? request = await _buildTranslationRequest(
      index,
      image,
      readPageState.readPageInfo.mode,
      fetchOnline: false,
      reportDownloadErrors: false,
    );
    if (request == null || request.imagePath == null) return;
    final ImageTranslationRequest? previous =
        readPageState.imageTranslationRequests[index];
    if (previous != null && previous.cacheKey != request.cacheKey) {
      imageTranslationService.removeResult(previous.cacheKey);
    }
    readPageState.imageTranslationRequests[index] = request;
    await imageTranslationService.hydrateResult(request);
    updateSafely([BaseLayoutLogic.pageId]);
  }

  /// Builds a lightweight translation request. Online requests retain only the
  /// stable disk path and logical URL; page-sized bytes are scoped to the
  /// download helper and are not stored in read-page state.
  Future<ImageTranslationRequest?> _buildTranslationRequest(
    int index,
    GalleryImage image,
    ReadMode mode, {
    bool fetchOnline = true,
    bool reportDownloadErrors = true,
  }) async {
    if (mode == ReadMode.online) {
      final String url = effectiveEHImageUrl(image.url);
      final String cacheKey = normalizedImageCacheKey(url);
      final String taskKey = 'online:$cacheKey';
      final ImageTranslationRequest descriptor = ImageTranslationRequest(
        cacheKey: taskKey,
        sourceUrl: url,
      );
      try {
        if (fetchOnline) {
          imageTranslationService.markDownloading(taskKey);
        }
        final File? file = await _ensureImageFileForTranslation(
          url,
          cacheKey,
          fetchOnline: fetchOnline,
        ).timeout(const Duration(seconds: 5));
        if (file != null && await file.exists()) {
          return descriptor.copyWith(imagePath: file.path);
        }
      } catch (e, stack) {
        log.warning('Failed to load image bytes for translation: $e');
        log.trace(stack);
      }
      if (fetchOnline && reportDownloadErrors) {
        imageTranslationService.markDownloadError(
          taskKey,
          'IMAGE_DOWNLOAD_TIMEOUT',
        );
        if (!imageTranslationService.isBatchTranslating) {
          toast('imageTranslationSourceUnavailable'.tr);
        }
      }
      return descriptor;
    }
    if (mode == ReadMode.downloaded && image.path != null) {
      return ImageTranslationRequest(
        cacheKey: 'downloaded:${image.path}',
        imagePath: _getDownloadedImageAbsolutePath(index),
      );
    }
    if (mode == ReadMode.archive && image.path != null) {
      return ImageTranslationRequest(
        cacheKey: 'archive:${image.path}',
        imagePath: _getArchiveImageAbsolutePath(index),
      );
    }
    toast('imageTranslationSourceUnavailable'.tr);
    return null;
  }

  /// Finds or downloads the reader's disk-cache file. The returned request
  /// stores only [File.path]; the temporary network buffer is released before
  /// this future completes.
  Future<File?> _ensureImageFileForTranslation(
    String url,
    String cacheKey, {
    required bool fetchOnline,
  }) async {
    final String directoryPath = await getExtendedImageDiskCacheDirectory();
    final File? compatible = await findCompatibleImageCacheFile(
      directory: directoryPath,
      url: url,
    );
    if (compatible != null && await compatible.exists()) {
      return compatible;
    }
    final File cacheFile = File(join(directoryPath, cacheKey));
    if (!fetchOnline) return null;

    final ExtendedNetworkImageProvider provider = ExtendedNetworkImageProvider(
      url,
      cache: true,
      cacheKey: cacheKey,
      retries: 1,
      printError: false,
    );
    Uint8List? bytes = await provider.getNetworkImageData();
    try {
      if (bytes == null) return null;
      // The vendored provider normally writes this file when cache:true. Keep
      // the fallback for older/custom provider behavior so the request always
      // points at the stable key used by the reader.
      if (!await cacheFile.exists()) {
        await Directory(directoryPath).create(recursive: true);
        await cacheFile.writeAsBytes(bytes, flush: true);
      }
      return await cacheFile.exists() ? cacheFile : null;
    } finally {
      bytes = null;
    }
  }

  /// Translates a single page end-to-end (OCR then translation). Batch
  /// translation uses [recognizeImage] + [translateRecognizedImage] so the
  /// pipeline can overlap the next page's OCR with the current translation.
  Future<void> translateImage(
    int index,
    BuildContext context, {
    bool force = false,
  }) async {
    // A single-page translate is a fresh operation: clear the one-shot cancel
    // latch left over from an earlier cancelled translate or from leaving the
    // read page, otherwise every later context-menu translate silently no-ops.
    imageTranslationService.resetCancelFlag();
    // The inline overlay is the only way to see a translation result; quietly
    // translating while it is hidden would look like a dead menu option.
    if (!readPageState.showImageTranslationOverlay) {
      readPageState.showImageTranslationOverlay = true;
      updateSafely([BaseLayoutLogic.pageId]);
      readPageLogic.updateSafely([readPageLogic.translationMenuId]);
    }

    final RecognizedImage? recognized = await recognizeImage(
      index,
      context,
      force: force,
    );
    if (recognized == null) {
      await repairTranslatedImage(index, force: force);
      _hintIfAlreadyTranslated(index, force);
      return;
    }
    await translateRecognizedImage(index, context, recognized);
    await repairTranslatedImage(index, force: force);
  }

  /// When a single-page translate has nothing to do, explain why if the page
  /// already carries a finished translation (previously a silent no-op).
  void _hintIfAlreadyTranslated(int index, bool force) {
    if (force) {
      return;
    }
    final ImageTranslationRequest? request =
        readPageState.imageTranslationRequests[index];
    if (request == null) {
      return;
    }
    if (imageTranslationService.resultFor(request.cacheKey).status ==
        ImageTranslationStatus.success) {
      toast('imageTranslationAlreadyTranslated'.tr);
    }
  }

  /// Unified entry point for local image context menus.
  /// Handles [ReadMode.downloaded] and [ReadMode.archive].
  /// Dispatches to desktop context menus or mobile bottom sheets based on current layout.
  /// [ReadMode.online] images use [showOnlineImageContextMenu] instead.
  void showLocalImageContextMenu(
    int index,
    BuildContext context, {
    Offset? position,
  }) {
    final mode = readPageState.readPageInfo.mode;
    if (mode == ReadMode.online) {
      return;
    }
    if (mode == ReadMode.local) {
      if (styleSetting.isInDesktopLayout && position != null) {
        showLocalDesktopContextMenu(
          index: index,
          context: context,
          position: position,
        );
      } else {
        showLocalMobileBottomMenu(index, context);
      }
      return;
    }

    final showDownloadedMenu = mode == ReadMode.downloaded;

    if (styleSetting.isInDesktopLayout && position != null) {
      if (showDownloadedMenu) {
        showDownloadedDesktopContextMenu(
          index: index,
          context: context,
          position: position,
        );
      } else {
        showArchiveDesktopContextMenu(
          index: index,
          context: context,
          position: position,
        );
      }
    } else {
      if (showDownloadedMenu) {
        showDownloadedMobileBottomMenu(index, context);
      } else {
        showArchiveMobileBottomMenu(index, context);
      }
    }
  }

  void showLocalMobileBottomMenu(int index, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder:
          (sheetContext) => CupertinoActionSheet(
            actions: [
              CupertinoActionSheetAction(
                child: ehActionSheetText(_bookmarkActionLabel(index)),
                onPressed: () async {
                  _dismissMobileContextMenu(sheetContext);
                  await _toggleBookmark(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('currentPageSuperResolution'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  readPageLogic.superResolveCurrentImage(index);
                },
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              child: ehActionSheetText('cancel'.tr),
              onPressed: () => _dismissMobileContextMenu(sheetContext),
            ),
          ),
    );
  }

  Future<void> showLocalDesktopContextMenu({
    required int index,
    required BuildContext context,
    required Offset position,
  }) async {
    final String? selected = await showMenu<String>(
      context: context,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'toggle_bookmark',
          child: Text(_bookmarkActionLabel(index)),
        ),
        PopupMenuItem(
          value: 'current_page_super_resolution',
          child: Text('currentPageSuperResolution'.tr),
        ),
      ],
    );
    switch (selected) {
      case 'toggle_bookmark':
        await _toggleBookmark(index);
        break;
      case 'current_page_super_resolution':
        readPageLogic.superResolveCurrentImage(index);
        break;
    }
  }

  /// Mobile bottom action sheet for downloaded-mode images.
  void showDownloadedMobileBottomMenu(int index, BuildContext context) {
    if (galleryDownloadService
            .galleryDownloadInfos[readPageState.readPageInfo.gid]
            ?.images[index]
            ?.downloadStatus !=
        DownloadStatus.downloaded) {
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder:
          (sheetContext) => CupertinoActionSheet(
            actions: [
              CupertinoActionSheetAction(
                child: ehActionSheetText(_bookmarkActionLabel(index)),
                onPressed: () async {
                  _dismissMobileContextMenu(sheetContext);
                  await _toggleBookmark(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('share'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  shareDownloadedImageFile(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('copyImage'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  copyDownloadedImageFile(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('copyEHPageUrl'.tr),
                onPressed: () async {
                  _dismissMobileContextMenu(sheetContext);
                  copyEHPageUrl(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('translateImageText'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  translateImage(index, context);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('currentPageSuperResolution'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  readPageLogic.superResolveCurrentImage(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('save'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  saveDownloadedImageFile(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('reDownload'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  galleryDownloadService.reDownloadImage(
                    readPageState.readPageInfo.gid!,
                    index,
                  );
                },
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              child: ehActionSheetText('cancel'.tr),
              onPressed: () => _dismissMobileContextMenu(sheetContext),
            ),
          ),
    );
  }

  /// Mobile bottom action sheet for archive-mode images.
  void showArchiveMobileBottomMenu(int index, BuildContext context) {
    if (readPageState.images[index] == null) {
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder:
          (sheetContext) => CupertinoActionSheet(
            actions: [
              CupertinoActionSheetAction(
                child: ehActionSheetText(_bookmarkActionLabel(index)),
                onPressed: () async {
                  _dismissMobileContextMenu(sheetContext);
                  await _toggleBookmark(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('share'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  shareArchiveImageFile(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('copyImage'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  copyArchiveImageFile(index);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('translateImageText'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  translateImage(index, context);
                },
              ),
              CupertinoActionSheetAction(
                child: ehActionSheetText('save'.tr),
                onPressed: () {
                  _dismissMobileContextMenu(sheetContext);
                  saveArchiveImageFile(index);
                },
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              child: ehActionSheetText('cancel'.tr),
              onPressed: () => _dismissMobileContextMenu(sheetContext),
            ),
          ),
    );
  }

  /// Desktop right-click context menu for downloaded-mode images.
  Future<void> showDownloadedDesktopContextMenu({
    required int index,
    required BuildContext context,
    required Offset position,
  }) async {
    if (galleryDownloadService
            .galleryDownloadInfos[readPageState.readPageInfo.gid]
            ?.images[index]
            ?.downloadStatus !=
        DownloadStatus.downloaded) {
      return;
    }

    final selected = await showMenu<String>(
      context: context,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(value: 'copyImage', child: Text('copyImage'.tr)),
        PopupMenuItem(
          value: 'copy_eh_page_url',
          child: Text('copyEHPageUrl'.tr),
        ),
        PopupMenuItem(
          value: 'translate_image',
          child: Text('translateImageText'.tr),
        ),
        PopupMenuItem(
          value: 'current_page_super_resolution',
          child: Text('currentPageSuperResolution'.tr),
        ),
        PopupMenuItem(
          value: 'toggle_bookmark',
          child: Text(_bookmarkActionLabel(index)),
        ),
        PopupMenuItem(value: 'save', child: Text('save'.tr)),
        PopupMenuItem(value: 'redownload', child: Text('reDownload'.tr)),
        PopupMenuItem(value: 'open_read_setting', child: Text('setting'.tr)),
      ],
    );

    switch (selected) {
      case 'copyImage':
        copyDownloadedImageFile(index);
        break;
      case 'copy_eh_page_url':
        copyEHPageUrl(index);
        break;
      case 'translate_image':
        translateImage(index, context);
        break;
      case 'current_page_super_resolution':
        readPageLogic.superResolveCurrentImage(index);
        break;
      case 'toggle_bookmark':
        await _toggleBookmark(index);
        break;
      case 'save':
        saveDownloadedImageFile(index);
        break;
      case 'redownload':
        galleryDownloadService.reDownloadImage(
          readPageState.readPageInfo.gid!,
          index,
        );
        break;
      case 'open_read_setting':
        readPageLogic.openReadSetting(context);
        break;
    }
  }

  /// Desktop right-click context menu for archive-mode images.
  Future<void> showArchiveDesktopContextMenu({
    required int index,
    required BuildContext context,
    required Offset position,
  }) async {
    if (readPageState.images[index] == null) {
      return;
    }

    final selected = await showMenu<String>(
      context: context,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(value: 'copyImage', child: Text('copyImage'.tr)),
        PopupMenuItem(
          value: 'translate_image',
          child: Text('translateImageText'.tr),
        ),
        PopupMenuItem(
          value: 'current_page_super_resolution',
          child: Text('currentPageSuperResolution'.tr),
        ),
        PopupMenuItem(
          value: 'toggle_bookmark',
          child: Text(_bookmarkActionLabel(index)),
        ),
        PopupMenuItem(value: 'save', child: Text('save'.tr)),
        PopupMenuItem(value: 'open_read_setting', child: Text('setting'.tr)),
      ],
    );

    switch (selected) {
      case 'copyImage':
        copyArchiveImageFile(index);
        break;
      case 'translate_image':
        translateImage(index, context);
        break;
      case 'current_page_super_resolution':
        readPageLogic.superResolveCurrentImage(index);
        break;
      case 'toggle_bookmark':
        await _toggleBookmark(index);
        break;
      case 'save':
        saveArchiveImageFile(index);
        break;
      case 'open_read_setting':
        readPageLogic.openReadSetting(context);
        break;
    }
  }

  /// Share an online image via the system share sheet.
  Future<void> shareOnlineImage(int index) async {
    if (readPageState.images[index] == null) {
      return;
    }

    Uint8List? data = await getNetworkImageData(
      readPageState.images[index]!.url,
    );
    if (data == null) {
      return;
    }

    String ext = extension(readPageState.images[index]!.url);
    if (isEmptyOrNull(ext)) {
      ext = basename(readPageState.images[index]!.url);
    }

    String fileName =
        '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_$index$ext';

    Share.shareXFiles(
      [XFile.fromData(data)],
      sharePositionOrigin: Rect.fromLTWH(
        0,
        0,
        fullScreenWidth,
        readPageState.displayRegionSize.height * 2 / 3,
      ),
      fileNameOverrides: [fileName],
    );
  }

  /// Share a downloaded-mode image file via the system share sheet.
  void shareDownloadedImageFile(int index) {
    Share.shareXFiles(
      [XFile(_getDownloadedImageAbsolutePath(index))],
      sharePositionOrigin: Rect.fromLTWH(
        0,
        0,
        fullScreenWidth,
        readPageState.displayRegionSize.height * 2 / 3,
      ),
    );
  }

  /// Share an archive-mode image file via the system share sheet.
  void shareArchiveImageFile(int index) {
    Share.shareXFiles(
      [XFile(_getArchiveImageAbsolutePath(index))],
      sharePositionOrigin: Rect.fromLTWH(
        0,
        0,
        fullScreenWidth,
        readPageState.displayRegionSize.height * 2 / 3,
      ),
    );
  }

  /// Copy an online image to clipboard.
  /// On desktop: writes image to temp file then uses [Pasteboard.writeFiles].
  /// On mobile: uses [Pasteboard.writeImage] with raw bytes.
  Future<void> copyOnlineImage(int index) async {
    if (readPageState.images[index] == null) {
      return;
    }

    Uint8List? data = await getNetworkImageData(
      readPageState.images[index]!.url,
    );
    if (data == null) {
      return;
    }

    if (GetPlatform.isDesktop) {
      String ext = extension(readPageState.images[index]!.url);
      if (isEmptyOrNull(ext)) {
        ext = basename(readPageState.images[index]!.url);
      }
      String fileName =
          '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_$index$ext';
      String filePath = join(downloadSetting.tempDownloadPath.value, fileName);
      File file = File(filePath);
      try {
        await file.create(recursive: true);
        await file.writeAsBytes(data);
        await Pasteboard.writeFiles([file.path]);
        toast('hasCopiedToClipboard'.tr);
      } catch (e) {
        log.error('Copy online image to clipboard failed: $e');
        toast('failed'.tr);
        file.delete().ignore();
      }
    } else {
      await Pasteboard.writeImage(data);
      toast('hasCopiedToClipboard'.tr);
    }
  }

  /// Copy a downloaded-mode image file to clipboard.
  void copyDownloadedImageFile(int index) {
    if (GetPlatform.isDesktop) {
      Pasteboard.writeFiles([
        _getDownloadedImageAbsolutePath(index),
      ]).then((_) => toast('hasCopiedToClipboard'.tr));
    } else {
      Pasteboard.writeImage(
        File(_getDownloadedImageAbsolutePath(index)).readAsBytesSync(),
      ).then((_) => toast('hasCopiedToClipboard'.tr));
    }
  }

  /// Copy an archive-mode image file to clipboard.
  void copyArchiveImageFile(int index) {
    if (GetPlatform.isDesktop) {
      Pasteboard.writeFiles([
        _getArchiveImageAbsolutePath(index),
      ]).then((_) => toast('hasCopiedToClipboard'.tr));
    } else {
      Pasteboard.writeImage(
        File(_getArchiveImageAbsolutePath(index)).readAsBytesSync(),
      ).then((_) => toast('hasCopiedToClipboard'.tr));
    }
  }

  Future<void> saveOnlineImage(int index) async {
    if (readPageState.images[index] == null) {
      return;
    }

    Uint8List? data = await getNetworkImageData(
      readPageState.images[index]!.url,
    );
    if (data == null) {
      return;
    }

    // deal with .webp/.jpg which has not basename
    String ext = extension(readPageState.images[index]!.url);
    if (isEmptyOrNull(ext)) {
      ext = basename(readPageState.images[index]!.url);
    }

    String fileName =
        '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_$index$ext';

    if (GetPlatform.isDesktop) {
      File file = File(
        join(downloadSetting.singleImageSavePath.value, fileName),
      );
      try {
        await file.create(recursive: true);
        await file.writeAsBytes(data);
        toast('saveSuccess'.tr);
      } catch (e) {
        log.error('Save online image failed: $e');
        toast('saveFailed'.tr);
        file.delete().ignore();
        return;
      }
    } else {
      File file = File(join(downloadSetting.tempDownloadPath.value, fileName));
      try {
        await file.create(recursive: true);
        await file.writeAsBytes(data);
        bool success = await _saveFile2Album(file.path, fileName);
        toast(success ? 'saveSuccess'.tr : 'saveFailed'.tr);
      } catch (e) {
        log.error('Save online image failed: $e');
        toast('saveFailed'.tr);
        file.delete().ignore();
        return;
      }
    }
  }

  Future<void> saveOriginalOnlineImage(int index) async {
    if (readPageState.images[index] == null) {
      return;
    }

    if (readPageState.images[index]!.originalImageUrl == null ||
        !userSetting.hasLoggedIn()) {
      return saveOnlineImage(index);
    }

    // deal with .webp/.jpg which has not basename
    String ext = extension(readPageState.images[index]!.originalImageUrl!);
    if (isEmptyOrNull(ext)) {
      ext = basename(readPageState.images[index]!.originalImageUrl!);
    }

    String fileName =
        '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_${index}_original$ext';
    String downloadPath = join(
      downloadSetting.tempDownloadPath.value,
      fileName,
    );
    File file = File(downloadPath);

    toast('downloading'.tr);
    Response response = await ehRequest.download(
      url: readPageState.images[index]!.originalImageUrl!,
      path: downloadPath,
    );

    /// what we downloaded is not an image
    if (!response.isRedirect &&
        (response.headers[Headers.contentTypeHeader]?.contains(
              "text/html; charset=UTF-8",
            ) ??
            false)) {
      File file = File(downloadPath);
      String data = file.readAsStringSync();
      file.delete().ignore();

      EHImageException? exception = GalleryDownloadService.imageData2Exception(
        data,
      );
      log.error(
        'Save ${readPageState.readPageInfo.galleryTitle} image: $index failed, invalid reason: $exception',
      );

      if (exception != null) {
        if (exception.operation == EHImageExceptionAfterOperation.pause) {
          toast(exception.message, isShort: false);
          return;
        } else if (exception.operation ==
            EHImageExceptionAfterOperation.pauseAll) {
          toast(exception.message, isShort: false);
          return;
        } else if (exception.operation ==
            EHImageExceptionAfterOperation.reParse) {
          GalleryImage image;
          try {
            image = await readPageLogic.requestImage(index, true, null);
          } catch (e) {
            log.error('Save original image failed: $e');
            toast('saveFailed'.tr);
            return;
          }

          readPageState.images[index]!.originalImageUrl =
              image.originalImageUrl;

          return saveOriginalOnlineImage(index);
        }
      } else {
        toast('saveFailed'.tr, isShort: false);
        return;
      }
    }

    try {
      if (GetPlatform.isDesktop) {
        await file.copy(
          join(downloadSetting.singleImageSavePath.value, fileName),
        );
        toast('saveSuccess'.tr);
      } else {
        bool success = await _saveFile2Album(downloadPath, fileName);
        toast(success ? 'saveSuccess'.tr : 'saveFailed'.tr);
      }
    } catch (e) {
      log.error('Save original online image failed: $e');
      toast('saveFailed'.tr);
    } finally {
      file.delete().ignore();
    }
  }

  /// Save a downloaded-mode image file to the gallery/album or designated save path.
  void saveDownloadedImageFile(int index) {
    String filePath = _getDownloadedImageAbsolutePath(index);
    File image = File(filePath);

    String fileName = basename(image.path);
    if (readPageState.readPageInfo.gid != null &&
        readPageState.readPageInfo.token != null) {
      fileName =
          '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_$index${extension(image.path)}';
    }

    if (GetPlatform.isDesktop) {
      image
          .copy(join(downloadSetting.singleImageSavePath.value, fileName))
          .then((_) => toast('success'.tr));
    } else {
      _saveFile2Album(filePath, fileName).then((_) => toast('success'.tr));
    }
  }

  /// Save an archive-mode image file to the gallery/album or designated save path.
  void saveArchiveImageFile(int index) {
    String filePath = _getArchiveImageAbsolutePath(index);
    File image = File(filePath);

    String fileName = basename(image.path);
    if (readPageState.readPageInfo.gid != null &&
        readPageState.readPageInfo.token != null) {
      fileName =
          '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_$index${extension(image.path)}';
    }

    if (GetPlatform.isDesktop) {
      image
          .copy(join(downloadSetting.singleImageSavePath.value, fileName))
          .then((_) => toast('success'.tr));
    } else {
      _saveFile2Album(filePath, fileName).then((_) => toast('success'.tr));
    }
  }

  void copyEHPageUrl(int index) {
    String? pageUrl;

    if (readPageState.thumbnails[index] != null) {
      pageUrl = readPageState.thumbnails[index]!.replacedMPVHref(index + 1);
    }

    if (pageUrl == null &&
        readPageState.images[index]?.imageHash != null &&
        readPageState.readPageInfo.gid != null) {
      bool isEX =
          readPageState.readPageInfo.galleryUrl?.contains(EHConsts.EXIndex) ==
          true;
      pageUrl =
          (isEX ? EHConsts.EXIndex : EHConsts.EHIndex) +
          '/s/${readPageState.images[index]!.imageHash}/${readPageState.readPageInfo.gid}-${index + 1}';
    }

    if (pageUrl == null) {
      toast('failed'.tr);
      return;
    }

    FlutterClipboard.copy(
      pageUrl,
    ).then((_) => toast('hasCopiedToClipboard'.tr));
  }

  /// Compute image container size when we haven't parsed image's size
  Size getPlaceHolderSize(int imageIndex) {
    if (readPageState.imageContainerSizes[imageIndex] != null) {
      return readPageState.imageContainerSizes[imageIndex]!;
    }
    return Size(double.infinity, readPageState.displayRegionSize.height / 2);
  }

  /// Compute image container size
  FittedSizes getImageFittedSize(Size imageSize) {
    return applyBoxFit(
      BoxFit.contain,
      Size(imageSize.width, imageSize.height),
      Size(readPageState.displayRegionSize.width, double.infinity),
    );
  }

  Alignment _computeAlignmentByTapOffset(Offset offset) {
    return Alignment(
      (offset.dx - Get.size.width / 2) / (Get.size.width / 2),
      (offset.dy - Get.size.height / 2) / (Get.size.height / 2),
    );
  }

  Future<bool> _saveImage2Album(Uint8List imageData, String fileName) async {
    await requestAlbumPermission();

    SaveResult saveResult = await SaverGallery.saveImage(
      imageData,
      name: fileName,
      androidRelativePath: "Pictures/JHenTai",
      androidExistNotSave: false,
    );

    log.info('Save image to album: $saveResult');

    return saveResult.isSuccess;
  }

  Future<bool> _saveFile2Album(String filePath, String fileName) async {
    await requestAlbumPermission();

    SaveResult saveResult = await SaverGallery.saveFile(
      file: filePath,
      name: fileName,
      androidRelativePath: "Pictures/JHenTai",
      androidExistNotSave: false,
    );

    log.info('Save image to album: $saveResult');

    return saveResult.isSuccess;
  }
}
