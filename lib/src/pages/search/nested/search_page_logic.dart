import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/search/nested/search_page_state.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/widget/jump_page_dialog.dart';

import '../../../model/gallery.dart';
import '../../../routes/routes.dart';
import '../../../service/tag_translation_service.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/loading_state_indicator.dart';

String appBarId = 'appBarId';
String searchFieldId = 'searchFieldId';
String bodyId = 'bodyId';
String loadingStateId = 'loadingStateId';

class SearchPageLogic extends GetxController {
  /// there may be more than one DetailsPages in route stack at same time, eg: tag a link in a comment.
  /// use this param as a 'tag' to get target [DetailsPageLogic] and [DetailsPageState].
  String tag;

  final SearchPageState state = SearchPageState();
  final TagTranslationService tagTranslationService = Get.find();
  final StorageService storageService = Get.find();

  /// used for delayed search suggestion
  Timer? timer;

  static final List<SearchPageLogic> stack = <SearchPageLogic>[];

  static SearchPageLogic? get current => stack.isEmpty ? null : stack.last;

  SearchPageLogic(this.tag) {
    stack.add(this);
  }

  @override
  void onInit() {
    /// enter this page by tapping tag
    if (Get.arguments is String) {
      state.tabBarConfig.searchConfig.keyword = Get.arguments;
      searchMore();
    }
    super.onInit();
  }

  @override
  void onClose() {
    stack.remove(this);
    super.onClose();
  }

  Future<void> handlePullDown() async {
    if (state.prevPageNoToLoad != null) {
      await loadBefore();
    } else {
      await searchMore(isRefresh: true);
    }
  }

  Future<void> loadBefore() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    Log.info('search data before', false);

    if (state.showSuggestionAndHistory) {
      toggleBodyType();
    }

    state.loadingState = LoadingState.loading;
    update([bodyId]);

