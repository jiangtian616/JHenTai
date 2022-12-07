import 'dart:math';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';

import '../../../../config/ui_config.dart';
import '../../../../service/gallery_download_service.dart';
import '../../../../utils/log.dart';
import '../../../../widget/eh_image.dart';
import '../../../../widget/icon_text_button.dart';
import '../../../../widget/loading_state_indicator.dart';
import '../../read_page_logic.dart';
import '../../read_page_state.dart';
import 'base_layout_logic.dart';
import 'base_layout_state.dart';

abstract class BaseLayout extends StatelessWidget {
  BaseLayout({Key? key}) : super(key: key);

  final ReadPageLogic readPageLogic = Get.find<ReadPageLogic>();
  final ReadPageState readPageState = Get.find<ReadPageLogic>().state;

  final GalleryDownloadService downloadService = Get.find();

  BaseLayoutLogic get logic;

  BaseLayoutState get state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BaseLayoutLogic>(
      id: BaseLayoutLogic.pageId,
      global: false,
      init: logic,
      builder: (_) => buildBody(context),
    );
  }

  Widget buildBody(BuildContext context);

  /// online mode: parsing and loading automatically while scrolling
  Widget buildItemInOnlineMode(BuildContext context, int index) {
    return GetBuilder<ReadPageLogic>(
      id: '${readPageLogic.onlineImageId}::$index',
      builder: (_) {
        /// step 1: parse image href if needed. check if thumbnail's info exists, if not, [parse] one page of thumbnails to get image hrefs.
        if (readPageState.thumbnails[index] == null) {
          if (readPageState.parseImageHrefsStates[index] == LoadingState.idle) {
            readPageLogic.beginToParseImageHref(index);
          }
          return _buildParsingHrefsIndicator(context, index);
        }

        /// step 2: parse image url.
        if (readPageState.images[index] == null) {
          if (readPageState.parseImageUrlStates[index] == LoadingState.idle) {
            readPageLogic.beginToParseImageUrl(index, false);
          }
          return _buildParsingUrlIndicator(context, index);
        }

        /// step 3: use url to load image
        return _buildOnlineImage(context, index);
      },
    );
  }

  /// wait for [readPageLogic] to parse image href in online mode
  Widget _buildParsingHrefsIndicator(BuildContext context, int index) {
    Size placeHolderSize = logic.getPlaceHolderSize();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTap: () => readPageLogic.beginToParseImageHref(index),
      onLongPress: () => readPageLogic.beginToParseImageHref(index),
      child: SizedBox(
        height: placeHolderSize.height,
        width: placeHolderSize.width,
        child: GetBuilder<ReadPageLogic>(
          id: '${readPageLogic.parseImageHrefsStateId}::$index',
          builder: (_) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingStateIndicator(
                loadingState: readPageState.parseImageHrefsStates[index],
                idleWidget: const CircularProgressIndicator(),
                errorWidget: const Icon(Icons.warning, color: Colors.yellow),
              ),
              Text(
                readPageState.parseImageHrefsStates[index] == LoadingState.error ? readPageState.parseImageHrefErrorMsg! : 'parsingPage'.tr,
              ).marginOnly(top: 8),
              Text((index + 1).toString()).marginOnly(top: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// wait for [readPageLogic] to parse image url in online mode
  Widget _buildParsingUrlIndicator(BuildContext context, int index) {
    Size placeHolderSize = logic.getPlaceHolderSize();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTap: () => readPageLogic.beginToParseImageUrl(index, true),
      onLongPress: () => readPageLogic.beginToParseImageUrl(index, true),
      child: SizedBox(
        height: placeHolderSize.height,
        width: placeHolderSize.width,
        child: GetBuilder<ReadPageLogic>(
          id: '${readPageLogic.parseImageUrlStateId}::$index',
          builder: (_) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingStateIndicator(
                loadingState: readPageState.parseImageUrlStates[index],
                idleWidget: const CircularProgressIndicator(),
                errorWidget: const Icon(Icons.warning, color: Colors.yellow),
              ),
              Text(
                readPageState.parseImageUrlStates[index] == LoadingState.error ? readPageState.parseImageUrlErrorMsg[index]! : 'parsingURL'.tr,
              ).marginOnly(top: 8),
              Text((index + 1).toString()).marginOnly(top: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineImage(BuildContext context, int index) {
    return GestureDetector(
      onLongPress: () => logic.showBottomMenuInOnlineMode(index, context),
      onSecondaryTap: () => logic.showBottomMenuInOnlineMode(index, context),
      child: EHImage(
        galleryImage: readPageState.images[index]!,
        containerWidth: logic.readPageState.imageSizes[index]?.width ?? logic.getPlaceHolderSize().width,
        containerHeight: logic.readPageState.imageSizes[index]?.height ?? logic.getPlaceHolderSize().height,
        clearMemoryCacheWhenDispose: true,
        loadingProgressWidgetBuilder: (double progress) => _loadingProgressWidgetBuilder(index, progress),
        failedWidgetBuilder: (ExtendedImageState state) => _failedWidgetBuilder(index, state),
        completedWidgetBuilder: (state) => _completedWidgetBuilder(index, state),
      ),
    );
  }

  /// loading for online mode
  Widget _loadingProgressWidgetBuilder(int index, double progress) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(value: progress),
        Text('loading'.tr).marginOnly(top: 8),
        Text((index + 1).toString()).marginOnly(top: 4),
      ],
    );
  }

  /// failed for online mode
  Widget _failedWidgetBuilder(int index, ExtendedImageState state) {
    Log.warning(state.lastException);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTextButton(
          icon: const Icon(Icons.error),
          text: Text('networkError'.tr),
          onPressed: state.reLoadImage,
          onLongPress: state.reLoadImage,
        ),
        Text((index + 1).toString()),
      ],
    );
  }

  /// completed for online mode
  Widget? _completedWidgetBuilder(int index, ExtendedImageState state) {
    if (state.extendedImageInfo == null || logic.readPageState.imageSizes[index] != null) {
      return null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.extendedImageInfo == null || logic.readPageState.imageSizes[index] != null) {
        return;
      }
      FittedSizes fittedSizes = logic.getImageFittedSize(
        Size(state.extendedImageInfo!.image.width.toDouble(), state.extendedImageInfo!.image.height.toDouble()),
      );
      logic.readPageState.imageSizes[index] = fittedSizes.destination;
      logic.readPageLogic.updateSafely(['${readPageLogic.onlineImageId}::$index']);
    });

    return null;
  }

  /// local mode: wait for download service to parse and download
  Widget buildItemInLocalMode(BuildContext context, int index) {
    return GetBuilder<GalleryDownloadService>(
      id: '${logic.galleryDownloadService.downloadImageId}::${readPageState.readPageInfo.gid}::$index',
      builder: (_) {
        /// step 1: wait for parsing image's href for this image. But if image's url has been parsed,
        /// we don't need to wait parsing thumbnail.
        if (readPageState.thumbnails[index] == null && readPageState.images[index] == null) {
          return _buildWaitParsingHrefsIndicator(context, index);
        }

        /// step 2: wait for parsing image's url.
        if (readPageState.images[index] == null) {
          return _buildWaitParsingUrlIndicator(context, index);
        }

        /// step 3: use url to load image
        return _buildLocalImage(context, index);
      },
    );
  }

  /// wait for [GalleryDownloadService] to parse image href in local mode
  Widget _buildWaitParsingHrefsIndicator(BuildContext context, int index) {
    DownloadStatus downloadStatus = downloadService.galleryDownloadInfos[readPageState.readPageInfo.gid]!.downloadProgress.downloadStatus;
    Size placeHolderSize = logic.getPlaceHolderSize();

    return SizedBox(
      height: placeHolderSize.height,
      width: placeHolderSize.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (downloadStatus == DownloadStatus.downloading) const CircularProgressIndicator(),
          if (downloadStatus == DownloadStatus.paused) const Icon(Icons.pause_circle_outline, color: Colors.white),
          Text(downloadStatus == DownloadStatus.downloading ? 'parsingPage'.tr : 'paused'.tr).marginOnly(top: 8),
          Text((index + 1).toString()).marginOnly(top: 4),
        ],
      ),
    );
  }

  /// wait for [GalleryDownloadService] to parse image url in local mode
  Widget _buildWaitParsingUrlIndicator(BuildContext context, int index) {
    DownloadStatus downloadStatus = downloadService.galleryDownloadInfos[readPageState.readPageInfo.gid]!.downloadProgress.downloadStatus;
    Size placeHolderSize = logic.getPlaceHolderSize();
    return SizedBox(
      height: placeHolderSize.height,
      width: placeHolderSize.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (downloadStatus == DownloadStatus.downloading) const CircularProgressIndicator(),
          if (downloadStatus == DownloadStatus.paused) const Icon(Icons.pause_circle_outline, color: Colors.white),
          Text(downloadStatus == DownloadStatus.downloading ? 'parsingURL'.tr : 'paused'.tr).marginOnly(top: 8),
          Text((index + 1).toString()).marginOnly(top: 4),
        ],
      ),
    );
  }

  Widget _buildLocalImage(BuildContext context, int index) {
    return GestureDetector(
      onLongPress: () => logic.showBottomMenuInLocalMode(index, context),
      onSecondaryTap: () => logic.showBottomMenuInLocalMode(index, context),
      child: EHImage(
        galleryImage: readPageState.images[index]!,
        containerWidth: logic.readPageState.imageSizes[index]?.width ?? logic.getPlaceHolderSize().width,
        containerHeight: logic.readPageState.imageSizes[index]?.height ?? logic.getPlaceHolderSize().height,
        clearMemoryCacheWhenDispose: true,
        downloadingWidgetBuilder: () => _downloadingWidgetBuilder(index),
        pausedWidgetBuilder: () => _pausedWidgetBuilder(index),
        loadingWidgetBuilder: () => _loadingWidgetBuilder(index),
        failedWidgetBuilder: (state) => _failedWidgetBuilderForLocalMode(index, state),
        completedWidgetBuilder: (state) => _completedWidgetBuilderForLocalMode(index, state),
      ),
    );
  }

  /// downloading for local mode
  Widget _downloadingWidgetBuilder(int index) {
    return GetBuilder<GalleryDownloadService>(
      id: '${logic.galleryDownloadService.galleryDownloadSpeedComputerId}::${readPageState.readPageInfo.gid}',
      builder: (_) {
        GalleryDownloadSpeedComputer speedComputer = downloadService.galleryDownloadInfos[readPageState.readPageInfo.gid]!.speedComputer;
        int downloadedBytes = speedComputer.imageDownloadedBytes[index];
        int totalBytes = speedComputer.imageTotalBytes[index];

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: max(downloadedBytes / totalBytes, 0.01)),
            Text('downloading'.tr).marginOnly(top: 8),
            Text((index + 1).toString()),
          ],
        );
      },
    );
  }

  /// paused for local mode
  Widget _pausedWidgetBuilder(int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.pause_circle_outline, color: Colors.white),
        Text('paused'.tr).marginOnly(top: 8),
        Text((index + 1).toString()),
      ],
    );
  }

  /// loading for local mode
  Widget _loadingWidgetBuilder(int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        UIConfig.loadingAnimation,
        Text((index + 1).toString()),
      ],
    );
  }

  /// failed for local mode
  Widget _failedWidgetBuilderForLocalMode(int index, ExtendedImageState state) {
    Log.warning(state.lastException);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTextButton(
          icon: const Icon(Icons.sentiment_very_dissatisfied),
          text: Text('error'.tr),
          onPressed: state.reLoadImage,
          onLongPress: state.reLoadImage,
        ),
        Text((index + 1).toString()),
      ],
    );
  }

  /// completed for local mode
  Widget? _completedWidgetBuilderForLocalMode(int index, ExtendedImageState state) {
    if (state.extendedImageInfo == null || logic.readPageState.imageSizes[index] != null) {
      return null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.extendedImageInfo == null || logic.readPageState.imageSizes[index] != null) {
        return;
      }
      FittedSizes fittedSizes = logic.getImageFittedSize(
        Size(state.extendedImageInfo!.image.width.toDouble(), state.extendedImageInfo!.image.height.toDouble()),
      );
      logic.readPageState.imageSizes[index] = fittedSizes.destination;
      logic.galleryDownloadService.updateSafely(['${logic.galleryDownloadService.downloadImageId}::${readPageState.readPageInfo.gid}::$index']);
    });

    return null;
  }
}
