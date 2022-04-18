import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/home/tab_view/gallerys/widget/jump_page_dialog.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

import '../../model/gallery.dart';
import '../../routes/routes.dart';
import '../../service/tag_translation_service.dart';
import '../../utils/log.dart';
import '../../utils/route_util.dart';
import '../../utils/snack_util.dart';
import '../../widget/loading_state_indicator.dart';
import 'search_page_state.dart';

String appBarId = 'appBarId';
String searchField = 'searchField';
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
    if (state.prevPageNoToLoad != -1) {
      await loadBefore();
    } else {
      await searchMore(isRefresh: true);
    }
  }

  Future<void> loadBefore() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    Log.info('search data', false);

    if (state.showSuggestionAndHistory) {
      toggleBodyType();
    }

    state.loadingState = LoadingState.loading;
    update([bodyId]);

    List<dynamic> gallerysAndPageCount;
    try {
      if (state.redirectUrl == null) {
        gallerysAndPageCount = await EHRequest.requestGalleryPage(
          pageNo: state.prevPageNoToLoad,
          searchConfig: state.tabBarConfig.searchConfig,
          parser: EHSpiderParser.galleryPage2GalleryList,
        );
      } else {
        gallerysAndPageCount = await EHRequest.requestGalleryPage(
          url: state.redirectUrl,
          pageNo: state.prevPageNoToLoad,
          parser: EHSpiderParser.galleryPage2GalleryList,
        );
      }
    } on DioError catch (e) {
      Log.error('searchFailed'.tr, e.message);
      snack('searchFailed'.tr, e.message);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    state.gallerys.insertAll(0, gallerysAndPageCount[0]);
    state.pageCount = gallerysAndPageCount[1];
    state.prevPageNoToLoad--;
    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
      state.prevPageNoToLoad = -1;
    } else if (state.pageCount == state.nextPageNoToLoad) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    await tagTranslationService.translateGalleryTagsIfNeeded(state.gallerys);
    _writeHistory();
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
      state.nextPageNoToLoad = 0;
      state.pageCount = -1;
    }
    state.loadingState = LoadingState.loading;
    update([bodyId]);

    List<dynamic> gallerysAndPageCount;
    try {
      if (state.redirectUrl == null) {
        gallerysAndPageCount = await EHRequest.requestGalleryPage(
          pageNo: state.nextPageNoToLoad,
          searchConfig: state.tabBarConfig.searchConfig,
          parser: EHSpiderParser.galleryPage2GalleryList,
        );
      } else {
        gallerysAndPageCount = await EHRequest.requestGalleryPage(
          url: state.redirectUrl,
          pageNo: state.nextPageNoToLoad,
          parser: EHSpiderParser.galleryPage2GalleryList,
        );
      }
    } on DioError catch (e) {
      Log.error('searchFailed'.tr, e.message);
      snack('searchFailed'.tr, e.message);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    state.gallerys.addAll(gallerysAndPageCount[0]);
    state.pageCount = gallerysAndPageCount[1];
    state.nextPageNoToLoad++;
    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
      state.prevPageNoToLoad = -1;
    } else if (state.pageCount == state.nextPageNoToLoad) {
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
    state.nextPageNoToLoad = pageIndex;
    state.prevPageNoToLoad = pageIndex - 1;
    state.loadingState = LoadingState.loading;
    update([bodyId]);

    List<dynamic> gallerysAndPageCount;
    try {
      if (state.redirectUrl == null) {
        gallerysAndPageCount = await EHRequest.requestGalleryPage(
          pageNo: state.nextPageNoToLoad,
          searchConfig: state.tabBarConfig.searchConfig,
          parser: EHSpiderParser.galleryPage2GalleryList,
        );
      } else {
        gallerysAndPageCount = await EHRequest.requestGalleryPage(
          url: state.redirectUrl,
          pageNo: pageIndex,
          parser: EHSpiderParser.galleryPage2GalleryList,
        );
      }
    } on DioError catch (e) {
      Log.error('searchFailed'.tr, e.message);
      snack('searchFailed'.tr, e.message);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    state.gallerys.addAll(gallerysAndPageCount[0]);
    state.pageCount = gallerysAndPageCount[1];
    state.nextPageNoToLoad++;
    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
      state.prevPageNoToLoad = -1;
    } else if (state.pageCount == state.nextPageNoToLoad) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    await tagTranslationService.translateGalleryTagsIfNeeded(state.gallerys);
    _writeHistory();
    update([appBarId, bodyId]);
  }

  Future<void> handleOpenJumpDialog() async {
    int? pageIndex = await Get.dialog(
      JumpPageDialog(totalPageNo: state.pageCount, currentNo: state.nextPageNoToLoad),
    );
    if (pageIndex != null) {
      jumpPage(pageIndex);
    }
  }

  void toggleBodyType() {
    state.showSuggestionAndHistory = !state.showSuggestionAndHistory;
    update([appBarId, searchField, bodyId]);
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
      state.suggestions = await EHRequest.requestTagSuggestion(
        state.tabBarConfig.searchConfig.keyword!,
        EHSpiderParser.tagSuggestion2TagList,
      );
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
    state.nextPageNoToLoad = 0;
    state.pageCount = -1;
    state.loadingState = LoadingState.loading;
    state.tabBarConfig.searchConfig.keyword = null;
    update([bodyId, searchField]);

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
