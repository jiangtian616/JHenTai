import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/icon_text_button.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class ReadPage extends StatelessWidget {
  final logic = Get.put(ReadPageLogic());
  final state = Get.find<ReadPageLogic>().state;

  ReadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Center(
        child: FlutterListView(
          controller: state.listViewController,
          delegate: FlutterListViewDelegate(
            (BuildContext context, int index) {
              /// too complicated, so i use Obx()
              return Obx(() {
                /// step 1: parsing thumbnail if needed. check thumbnail info whether exists, if not, [parse] one page of thumbnails
                if (state.thumbnails.isEmpty || state.thumbnails[index].value == null) {
                  if (state.thumbnailsParsingState.value == LoadingState.idle) {
                    logic.beginParseThumbnails(index);
                  }
                  return _buildParsingThumbnailsIndicator(context, index);
                }

                /// step 2: parsing image url. [parse] one image's raw data
                if (state.images[index].value == null) {
                  if (state.imageParsingStates[index].value == LoadingState.idle) {
                    logic.beginParseGalleryImage(index);
                  }
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
                );
              });
            },
            initIndex: state.initialIndex,
            childCount: state.pageCount,
            preferItemHeight: context.height,
          ),
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
            loadingState: state.thumbnailsParsingState.value,
            idleWidget: const CircularProgressIndicator(),
            errorTapCallback: () => logic.beginParseThumbnails(index),
          ),
          Text(
            state.thumbnailsParsingState.value == LoadingState.error ? 'parsePageFailed'.tr : 'parsingPage'.tr,
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
          LoadingStateIndicator(
            userCupertinoIndicator: false,
            loadingState: state.imageParsingStates[index].value,
            idleWidget: const CircularProgressIndicator(),
            errorTapCallback: () => logic.beginParseGalleryImage(index),
          ),
          Text(
            state.imageParsingStates[index].value == LoadingState.error ? 'parseURLFailed'.tr : 'parsingURL'.tr,
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

  TextStyle _readPageTextStyle() {
    return const TextStyle(
      color: Colors.white,
      fontSize: 12,
      decoration: TextDecoration.none,
    );
  }
}
