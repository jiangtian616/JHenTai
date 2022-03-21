import 'dart:math';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/icon_text_button.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../service/download_service.dart';

class ReadPage extends StatelessWidget {
  final logic = Get.put(ReadPageLogic());
  final state = Get.find<ReadPageLogic>().state;
  final DownloadService downloadService = Get.find();

  ReadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: FlutterListView(
        controller: state.listViewController,
        delegate: FlutterListViewDelegate(
          (BuildContext context, int index) {
            return Obx(() {
              /// step 1: parsing thumbnail if needed. check thumbnail info whether exists, if not, [parse] one page of thumbnails
              if (state.thumbnails.isEmpty || state.thumbnails[index].value == null) {
                if (state.imageHrefParsingState.value == LoadingState.idle) {
                  logic.beginParsingImageHref(index);
                }
                if (state.type == 'online' || state.images[index].value == null) {
                  return _buildParsingThumbnailsIndicator(context, index);
                }
              }

              /// step 2: parsing image url. [parse] one image's raw data
              if (state.images[index].value == null) {
                if (state.imageUrlParsingStates?[index].value == LoadingState.idle) {
                  logic.beginParsingImageUrl(index);
                }

                /// just like a listener
                downloadService.gid2Images[state.gid]?[index].value;

                return _buildParsingImageIndicator(context, index);
              }

              /// step 3 load image : use url to [load] image
              return EHImage(
                galleryImage: state.images[index].value!,
                adaptive: true,
                fit: BoxFit.contain,
                enableLongPressToRefresh: true,
                loadingWidgetBuilder: (double progress) => _loadingWidgetBuilder(context, index, progress),
                failedWidgetBuilder: (ExtendedImageState state) => _failedWidgetBuilder(context, index, state),
                downloadingWidgetBuilder: () => _downloadingWidgetBuilder(context, index),
              );
            });
          },
          initIndex: state.initialIndex,
          childCount: state.pageCount,
          preferItemHeight: context.height,
          onIsPermanent: (keyOrIndex) => true,
        ),
      ),
    );
  }

  Widget _buildParsingThumbnailsIndicator(BuildContext context, int index) {
    return SizedBox(
      height: context.height / 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingStateIndicator(
            userCupertinoIndicator: false,
            loadingState: state.imageHrefParsingState.value,
            idleWidget: const CircularProgressIndicator(),
            errorTapCallback: () => logic.beginParsingImageHref(index),
          ),
          Text(
            state.imageHrefParsingState.value == LoadingState.error ? 'parsePageFailed'.tr : 'parsingPage'.tr,
            style: _readPageTextStyle(),
          ).marginOnly(top: 8),
          Text(index.toString(), style: _readPageTextStyle()).marginOnly(top: 4),
        ],
      ),
    );
  }

  Widget _buildParsingImageIndicator(BuildContext context, int index) {
    return SizedBox(
      height: context.height / 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.type == 'online')
            LoadingStateIndicator(
              userCupertinoIndicator: false,
              loadingState: state.imageUrlParsingStates![index].value,
              idleWidget: const CircularProgressIndicator(),
              errorTapCallback: () => logic.beginParsingImageUrl(index),
            ),
          if (state.type == 'local') const CircularProgressIndicator(),
          Text(
            state.imageUrlParsingStates?[index].value == LoadingState.error ? 'parseURLFailed'.tr : 'parsingURL'.tr,
            style: _readPageTextStyle(),
          ).marginOnly(top: 8),
          Text(index.toString(), style: _readPageTextStyle()).marginOnly(top: 4),
        ],
      ),
    );
  }

  Widget _loadingWidgetBuilder(BuildContext context, int index, double progress) {
    FittedSizes fittedSizes = applyBoxFit(
      BoxFit.contain,
      Size(state.images[index].value!.width, state.images[index].value!.height),
      Size(context.width, double.infinity),
    );

    return SizedBox(
      height: fittedSizes.destination.height,
      width: fittedSizes.destination.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: progress),
          Text('loading'.tr, style: _readPageTextStyle()).marginOnly(top: 8),
          Text(index.toString(), style: _readPageTextStyle()).marginOnly(top: 4),
        ],
      ),
    );
  }

  Widget _failedWidgetBuilder(BuildContext context, int index, ExtendedImageState state) {
    FittedSizes fittedSizes = applyBoxFit(
      BoxFit.contain,
      Size(this.state.images[index].value!.width, this.state.images[index].value!.height),
      Size(context.width, double.infinity),
    );

    return SizedBox(
      height: fittedSizes.destination.height,
      width: fittedSizes.destination.width,
      child: Column(
        children: [
          IconTextButton(
            iconData: Icons.error,
            text: Text('networkError'.tr, style: _readPageTextStyle()),
            onPressed: state.reLoadImage,
          ),
          Text(index.toString(), style: _readPageTextStyle()),
        ],
      ),
    );
  }

  Widget _downloadingWidgetBuilder(BuildContext context, int index) {
    FittedSizes fittedSizes = applyBoxFit(
      BoxFit.contain,
      Size(state.images[index].value!.width, state.images[index].value!.height),
      Size(context.width, double.infinity),
    );


    return Obx(() {
      SpeedComputer speedComputer = downloadService.gid2SpeedComputer[state.gid]!;
      int downloadedBytes = speedComputer.imageDownloadedBytes[index].value;
      int totalBytes = speedComputer.imageTotalBytes[index].value;

      return SizedBox(
        height: fittedSizes.destination.height,
        width: fittedSizes.destination.width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: max(downloadedBytes / totalBytes, 0.01)),
            Text('downloading'.tr, style: _readPageTextStyle()).marginOnly(top: 8),
            Text(index.toString(), style: _readPageTextStyle()),
          ],
        ),
      );
    });
  }

  TextStyle _readPageTextStyle() {
    return const TextStyle(
      color: Colors.white,
      fontSize: 12,
      decoration: TextDecoration.none,
    );
  }
}
