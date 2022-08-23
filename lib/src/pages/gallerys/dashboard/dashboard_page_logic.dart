import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/dashboard_page_state.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';

import '../../../consts/eh_consts.dart';
import '../../../network/eh_request.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/loading_state_indicator.dart';

class DashboardPageLogic extends BasePageLogic {
  @override
  final String pageId = 'pageId';
  @override
  final String appBarId = 'appBarId';
  @override
  final String bodyId = 'bodyId';
  @override
  final String scroll2TopButtonId = 'scroll2TopButtonId';
  @override
  final String refreshStateId = 'refreshStateId';
  @override
  final String loadingStateId = 'loadingStateId';

  final String ranklistId = 'ranklistId';
  final String popularListId = 'popularListId';
  final String galleryListId = 'galleryListId';

  @override
  bool get autoLoadForFirstTime => false;

  @override
  bool get useSearchConfig => true;

  @override
  int get tabIndex => 0;

  @override
  DashboardPageState state = DashboardPageState();

  @override
  void onReady() {
    super.onReady();
    loadMore();
    loadRanklist();
    loadPopular();
  }

  Future<void> loadRanklist() async {
    if (state.ranklistLoadingState == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.ranklistLoadingState;
    state.ranklistLoadingState = LoadingState.loading;
    if (prevState == LoadingState.error || prevState == LoadingState.noData) {
      update([ranklistId]);
    }

    Log.info('Get ranklist data', false);
    List<dynamic> gallerysAndPageInfo;
    try {
      gallerysAndPageInfo = await EHRequest.requestRanklistPage(
        ranklistType: RanklistType.day,
        pageNo: 0,
        parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
      );
    } on DioError catch (e) {
      Log.error('getRanklistFailed'.tr, e.message);
      snack('getRanklistFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.ranklistLoadingState = LoadingState.error;
      update([ranklistId]);
      return;
    }

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    state.ranklistGallerys = gallerysAndPageInfo[0];
    state.ranklistLoadingState = LoadingState.success;
    update([ranklistId]);
  }

  Future<void> loadPopular() async {
    if (state.popularLoadingState == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.popularLoadingState;
    state.popularLoadingState = LoadingState.loading;
    if (prevState == LoadingState.error || prevState == LoadingState.noData) {
      update([popularListId]);
    }

    Log.info('Get popular list data', false);
    List<dynamic> gallerysAndPageInfo;
    try {
      gallerysAndPageInfo = await EHRequest.requestGalleryPage(
        pageNo: 0,
        url: EHConsts.EPopular,
        parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
      );
      gallerysAndPageInfo[1] = 1;
    } on DioError catch (e) {
      Log.error('getPopularListFailed'.tr, e.message);
      snack('getPopularListFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.popularLoadingState = LoadingState.error;
      update([popularListId]);
      return;
    }

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    state.popularGallerys = gallerysAndPageInfo[0];
    state.popularLoadingState = LoadingState.success;
    update([popularListId]);
  }

  /// pull-down to refresh ranklist & popular & gallerys
  Future<void> handleRefreshTotalPage() async {
    return Future.any([
      super.handleRefresh(refreshId: galleryListId),
      loadRanklist(),
      loadPopular(),
    ]);
  }

  @override
  Future<List> getGallerysAndPageInfoByPage(int pageIndex) async {
    Log.info('Get gallery data, pageIndex:$pageIndex', false);

    List<dynamic> gallerysAndPageInfo = await EHRequest.requestGalleryPage(
      pageNo: pageIndex,
      searchConfig: state.searchConfig,
      parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
    );

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    return gallerysAndPageInfo;
  }
}