    List<dynamic> gallerysAndPageInfo;
    try {
      if (state.redirectUrl == null) {
        gallerysAndPageInfo = await EHRequest.requestGalleryPage(
          pageNo: state.prevPageNoToLoad!,
          searchConfig: state.tabBarConfig.searchConfig,
          parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
        );
      } else {
        gallerysAndPageInfo = await EHRequest.requestGalleryPage(
          url: state.redirectUrl,
          pageNo: state.prevPageNoToLoad!,
          parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
        );
      }
    } on DioError catch (e) {
      Log.error('searchFailed'.tr, e.message);
      snack('searchFailed'.tr, e.message);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    state.gallerys.insertAll(0, gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.nextPageNoToLoad = gallerysAndPageInfo[2];
    state.prevPageNoToLoad = gallerysAndPageInfo[3];

    await tagTranslationService.translateGalleryTagsIfNeeded(state.gallerys);

    state.loadingState = LoadingState.idle;
    update([appBarId, bodyId]);
  }

  Future<void> searchMore({bool isRefresh = true}) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    Log.info('search data', false);

    if (state.showSuggestionAndHistory) {
      toggleBodyType();
    }

    if (isRefresh) {
      state.gallerys.clear();
      state.prevPageNoToLoad = null;
      state.nextPageNoToLoad = 0;
      state.pageCount = -1;
    }
    state.loadingState = LoadingState.loading;
    update([bodyId, searchFieldId]);

    List<dynamic> gallerysAndPageInfo;
    try {
      if (state.redirectUrl == null) {
        gallerysAndPageInfo = await EHRequest.requestGalleryPage(
          pageNo: state.nextPageNoToLoad!,
          searchConfig: state.tabBarConfig.searchConfig,
          parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
        );
      } else {
        gallerysAndPageInfo = await EHRequest.requestGalleryPage(
          url: state.redirectUrl,
          pageNo: state.nextPageNoToLoad!,
          parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
        );
      }
    } on DioError catch (e) {
      Log.error('searchFailed'.tr, e.message);
      snack('searchFailed'.tr, e.message);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    state.gallerys.addAll(gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.nextPageNoToLoad = gallerysAndPageInfo[3];
    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextPageNoToLoad == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    await tagTranslationService.translateGalleryTagsIfNeeded(state.gallerys);
    _writeHistory();
    update([appBarId, bodyId]);
  }

  Future<void> jumpPage(int pageIndex) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    Log.info('jumpPage to $pageIndex', false);

    if (state.showSuggestionAndHistory) {
      toggleBodyType();
    }

    state.gallerys.clear();
    pageIndex = max(pageIndex, 0);
    pageIndex = min(pageIndex, state.pageCount - 1);
    state.nextPageNoToLoad = null;
    state.prevPageNoToLoad = null;
    state.loadingState = LoadingState.loading;
    update([bodyId]);

    List<dynamic> gallerysAndPageInfo;
    try {
      if (state.redirectUrl == null) {
        gallerysAndPageInfo = await EHRequest.requestGalleryPage(
          pageNo: pageIndex,
          searchConfig: state.tabBarConfig.searchConfig,
          parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
        );
      } else {
        gallerysAndPageInfo = await EHRequest.requestGalleryPage(
          url: state.redirectUrl,
          pageNo: pageIndex,
          parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
        );
      }
    } on DioError catch (e) {
      Log.error('searchFailed'.tr, e.message);
      snack('searchFailed'.tr, e.message);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    state.gallerys.addAll(gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.nextPageNoToLoad = gallerysAndPageInfo[2];
    state.prevPageNoToLoad = gallerysAndPageInfo[3];
    if (state.nextPageNoToLoad == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    await tagTranslationService.translateGalleryTagsIfNeeded(state.gallerys);
    update([appBarId, bodyId]);
  }

  Future<void> handleOpenJumpDialog() async {
    int? pageIndex = await Get.dialog(
      JumpPageDialog(totalPageNo: state.pageCount, currentNo: state.nextPageNoToLoad ?? state.pageCount),
    );
    if (pageIndex != null) {
      jumpPage(pageIndex);
    }
  }

  void toggleBodyType() {
    state.showSuggestionAndHistory = !state.showSuggestionAndHistory;
    update([appBarId, searchFieldId, bodyId]);
  }

  void _writeHistory() {
    /// do not record file search
    if (state.redirectUrl != null) {
      return;
    }
    if (state.tabBarConfig.searchConfig.keyword?.isEmpty ?? true) {
      return;
    }

    List history = storageService.read('searchHistory') ?? <String>[];
    history.remove(state.tabBarConfig.searchConfig.keyword);
    history.insert(0, state.tabBarConfig.searchConfig.keyword);
    storageService.write('searchHistory', history);
  }

  List<String> getSearchHistory() {
    List history = storageService.read('searchHistory') ?? <String>[];
    return history.cast<String>();
  }

  void clearHistory() {
    storageService.remove('searchHistory').then((v) {
      if (state.showSuggestionAndHistory) {
        update([bodyId]);
      }
    });
  }

  /// search only if there's no timer active (300ms)
  Future<void> waitAndSearchTags() async {
    timer?.cancel();

    if (state.tabBarConfig.searchConfig.keyword?.isEmpty ?? true) {
      return;
    }
    timer = Timer(const Duration(milliseconds: 300), searchTags);
  }

  Future<void> searchTags() async {
    Log.info('search for ${state.tabBarConfig.searchConfig.keyword}', false);

    /// chinese => database
    /// other => EH api
    if (StyleSetting.enableTagZHTranslation.isTrue &&
        tagTranslationService.loadingState.value == LoadingState.success) {
      state.suggestions = await tagTranslationService.searchTags(state.tabBarConfig.searchConfig.keyword!);
    } else {
      try {
        state.suggestions = await EHRequest.requestTagSuggestion(
          state.tabBarConfig.searchConfig.keyword!,
          EHSpiderParser.tagSuggestion2TagList,
        );
      } on DioError catch (e) {
        Log.error('Request tag suggestion failed', e);
      }
    }

    if (state.showSuggestionAndHistory) {
      update([bodyId]);
    }
  }

  Future<void> handlePickImage() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
    } on Exception catch (e) {
      Log.error('Pick file failed', e);
    }

    if (result == null) {
      return;
    }

    Log.info('file search', false);

    if (state.showSuggestionAndHistory) {
      toggleBodyType();
    }

    state.gallerys.clear();
    state.prevPageNoToLoad = null;
    state.nextPageNoToLoad = 0;
    state.pageCount = -1;
    state.loadingState = LoadingState.loading;
    state.tabBarConfig.searchConfig.keyword = null;
    update([bodyId, searchFieldId]);

    try {
      state.redirectUrl = await EHRequest.requestLookup(
        imagePath: result.files.first.path!,
        imageName: result.files.first.name,
        parser: EHSpiderParser.imageLookup2RedirectUrl,
      );
    } on DioError catch (e) {
      Log.error('fileSearchFailed'.tr, e.message);
      snack('fileSearchFailed'.tr, e.message);
      state.loadingState = LoadingState.idle;
      update([loadingStateId]);
      return;
    }

    state.loadingState = LoadingState.idle;
    searchMore();
  }

  void handleTapCard(Gallery gallery) {
    toNamed(Routes.details, arguments: gallery);
  }
}
