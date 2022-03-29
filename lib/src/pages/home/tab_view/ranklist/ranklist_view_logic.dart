import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/l18n/en_US.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

import '../../../../model/base_gallery.dart';
import '../../../../routes/routes.dart';
import '../../../../service/tag_translation_service.dart';
import '../../../../setting/gallery_setting.dart';
import '../../../../utils/log.dart';
import '../../../../widget/loading_state_indicator.dart';
import 'ranklist_view_state.dart';

String appBarTitleId = 'appBarTitleId';
String bodyId = 'bodyId';
String loadingStateId = 'loadingStateId';

class RanklistViewLogic extends GetxController {
  final RanklistViewState state = RanklistViewState();
  final TagTranslationService tagTranslationService = Get.find();

  Future<void> getRanklist([bool refresh = false]) async {
    RanklistType curType = state.ranklistType;

    if (state.getRanklistLoadingState[curType] == LoadingState.loading) {
      return;
    }
    if (state.getRanklistLoadingState[curType] == LoadingState.noMore) {
      return;
    }

    Log.info('get ranklist data', false);
    LoadingState prevState = state.getRanklistLoadingState[curType]!;
    state.getRanklistLoadingState[curType] = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update([loadingStateId]);
    }

    Map<RanklistType, List<BaseGallery>> baseGallerys = {};
    try {
      baseGallerys = await EHRequest.requestRankPage(EHSpiderParser.rankPage2Ranklists);
    } on DioError catch (e) {
      Log.error('get ranklist failed', e.message);
      Get.snackbar('getRanklistFailed'.tr, e.message, snackPosition: SnackPosition.BOTTOM);
      state.getRanklistLoadingState[curType] = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    for (BaseGallery baseGallery in baseGallerys[curType]!) {
      try {
        Map<String, dynamic> galleryAndDetailAndApikeyAndPageCount =
            await EHRequest.requestDetailPage<Map<String, dynamic>>(
          galleryUrl: baseGallery.galleryUrl,
          parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
        );
        state.ranklistGallery[curType]?.add(galleryAndDetailAndApikeyAndPageCount['gallery']);
        state.ranklistGalleryDetails[curType]?.add(galleryAndDetailAndApikeyAndPageCount['galleryDetails']);
        state.ranklistGalleryDetailsApikey[curType]?.add(galleryAndDetailAndApikeyAndPageCount['apikey']);
      } on DioError catch (e) {
        if (e.response?.statusCode != 404) {
          Log.error('get ranklist failed', e.message);
          Get.snackbar('getRanklistFailed'.tr, e.message, snackPosition: SnackPosition.BOTTOM);
          state.ranklistGallery[curType]?.clear();
          state.ranklistGalleryDetails[curType]?.clear();
          state.ranklistGalleryDetailsApikey[curType]?.clear();
          state.getRanklistLoadingState[curType] = LoadingState.error;
          update([bodyId]);
          return;
        }
      }
    }

    tagTranslationService.translateGalleryTagsIfNeeded(state.ranklistGallery[curType]!);
    tagTranslationService.translateGalleryDetailsTagsIfNeeded(state.ranklistGalleryDetails[curType]!);
    state.getRanklistLoadingState[curType] = LoadingState.noMore;
    update([bodyId]);
  }

  Future<void> handleRefresh() async {
    state.ranklistGallery[state.ranklistType]?.clear();
    state.getRanklistLoadingState[state.ranklistType] = LoadingState.idle;
    update([bodyId]);
    getRanklist();
  }

  Future<void> handleTapCard(Gallery gallery) async {
    int index = state.ranklistGallery[state.ranklistType]!.indexWhere((g) => gallery.gid == g.gid);

    Get.toNamed(
      Routes.details,
      arguments: [
        gallery,
        state.ranklistGalleryDetails[state.ranklistType]![index],
        state.ranklistGalleryDetailsApikey[state.ranklistType]![index],
      ],
    );
  }

  Future<void> handleChangeRanklist(RanklistType result) async {
    if (result != state.ranklistType) {
      state.ranklistType = result;
      update([bodyId]);
      getRanklist();
    }
    state.ranklistType = result;
    update(['appBarTitleId']);
  }
}
