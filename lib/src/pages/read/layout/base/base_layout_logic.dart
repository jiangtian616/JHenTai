import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clipboard/clipboard.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:image_save/image_save.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../setting/path_setting.dart';
import '../../../../setting/read_setting.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/screen_size_util.dart';
import '../../read_page_logic.dart';
import '../../read_page_state.dart';

abstract class BaseLayoutLogic extends GetxController with GetTickerProviderStateMixin {
  static const String pageId = 'pageId';

  final ReadPageLogic readPageLogic = Get.find<ReadPageLogic>();
  final ReadPageState readPageState = Get.find<ReadPageLogic>().state;
  final GalleryDownloadService galleryDownloadService = Get.find<GalleryDownloadService>();

  Timer? autoModeTimer;
  Worker? doubleTapGestureSwitcherListener;
  Worker? tapDragGestureSwitcherListener;

  @override
  void onInit() {
    doubleTapGestureSwitcherListener = ever(ReadSetting.enableDoubleTapToScaleUp, (value) => updateSafely([pageId]));
    tapDragGestureSwitcherListener = ever(ReadSetting.enableTapDragToScaleUp, (value) => updateSafely([pageId]));
    super.onInit();
  }

  @override
  void onClose() {
    autoModeTimer?.cancel();
    doubleTapGestureSwitcherListener?.dispose();
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

  void handleM() {}

  void toImageIndex(int imageIndex) {
    if (ReadSetting.enablePageTurnAnime.isFalse) {
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

  void enterAutoMode();

  @mustCallSuper
  void closeAutoMode() {
    autoModeTimer?.cancel();
  }

  void showBottomMenuInOnlineMode(int index, BuildContext context) {
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
            child: Text('${'save'.tr}(${'resampleImage'.tr})'),
            onPressed: () async {
              backRoute();
              saveOnlineImage(index);
            },
          ),
          if (readPageState.images[index]!.originalImageUrl != null && UserSetting.hasLoggedIn())
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

  void showBottomMenuInLocalMode(int index, BuildContext context) {
    if (galleryDownloadService.galleryDownloadInfos[readPageState.readPageInfo.gid]?.images[index]?.downloadStatus != DownloadStatus.downloaded) {
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('share'.tr),
            onPressed: () {
              backRoute();
              shareLocalImage(index);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('save'.tr),
            onPressed: () {
              backRoute();
              saveLocalImage(index);
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

  void shareOnlineImage(int index) async {
    if (readPageState.images[index] == null) {
      return;
    }

    if (GetPlatform.isDesktop) {
      await FlutterClipboard.copy(readPageState.images[index]!.url);
      toast('hasCopiedToClipboard'.tr);
      return;
    }

    Uint8List? data = await getNetworkImageData(readPageState.images[index]!.url);
    if (data == null) {
      return;
    }

    String path = join(PathSetting.tempDir.path, '${DateTime.now().hashCode}${extension(readPageState.images[index]!.url)}');
    File file = File(path);

    file.create().then((file) => file.writeAsBytes(data)).then(
          (_) => Share.shareFiles(
            [path],
            text: '$index${extension(readPageState.images[index]!.url)}',
            sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, screenHeight * 2 / 3),
          ),
        );
  }

  void shareLocalImage(int index) {
    if (GetPlatform.isDesktop) {
      FlutterClipboard.copy(readPageState.images[index]!.url).then((_) => toast('hasCopiedToClipboard'.tr));
      return;
    }

    Share.shareFiles(
      [
        GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(
            galleryDownloadService.galleryDownloadInfos[readPageState.readPageInfo.gid!]!.images[index]!.path!),
      ],
      text: basename(galleryDownloadService.galleryDownloadInfos[readPageState.readPageInfo.gid!]!.images[index]!.path!),
      sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, screenHeight * 2 / 3),
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

    if (GetPlatform.isDesktop) {
      File file = File(join(DownloadSetting.singleImageSavePath.value, basename(readPageState.images[index]!.url)));
      file.create(recursive: true).then((_) => file.writeAsBytesSync(data)).then((_) => toast('success'.tr));
      return;
    }

    _saveImage2Album(data, basename(readPageState.images[index]!.url)).then((_) => toast('success'.tr));
  }

  Future<void> saveOriginalOnlineImage(int index) async {
    if (readPageState.images[index] == null) {
      return;
    }

    if (readPageState.images[index]!.originalImageUrl == null || !UserSetting.hasLoggedIn()) {
      return saveOnlineImage(index);
    }

    String downloadPath = join(DownloadSetting.singleImageSavePath.value, basename(readPageState.images[index]!.url));

    toast('downloading'.tr);
    await EHRequest.download(
      url: readPageState.images[index]!.originalImageUrl!,
      path: downloadPath,
      receiveTimeout: 0,
    );

    if (GetPlatform.isDesktop) {
      toast('success'.tr);
    } else {
      _saveImage2Album(File(downloadPath).readAsBytesSync(), basename(readPageState.images[index]!.url)).then((_) => toast('success'.tr));
    }
  }

  void saveLocalImage(int index) {
    File image = File(
      GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(
        galleryDownloadService.galleryDownloadInfos[readPageState.readPageInfo.gid!]!.images[index]!.path!,
      ),
    );

    if (GetPlatform.isDesktop) {
      image.copy(join(DownloadSetting.singleImageSavePath.value, basename(image.path))).then((_) => toast('success'.tr));
    } else {
      image.readAsBytes().then((bytes) => _saveImage2Album(bytes, basename(image.path))).then((_) => toast('success'.tr));
    }
  }

  /// Compute image container size when we haven't parsed image's size
  Size getPlaceHolderSize(int imageIndex) {
    if (readPageState.imageContainerSizes[imageIndex] != null) {
      return readPageState.imageContainerSizes[imageIndex]!;
    }
    return Size(double.infinity, screenHeight / 2);
  }

  /// Compute image container size
  FittedSizes getImageFittedSize(Size imageSize) {
    return applyBoxFit(
      BoxFit.contain,
      Size(imageSize.width, imageSize.height),
      Size(fullScreenWidth, double.infinity),
    );
  }

  Alignment _computeAlignmentByTapOffset(Offset offset) {
    return Alignment((offset.dx - Get.size.width / 2) / (Get.size.width / 2), (offset.dy - Get.size.height / 2) / (Get.size.height / 2));
  }

  Future<bool> _saveImage2Album(Uint8List imageData, String fileName) async {
    if (readPageState.readPageInfo.gid != null) {
      fileName = '${readPageState.readPageInfo.gid!}_$fileName';
    }

    return await ImageSave.saveImage(imageData, fileName, albumName: EHConsts.appName) == true;
  }
}
