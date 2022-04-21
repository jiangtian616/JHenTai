import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

import '../../../../model/base_gallery.dart';
import '../../../../routes/routes.dart';
import '../../../../service/tag_translation_service.dart';
import '../../../../utils/log.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/snack_util.dart';
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
      Log.error('getRanklistFailed'.tr, e.message);
      snack('getRanklistFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.getRanklistLoadingState[curType] = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    List<Map<String, dynamic>?> results = List.generate(baseGallerys[curType]!.length, (index) => null);
    try {
      await Future.wait(
        baseGallerys[curType]!
            .mapIndexed(
              (index, baseGallery) => EHRequest.requestDetailPage<Map<String, dynamic>>(
                galleryUrl: baseGallery.galleryUrl,
                parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
              ).then((value) => results[index] = value).catchError((error) {
                if (error is! DioError) {
                  throw error;
                }

                /// 404 => hide or remove
                if (error.response?.statusCode != 404) {
                  Log.error('${'getSomeOfGallerysFailed'.tr}: ${baseGallery.galleryUrl}', error.message);
                } else {
                  Log.info('Gallery 404: ${baseGallery.galleryUrl}', false);
                }
                throw error;
              }),
            )
            .toList(),
      );
    } on DioError catch (e) {
      snack(
        'getSomeOfGallerysFailed'.tr,
        e.message,
        longDuration: true,
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    results.removeWhere((r) => r == null);
    state.ranklistGallery[curType] = (results.map((r) => r!['gallery'] as Gallery).toList());
    state.ranklistGalleryDetails[curType] = (results.map((r) => r!['galleryDetails'] as GalleryDetail).toList());
    state.ranklistGalleryDetailsApikey[curType] = (results.map((r) => r!['apikey'] as String).toList());

    tagTranslationService.translateGalleryTagsIfNeeded(state.ranklistGallery[curType]!);
    tagTranslationService.translateGalleryDetailsTagsIfNeeded(state.ranklistGalleryDetails[curType]!);
    state.getRanklistLoadingState[curType] =
        state.ranklistGallery[curType]!.isNotEmpty ? LoadingState.noMore : LoadingState.noData;
    update([bodyId]);
  }

  Future<void> handleRefresh() async {
    state.listKey = UniqueKey();
    return getRanklist();
  }

  Future<void> handleTapCard(Gallery gallery) async {
    int index = state.ranklistGallery[state.ranklistType]!.indexWhere((g) => gallery.gid == g.gid);

    toNamed(
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
      state.listKey = UniqueKey();
      update([bodyId]);
      if (state.getRanklistLoadingState[result] != LoadingState.noMore) {
        getRanklist();
      }
    }
    state.ranklistType = result;
    update(['appBarTitleId']);
  }
}
