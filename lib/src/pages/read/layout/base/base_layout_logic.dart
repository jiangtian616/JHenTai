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
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
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
import '../../../../model/read_page_info.dart';
import '../../../../service/log.dart';
import '../../../../setting/read_setting.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/screen_size_util.dart';
import '../../read_page_logic.dart';
import '../../read_page_state.dart';

abstract class BaseLayoutLogic extends GetxController with GetTickerProviderStateMixin {
  static const String pageId = 'pageId';

  final ReadPageLogic readPageLogic = Get.find<ReadPageLogic>();
  final ReadPageState readPageState = Get.find<ReadPageLogic>().state;

  Timer? autoModeTimer;
  Worker? doubleTapGestureSwitcherListener;
  Worker? tapDragGestureSwitcherListener;
  Worker? showScrollBarListener;

  @override
  void onInit() {
    doubleTapGestureSwitcherListener = ever(readSetting.enableDoubleTapToScaleUp, (value) => updateSafely([pageId]));
    tapDragGestureSwitcherListener = ever(readSetting.enableTapDragToScaleUp, (value) => updateSafely([pageId]));
    showScrollBarListener = ever(readSetting.showScrollBar, (value) => updateSafely([pageId]));
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
    if (value.scrollDelta.dy > 0) {
      toNext();
    } else if (value.scrollDelta.dy < 0) {
      toPrev();
    }
  }

  /// Unified entry point for online image context menus.
  /// Dispatches to [showOnlineDesktopContextMenu] on desktop or [showOnlineMobileBottomMenu] on mobile.
  void showOnlineImageContextMenu(int index, BuildContext context, {Offset? position}) {
    if (styleSetting.isInDesktopLayout && position != null) {
      showOnlineDesktopContextMenu(index: index, context: context, position: position);
    } else {
      showOnlineMobileBottomMenu(index, context);
    }
  }

