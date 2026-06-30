import 'dart:collection';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_count.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_page.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/local_search/local_search_state.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/uuid_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class LocalSearchLogic extends BasePageLogic {
  @override
  final LocalSearchState state = LocalSearchState();

  int _searchTicket = 0;
  late final TextEditingController textEditingController;
  late final FocusNode searchFocusNode;

  @override
  Future<void> onInit() async {
    textEditingController = TextEditingController(text: state.searchConfig.keyword ?? '');
    searchFocusNode = FocusNode();
    await super.onInit();
  }

  @override
  void onClose() {
    textEditingController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  @override
  bool get useSearchConfig => false;

  @override
  bool get autoLoadForFirstTime => false;

  Future<void> handleSearch(String keyword) async {
    keyword = keyword.trim();
    if (keyword.isEmpty) {
      return;
    }
    state.searchConfig.keyword = keyword;
    if (textEditingController.text != keyword) {
      textEditingController.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
    await handleClearAndRefresh();
  }

  @override
  Future<void> handleClearAndRefresh() async {
    String keyword = state.searchConfig.keyword?.trim() ?? '';
    if (keyword.isEmpty) {
      return;
    }

    int ticket = ++_searchTicket;
    state.hasSearched = true;
    state.loadingState = LoadingState.loading;
    state.refreshState = LoadingState.idle;
    state.gallerys.clear();
    state.prevGid = null;
    state.nextGid = null;
    state.seek = DateTime.now();
    state.totalCount = null;
    state.favoriteSortOrder = null;
    state.pageStorageKey = PageStorageKey('$runtimeType::$ticket::${newUUID()}');
    state.galleryCollectionKey = Key('$runtimeType::gallery::$ticket::${newUUID()}');

    jump2Top();
    updateSafely();

    GalleryPageInfo galleryPage;
    try {
      galleryPage = await _queryLocalGalleryPage(keyword);
    } catch (e) {
      if (ticket != _searchTicket) {
        return;
      }
      log.error('Local search failed', e);
      state.loadingState = LoadingState.error;
      updateSafely();
      return;
    }

    if (ticket != _searchTicket) {
      return;
    }

    List<Gallery> gallerys = await postHandleNewGallerys(galleryPage.gallerys);
    if (ticket != _searchTicket) {
      return;
    }

    state.gallerys = gallerys;
    state.totalCount = GalleryCount(count: gallerys.length.toString(), type: GalleryCountType.accurate);
    state.prevGid = null;
    state.nextGid = null;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;
    state.loadingState = gallerys.isEmpty ? LoadingState.noData : LoadingState.noMore;

    updateSafely();
  }

  @override
  Future<void> loadMore({bool checkLoadingState = true}) {
    return handleClearAndRefresh();
  }

  @override
  Future<void> handlePullDown() {
    return handleClearAndRefresh();
  }

  @override
  Future<GalleryPageInfo> getGalleryPage({String? prevGid, String? nextGid, DateTime? seek}) async {
    return _queryLocalGalleryPage(state.searchConfig.keyword?.trim() ?? '');
  }

  Future<GalleryPageInfo> _queryLocalGalleryPage(String keyword) async {
    List<GalleryDownloadedData> galleries = await (appDb.select(appDb.galleryDownloaded)
          ..where((t) => t.title.contains(keyword)))
        .get();

    List<ArchiveDownloadedData> archives = await (appDb.select(appDb.archiveDownloaded)
          ..where((t) => t.title.contains(keyword)))
        .get();

    List<Gallery> result = [];
    final GalleryDownloadService galleryDownloadService = Get.find<GalleryDownloadService>();

    for (var g in galleries) {
      GalleryImage? image = galleryDownloadService.galleryDownloadInfos[g.gid]?.images[0];

      result.add(Gallery(
        galleryUrl: GalleryUrl.parse(g.galleryUrl),
        title: g.title,
        category: g.category,
        cover: image ?? GalleryImage(url: ''),
        pageCount: g.pageCount,
        rating: 0,
        hasRated: false,
        uploader: g.uploader,
        publishTime: g.publishTime,
        isExpunged: false,
        tags: LinkedHashMap(),
      ));
    }

    for (var a in archives) {
      if (result.any((e) => e.gid == a.gid)) {
        continue;
      }
      result.add(Gallery(
        galleryUrl: GalleryUrl.parse(a.galleryUrl),
        title: a.title,
        category: a.category,
        cover: GalleryImage(url: a.coverUrl),
        pageCount: a.pageCount,
        rating: 0,
        hasRated: false,
        uploader: a.uploader,
        publishTime: a.publishTime,
        isExpunged: false,
        tags: LinkedHashMap(),
      ));
    }

    return GalleryPageInfo(
      gallerys: result,
      totalCount: GalleryCount(count: result.length.toString(), type: GalleryCountType.accurate),
      nextGid: null,
      prevGid: null,
    );
  }
}
