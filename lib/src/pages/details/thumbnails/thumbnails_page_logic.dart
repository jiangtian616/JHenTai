import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/pages/details/thumbnails/thumbnails_page_state.dart';

import '../../../exception/eh_exception.dart';
import '../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../model/gallery_thumbnail.dart';
import '../../../network/eh_request.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/jump_page_dialog.dart';
import '../../../widget/loading_state_indicator.dart';

class ThumbnailsPageLogic extends GetxController with Scroll2TopLogicMixin {
  static const String thumbnailsId = 'thumbnailsId';
  static const String loadingStateId = 'loadingStateId';

  ThumbnailsPageState state = ThumbnailsPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  DetailsPageLogic detailsPageLogic = DetailsPageLogic.current!;
  DetailsPageState detailsPageState = DetailsPageLogic.current!.state;

  @override
  void onReady() {
    super.onReady();
    loadMoreThumbnails();
  }

  Future<void> loadMoreThumbnails() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    /// no more thumbnails
    if (state.nextPageIndexToLoadThumbnails >= detailsPageState.galleryDetails!.thumbnailsPageCount) {
      state.loadingState = LoadingState.noMore;
      updateSafely([loadingStateId]);
      return;
    }

    state.loadingState = LoadingState.loading;
    updateSafely([loadingStateId]);

    Map<String, dynamic> rangeAndThumbnails;
    try {
      rangeAndThumbnails = await EHRequest.requestDetailPage(
        galleryUrl: detailsPageState.galleryUrl,
        thumbnailsPageIndex: state.nextPageIndexToLoadThumbnails,
        parser: EHSpiderParser.detailPage2RangeAndThumbnails,
      );
    } on DioError catch (e) {
      Log.error('failToGetThumbnails'.tr, e.message);
      snack('failToGetThumbnails'.tr, e.message, longDuration: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    } on EHException catch (e) {
      Log.error('failToGetThumbnails'.tr, e.message);
      snack('failToGetThumbnails'.tr, e.message, longDuration: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    }

    int rangeIndexFrom = rangeAndThumbnails['rangeIndexFrom'];
    int rangeIndexTo = rangeAndThumbnails['rangeIndexTo'];
    List<GalleryThumbnail> newThumbnails = rangeAndThumbnails['thumbnails'];

    state.thumbnails.addAll(newThumbnails);
    for (int i = rangeIndexFrom; i <= rangeIndexTo; i++) {
      state.absoluteIndexOfThumbnails.add(i);
    }
    state.nextPageIndexToLoadThumbnails++;

    state.loadingState = LoadingState.idle;
    updateSafely();
  }

  Future<void> handleTapJumpButton() async {
    int? pageIndex = await Get.dialog(
      JumpPageDialog(
        totalPageNo: detailsPageState.galleryDetails!.thumbnailsPageCount,
        currentNo: state.nextPageIndexToLoadThumbnails,
      ),
    );

    if (pageIndex != null && state.loadingState != LoadingState.loading) {
      state.thumbnails.clear();
      state.absoluteIndexOfThumbnails.clear();
      state.initialPageIndex = pageIndex;
      state.nextPageIndexToLoadThumbnails = pageIndex;
      updateSafely();
      loadMoreThumbnails();
    }
  }
}
