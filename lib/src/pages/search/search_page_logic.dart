import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

import '../../model/gallery.dart';
import '../../routes/routes.dart';
import '../../service/tag_translation_service.dart';
import '../../setting/gallery_setting.dart';
import '../../utils/log.dart';
import '../../widget/loading_state_indicator.dart';
import 'search_page_state.dart';

class SearchPageLogic extends GetxController {
  final SearchPageState state = SearchPageState();
  final TagTranslationService tagTranslationService = Get.find();

  SearchPageLogic() {
    currentStackDepth++;
  }

  /// there may be more than one SearchPages in route stack at same time.
  /// use this param as a 'tag' to get target [SearchPageLogic] and [SearchPageState].
  /// when a SearchPageLogic is created, currentStackDepth++, when a SearchPageLogic is disposed, currentStackDepth--.
  static int currentStackDepth = 0;

  static SearchPageLogic get currentSearchPageLogic =>
      Get.find<SearchPageLogic>(tag: SearchPageLogic.currentStackDepth.toString());

  @override
  void onInit() {
    /// enter this page by tapping tag
    if (Get.arguments is String) {
      state.tabBarConfig.searchConfig.keyword = Get.arguments;
      search();
    }
    super.onInit();
  }

  Future<void> search({bool isRefresh = true}) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    Log.info('search data', false);
    if (isRefresh) {
      state.gallerys.clear();
      state.nextPageNoToLoad = 0;
      state.pageCount = -1;
    }
    state.loadingState = LoadingState.loading;
    update();

    try {
      List<dynamic> gallerysAndPageCount = await EHRequest.requestGalleryPage(
        pageNo: state.nextPageNoToLoad,
        searchConfig: state.tabBarConfig.searchConfig,
        parser: EHSpiderParser.galleryPage2GalleryList,
      );
      state.gallerys.addAll(gallerysAndPageCount[0]);
      state.pageCount = gallerysAndPageCount[1];
    } on DioError catch (e) {
      Log.error('search Failed', e.message);
      Get.snackbar('searchFailed'.tr, e.message, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = LoadingState.error;
      update();
      return;
    }

    state.nextPageNoToLoad++;

    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
    } else if (state.pageCount == state.nextPageNoToLoad) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    await tagTranslationService.translateGalleryTagsIfNeeded(state.gallerys);

    update();
  }

  void handleTapCard(Gallery gallery) {
    Get.toNamed(Routes.details, arguments: gallery);
  }
}
