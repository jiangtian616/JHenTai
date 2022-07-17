import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/search/simple/simple_search_page_state.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

import '../../../model/search_config.dart';
import '../../../service/tag_translation_service.dart';
import '../../../utils/log.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/eh_search_config_dialog.dart';
import '../../../widget/loading_state_indicator.dart';
import '../../base/base_page_logic.dart';

class SimpleSearchPageLogic extends BasePageLogic {
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
  final String searchFieldId = 'searchFieldId';

  @override
  int get tabIndex => 1;

  @override
  bool get useSearchConfig => false;

  @override
  bool get autoLoadFirstPage => false;

  @override
  final SimpleSearchPageState state = SimpleSearchPageState();
  final TagTranslationService tagTranslationService = Get.find();
  final QuickSearchService quickSearchService = Get.find();
  final StorageService storageService = Get.find();

  /// used for delayed search suggestion
  Timer? timer;
  static const Duration searchDelay = Duration(milliseconds: 300);

  @override
  Future<void> clearAndRefresh() async {
    state.hasSearched = true;

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      toggleBodyType();
    }
    state.redirectUrl = null;

    _writeHistory();

    /// Reset scroll offset
    state.pageStorageKey = PageStorageKey('$runtimeType::${Random().nextInt(9999999)}');

    return super.clearAndRefresh();
  }

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageNo) async {
    Log.verbose('Get gallerys info at page: $pageNo');

    List<dynamic> gallerysAndPageInfo;
    if (state.redirectUrl == null) {
      gallerysAndPageInfo = await EHRequest.requestGalleryPage(
        pageNo: pageNo,
        searchConfig: state.searchConfig,
        parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
      );
    } else {
      gallerysAndPageInfo = await EHRequest.requestGalleryPage(
        url: state.redirectUrl,
        pageNo: pageNo,
        parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
      );
    }

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    return gallerysAndPageInfo;
  }

  Future<void> handleFileSearch() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(type: FileType.image);
    } on Exception catch (e) {
      Log.error('Pick file failed', e);
    }

    if (result == null) {
      return;
    }

    Log.info('File search', false);

    state.hasSearched = true;

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      toggleBodyType();
    }

    state.gallerys.clear();
    state.prevPageIndexToLoad = null;
    state.nextPageIndexToLoad = 0;
    state.pageCount = -1;

    state.loadingState = LoadingState.loading;
    state.searchConfig.keyword = null;
    update([pageId]);

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

    loadMore(checkLoadingState: false);
  }

  Future<void> addQuickSearch() async {
    Map<String, dynamic>? result = await Get.dialog(
      EHSearchConfigDialog(searchConfig: state.searchConfig, type: EHSearchConfigDialogType.add),
    );

    if (result == null) {
      return;
    }

    String quickSearchName = result['quickSearchName'];
    SearchConfig searchConfig = result['searchConfig'];
    quickSearchService.addQuickSearch(quickSearchName, searchConfig);
  }

  /// search only if there's no timer active (300ms)
  Future<void> waitAndSearchTags() async {
    timer?.cancel();

    if (state.searchConfig.keyword?.isEmpty ?? true) {
      return;
    }
    timer = Timer(searchDelay, searchTags);
  }

  Future<void> searchTags() async {
    Log.info('search for ${state.searchConfig.keyword}', false);

    /// chinese => database
    /// other => EH api
    if (StyleSetting.enableTagZHTranslation.isTrue && tagTranslationService.loadingState.value == LoadingState.success) {
      state.suggestions = await tagTranslationService.searchTags(state.searchConfig.keyword!);
    } else {
      try {
        state.suggestions = await EHRequest.requestTagSuggestion(state.searchConfig.keyword!, EHSpiderParser.tagSuggestion2TagList);
      } on DioError catch (e) {
        Log.error('Request tag suggestion failed', e);
      }
    }

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      update([pageId]);
    }
  }

  List<String> getSearchHistory() {
    List history = storageService.read('searchHistory') ?? <String>[];
    return history.cast<String>();
  }

  void _writeHistory() {
    /// do not record file search
    if (state.redirectUrl != null) {
      return;
    }

    if (state.searchConfig.keyword?.isEmpty ?? true) {
      return;
    }

    List history = storageService.read('searchHistory') ?? <String>[];
    history.remove(state.searchConfig.keyword);
    history.insert(0, state.searchConfig.keyword);
    storageService.write('searchHistory', history);
  }

  void clearHistory() {
    storageService.remove('searchHistory').then((_) {
      if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
        update([pageId]);
      }
    });
  }

  void updateBody() {
    update([bodyId]);
  }

  void toggleBodyType() {
    state.bodyType = (state.bodyType == SearchPageBodyType.gallerys ? SearchPageBodyType.suggestionAndHistory : SearchPageBodyType.gallerys);
    update([pageId]);
  }
}
