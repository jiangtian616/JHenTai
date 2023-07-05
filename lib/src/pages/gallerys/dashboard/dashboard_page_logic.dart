import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/dashboard_page_state.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';

import '../../../consts/eh_consts.dart';
import '../../../exception/eh_exception.dart';
import '../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../model/gallery_page.dart';
import '../../../network/eh_request.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/loading_state_indicator.dart';

class DashboardPageLogic extends BasePageLogic {
  final String ranklistId = 'ranklistId';
  final String popularListId = 'popularListId';
  final String galleryListId = 'galleryListId';

  @override
  bool get autoLoadForFirstTime => false;

  @override
  bool get useSearchConfig => true;

  @override
  DashboardPageState state = DashboardPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

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

    Log.info('Get ranklist data');

    List<dynamic> gallerysAndPageInfo;
    try {
      gallerysAndPageInfo = await EHRequest.requestRanklistPage(
        ranklistType: RanklistType.day,
        pageNo: 0,
        parser: EHSpiderParser.ranklistPage2GalleryPageInfo,
      );
    } on DioError catch (e) {
      Log.error('getRanklistFailed'.tr, e.message);
      snack('getRanklistFailed'.tr, e.message, longDuration: true);
      state.ranklistLoadingState = LoadingState.error;
      update([ranklistId]);
      return;
    } on EHException catch (e) {
      Log.error('getRanklistFailed'.tr, e.message);
      snack('getRanklistFailed'.tr, e.message, longDuration: true);
      state.ranklistLoadingState = LoadingState.error;
      update([ranklistId]);
      return;
    }

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    state.ranklistGallerys = gallerysAndPageInfo[0];

    handleGalleryByLocalTags(state.ranklistGallerys);
    
    state.ranklistLoadingState = LoadingState.success;
    update([ranklistId]);
  }

  Future<void> loadPopular() async {
    if (state.popularLoadingState == LoadingState.loading) {
      return;
    }

    state.popularLoadingState = LoadingState.loading;
    update([popularListId]);

    Log.info('Get popular list data');

    GalleryPageInfo gallerysPage;
    try {
      gallerysPage = await EHRequest.requestGalleryPage(
        url: EHConsts.EPopular,
        parser: EHSpiderParser.galleryPage2GalleryPageInfo,
      );
    } on DioError catch (e) {
      Log.error('getPopularListFailed'.tr, e.message);
      snack('getPopularListFailed'.tr, e.message, longDuration: true);
      state.popularLoadingState = LoadingState.error;
      update([popularListId]);
      return;
    } on EHException catch (e) {
      Log.error('getPopularListFailed'.tr, e.message);
      snack('getPopularListFailed'.tr, e.message, longDuration: true);
      state.popularLoadingState = LoadingState.error;
      update([popularListId]);
      return;
    }

    await translateGalleryTagsIfNeeded(gallerysPage.gallerys);

    state.popularGallerys = gallerysPage.gallerys;

    handleGalleryByLocalTags(state.popularGallerys);
    
    state.popularLoadingState = LoadingState.success;
    update([popularListId]);
  }

  /// pull-down to refresh ranklist & popular & gallerys, we need to sync loading state manually because [handleRefresh] doesn't
  /// refresh loading state
  Future<void> handleRefreshTotalPage() async {
    state.loadingState = LoadingState.loading;
    update([loadingStateId]);

    await Future.any([
      super.handleRefresh(updateId: galleryListId).then((_) {
        state.loadingState = state.refreshState;
        update([loadingStateId]);
      }),
      loadRanklist(),
      loadPopular(),
    ]);
  }
}
