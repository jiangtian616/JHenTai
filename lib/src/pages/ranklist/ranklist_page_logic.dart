import 'dart:async';

import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../utils/log.dart';
import '../base/base_page_logic.dart';

class RanklistPageLogic extends BasePageLogic {
  @override
  final String pageId = 'pageId';
  @override
  final String appBarId = 'appBarId';
  @override
  final String bodyId = 'bodyId';
  @override
  final String refreshStateId = 'refreshStateId';
  @override
  final String loadingStateId = 'loadingStateId';

  @override
  int get tabIndex => 3;

  @override
  bool get autoLoadForFirstTime => true;

  @override
  final RanklistPageState state = RanklistPageState();

  Future<void> handleChangeRanklist(RanklistType result) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    if (result != state.ranklistType) {
      state.ranklistType = result;
      super.clearAndRefresh();
    }
  }

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex) async {
    Log.info('Get ranklist data, type:${state.ranklistType.name}, pageIndex:$pageIndex', false);

    List<dynamic> gallerysAndPageInfo = await EHRequest.requestRanklistPage(
      ranklistType: state.ranklistType,
      pageNo: pageIndex,
      parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
    );

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    return gallerysAndPageInfo;
  }
}