  /// Mobile bottom action sheet for online images.
  void showOnlineMobileBottomMenu(int index, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('reload'.tr),
            onPressed: () {
              backRoute();
              readPageLogic.reloadImage(index);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('share'.tr),
            onPressed: () async {
              backRoute();
              shareOnlineImage(index);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('copyEHPageUrl'.tr),
            onPressed: () async {
              backRoute();
              copyEHPageUrl(index);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('${'save'.tr}(${'resampleImage'.tr})'),
            onPressed: () async {
              backRoute();
              saveOnlineImage(index);
            },
          ),
          if (readPageState.images[index]!.originalImageUrl != null && userSetting.hasLoggedIn())
            CupertinoActionSheetAction(
              child: Text('${'save'.tr}(${'originalImage'.tr})'),
              onPressed: () async {
                backRoute();
                saveOriginalOnlineImage(index);
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(child: Text('cancel'.tr), onPressed: backRoute),
      ),
    );
  }

  /// Desktop right-click context menu for online images.
  Future<void> showOnlineDesktopContextMenu({
    required int index,
    required BuildContext context,
    required Offset position,
  }) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'reload',
          child: Text('reload'.tr),
        ),
        PopupMenuItem(
          value: 'share',
          child: Text('share'.tr),
        ),
        PopupMenuItem(
          value: 'copy_eh_page_url',
          child: Text('copyEHPageUrl'.tr),
        ),
        PopupMenuItem(
          value: 'save',
          child: Text('${'save'.tr}(${'resampleImage'.tr})'),
        ),
        if (readPageState.images[index]!.originalImageUrl != null && userSetting.hasLoggedIn())
          PopupMenuItem(
            value: 'save_original',
            child: Text('${'save'.tr}(${'originalImage'.tr})'),
          ),
      ],
    );

    switch (selected) {
      case 'reload':
        readPageLogic.reloadImage(index);
        break;
      case 'share':
        shareOnlineImage(index);
        break;
      case 'copy_eh_page_url':
        copyEHPageUrl(index);
        break;
      case 'save':
        await saveOnlineImage(index);
        break;
      case 'save_original':
        await saveOriginalOnlineImage(index);
        break;
    }
  }

  String _getDownloadedImageAbsolutePath(int index) {
    return GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(
      readPageState.images[index]!.path!,
    );
  }

  String _getArchiveImageAbsolutePath(int index) {
    return join(pathService.getVisibleDir().path, readPageState.images[index]!.path!);
  }

  /// Unified entry point for local image context menus.
  /// Handles [ReadMode.downloaded] and [ReadMode.archive].
  /// Dispatches to desktop context menus or mobile bottom sheets based on current layout.
  /// [ReadMode.online] images use [showOnlineImageContextMenu] instead.
  void showLocalImageContextMenu(int index, BuildContext context, {Offset? position}) {
    final mode = readPageState.readPageInfo.mode;
    if (mode == ReadMode.online || mode == ReadMode.local) {
      return;
    }

    final showDownloadedMenu = mode == ReadMode.downloaded;

    if (styleSetting.isInDesktopLayout && position != null) {
      if (showDownloadedMenu) {
        showDownloadedDesktopContextMenu(index: index, context: context, position: position);
      } else {
        showArchiveDesktopContextMenu(index: index, context: context, position: position);
      }
    } else {
      if (showDownloadedMenu) {
        showDownloadedMobileBottomMenu(index, context);
      } else {
        showArchiveMobileBottomMenu(index, context);
      }
    }
  }

  /// Mobile bottom action sheet for downloaded-mode images.
  void showDownloadedMobileBottomMenu(int index, BuildContext context) {
    if (galleryDownloadService.galleryDownloadInfos[readPageState.readPageInfo.gid]?.images[index]?.downloadStatus != DownloadStatus.downloaded) {
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text('share'.tr),
            onPressed: () {
              backRoute();
              shareDownloadedImageFile(index);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('copyEHPageUrl'.tr),
            onPressed: () async {
              backRoute();
              copyEHPageUrl(index);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('save'.tr),
            onPressed: () {
              backRoute();
              saveDownloadedImageFile(index);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('reDownload'.tr),
            onPressed: () {
              backRoute();
              galleryDownloadService.reDownloadImage(readPageState.readPageInfo.gid!, index);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(child: Text('cancel'.tr), onPressed: backRoute),
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
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text('share'.tr),
            onPressed: () {
              backRoute();
              shareArchiveImageFile(index);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('save'.tr),
            onPressed: () {
              backRoute();
              saveArchiveImageFile(index);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(child: Text('cancel'.tr), onPressed: backRoute),
      ),
    );
  }

  /// Desktop right-click context menu for downloaded-mode images.
  Future<void> showDownloadedDesktopContextMenu({
    required int index,
    required BuildContext context,
    required Offset position,
  }) async {
    if (galleryDownloadService.galleryDownloadInfos[readPageState.readPageInfo.gid]?.images[index]?.downloadStatus != DownloadStatus.downloaded) {
      return;
    }

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(value: 'share', child: Text('share'.tr)),
        PopupMenuItem(value: 'copy_eh_page_url', child: Text('copyEHPageUrl'.tr)),
        PopupMenuItem(value: 'save', child: Text('save'.tr)),
        PopupMenuItem(value: 'redownload', child: Text('reDownload'.tr)),
      ],
    );

    switch (selected) {
      case 'share':
        shareDownloadedImageFile(index);
        break;
      case 'copy_eh_page_url':
        copyEHPageUrl(index);
        break;
      case 'save':
        saveDownloadedImageFile(index);
        break;
      case 'redownload':
        galleryDownloadService.reDownloadImage(readPageState.readPageInfo.gid!, index);
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
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(value: 'share', child: Text('share'.tr)),
        PopupMenuItem(value: 'save', child: Text('save'.tr)),
      ],
    );

    switch (selected) {
      case 'share':
        shareArchiveImageFile(index);
        break;
      case 'save':
        saveArchiveImageFile(index);
        break;
    }
  }

  void shareOnlineImage(int index) async {
    if (readPageState.images[index] == null) {
      return;
    }

    Uint8List? data = await getNetworkImageData(readPageState.images[index]!.url);
    if (data == null) {
      return;
    }

    // deal with .webp/.jpg which has not basename
    String ext = extension(readPageState.images[index]!.url);
    if (isEmptyOrNull(ext)) {
      ext = basename(readPageState.images[index]!.url);
    }

    String fileName = '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_$index$ext';

    if (GetPlatform.isDesktop) {
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
      return;
    }

    Share.shareXFiles(
      [XFile.fromData(data)],
      sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, readPageState.displayRegionSize.height * 2 / 3),
      fileNameOverrides: [fileName],
    );
  }

  /// Share a downloaded-mode image file. On desktop, copies file path to clipboard; on mobile, invokes share sheet.
  void shareDownloadedImageFile(int index) {
    if (GetPlatform.isDesktop) {
      Pasteboard.writeFiles([_getDownloadedImageAbsolutePath(index)]).then((_) => toast('hasCopiedToClipboard'.tr));
      return;
    }

    Share.shareXFiles(
      [XFile(_getDownloadedImageAbsolutePath(index))],
      sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, readPageState.displayRegionSize.height * 2 / 3),
    );
  }

  /// Share an archive-mode image file. On desktop, copies file path to clipboard; on mobile, invokes share sheet.
  void shareArchiveImageFile(int index) {
    if (GetPlatform.isDesktop) {
      Pasteboard.writeFiles([_getArchiveImageAbsolutePath(index)]).then((_) => toast('hasCopiedToClipboard'.tr));
      return;
    }

    Share.shareXFiles(
      [XFile(_getArchiveImageAbsolutePath(index))],
      sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, readPageState.displayRegionSize.height * 2 / 3),
    );
  }

  Future<void> saveOnlineImage(int index) async {
    if (readPageState.images[index] == null) {
      return;
    }

    Uint8List? data = await getNetworkImageData(readPageState.images[index]!.url);
    if (data == null) {
      return;
    }

    // deal with .webp/.jpg which has not basename
    String ext = extension(readPageState.images[index]!.url);
    if (isEmptyOrNull(ext)) {
      ext = basename(readPageState.images[index]!.url);
    }

    String fileName = '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_$index$ext';

    if (GetPlatform.isDesktop) {
      File file = File(join(downloadSetting.singleImageSavePath.value, fileName));
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

    if (readPageState.images[index]!.originalImageUrl == null || !userSetting.hasLoggedIn()) {
      return saveOnlineImage(index);
    }

    // deal with .webp/.jpg which has not basename
    String ext = extension(readPageState.images[index]!.originalImageUrl!);
    if (isEmptyOrNull(ext)) {
      ext = basename(readPageState.images[index]!.originalImageUrl!);
    }

    String fileName = '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_${index}_original$ext';
    String downloadPath = join(downloadSetting.tempDownloadPath.value, fileName);
    File file = File(downloadPath);

    toast('downloading'.tr);
    Response response = await ehRequest.download(url: readPageState.images[index]!.originalImageUrl!, path: downloadPath);

    /// what we downloaded is not an image
    if (!response.isRedirect && (response.headers[Headers.contentTypeHeader]?.contains("text/html; charset=UTF-8") ?? false)) {
      File file = File(downloadPath);
      String data = file.readAsStringSync();
      file.delete().ignore();

      EHImageException? exception = GalleryDownloadService.imageData2Exception(data);
      log.error('Save ${readPageState.readPageInfo.galleryTitle} image: $index failed, invalid reason: $exception');

      if (exception != null) {
        if (exception.operation == EHImageExceptionAfterOperation.pause) {
          toast(exception.message, isShort: false);
          return;
        } else if (exception.operation == EHImageExceptionAfterOperation.pauseAll) {
          toast(exception.message, isShort: false);
          return;
        } else if (exception.operation == EHImageExceptionAfterOperation.reParse) {
          GalleryImage image;
          try {
            image = await readPageLogic.requestImage(index, true, null);
          } catch (e) {
            log.error('Save original image failed: $e');
            toast('saveFailed'.tr);
            return;
          }

          readPageState.images[index]!.originalImageUrl = image.originalImageUrl;

          return saveOriginalOnlineImage(index);
        }
      } else {
        toast('saveFailed'.tr, isShort: false);
        return;
      }
    }

    try {
      if (GetPlatform.isDesktop) {
        await file.copy(join(downloadSetting.singleImageSavePath.value, fileName));
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
    if (readPageState.readPageInfo.gid != null && readPageState.readPageInfo.token != null) {
      fileName = '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_$index${extension(image.path)}';
    }

    if (GetPlatform.isDesktop) {
      image.copy(join(downloadSetting.singleImageSavePath.value, fileName)).then((_) => toast('success'.tr));
    } else {
      _saveFile2Album(filePath, fileName).then((_) => toast('success'.tr));
    }
  }

  /// Save an archive-mode image file to the gallery/album or designated save path.
  void saveArchiveImageFile(int index) {
    String filePath = _getArchiveImageAbsolutePath(index);
    File image = File(filePath);

    String fileName = basename(image.path);
    if (readPageState.readPageInfo.gid != null && readPageState.readPageInfo.token != null) {
      fileName = '${readPageState.readPageInfo.gid!}_${readPageState.readPageInfo.token!}_$index${extension(image.path)}';
    }

    if (GetPlatform.isDesktop) {
      image.copy(join(downloadSetting.singleImageSavePath.value, fileName)).then((_) => toast('success'.tr));
    } else {
      _saveFile2Album(filePath, fileName).then((_) => toast('success'.tr));
    }
  }

  void copyEHPageUrl(int index) {
    String? pageUrl;

    if (readPageState.thumbnails[index] != null) {
      pageUrl = readPageState.thumbnails[index]!.replacedMPVHref(index + 1);
    }

    if (pageUrl == null && readPageState.images[index]?.imageHash != null && readPageState.readPageInfo.gid != null) {
      bool isEX = readPageState.readPageInfo.galleryUrl?.contains(EHConsts.EXIndex) == true;
      pageUrl = (isEX ? EHConsts.EXIndex : EHConsts.EHIndex) + '/s/${readPageState.images[index]!.imageHash}/${readPageState.readPageInfo.gid}-${index + 1}';
    }

    if (pageUrl == null) {
      toast('failed'.tr);
      return;
    }

    FlutterClipboard.copy(pageUrl).then((_) => toast('hasCopiedToClipboard'.tr));
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
    return Alignment((offset.dx - Get.size.width / 2) / (Get.size.width / 2), (offset.dy - Get.size.height / 2) / (Get.size.height / 2));
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
