import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/storage_enum.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:throttling/throttling.dart';

import '../../database/database.dart';
import '../../model/gallery_image.dart';
import '../../model/read_page_info.dart';
import '../../routes/routes.dart';
import '../../service/archive_download_service.dart';
import '../../service/gallery_download_service.dart';
import '../../service/super_resolution_service.dart';
import '../../setting/read_setting.dart';
import '../../utils/process_util.dart';
import '../../utils/route_util.dart';
import '../../utils/table.dart' as t;
import 'download_search_state.dart';

class DownloadSearchLogic extends GetxController {
  final DownloadSearchState state = DownloadSearchState();

  final String loadingStateId = 'loadingStateId';
  final String searchFieldId = 'searchFieldId';
  final String bodyId = 'bodyId';

  final GalleryDownloadService galleryDownloadService = Get.find();
  final ArchiveDownloadService archiveDownloadService = Get.find();
  final SuperResolutionService superResolutionService = Get.find();
  final StorageService storageService = Get.find();
  final TagTranslationService tagTranslationService = Get.find();

  late final TextEditingController textEditingController;
  late final FocusNode searchFocusNode;
  late final Debouncing searchDebouncing;
  late final ScrollController scrollController;

  LoadingState loadingState = LoadingState.idle;

  @override
  void onInit() {
    textEditingController = TextEditingController();
    searchFocusNode = FocusNode();
    searchDebouncing = Debouncing(duration: const Duration(milliseconds: 300));
    scrollController = ScrollController();
    int? code = storageService.read(StorageEnum.downloadSearchPageType.key);
    if (code != null) {
      state.searchType = DownloadSearchConfigTypeEnum.fromCode(code);
    }
    super.onInit();
  }

  @override
  void onClose() {
    textEditingController.dispose();
    searchFocusNode.dispose();
    searchDebouncing.close();
    scrollController.dispose();
    super.onClose();
  }

  void handleTapClearButton() {
    textEditingController.clear();
  }

  void handleSearchFieldChanged(String value) {
    if (value.isBlank!) {
      return;
    }
    searchDebouncing.debounce(() => search(value));
  }

  Future<void> search(String value) async {
    Log.info('search downloaded info: $value');

    if (loadingState == LoadingState.loading) {
      return;
    }

    loadingState = LoadingState.loading;
    state.gallerys.clear();
    state.archives.clear();
    updateSafely([loadingStateId]);

    List<TagData> allGalleryTags = galleryDownloadService.gallerys.map((g) => g.tags).mapMany(tagDataString2TagDataList).toList();
    List<TagData> allArchiveTags = archiveDownloadService.archives.map((a) => a.tags).mapMany(tagDataString2TagDataList).toList();
    List<TagData> allTags = {...allGalleryTags, ...allArchiveTags}.toList();
    List<TagData> translatedTags = await tagTranslationService.translateTagDatasIfNeeded(allTags);
    t.Table<String, String, TagData> translatedTagDataTable = t.Table();
    for (TagData tag in translatedTags) {
      translatedTagDataTable.put(tag.namespace, tag.key, tag);
    }

    List<GallerySearchVO> gallerys = galleryDownloadService.gallerys
        .map(
          (g) => GallerySearchVO(
            gid: g.gid,
            token: g.token,
            title: g.title,
            category: g.category,
            pageCount: g.pageCount,
            galleryUrl: g.galleryUrl,
            oldVersionGalleryUrl: g.oldVersionGalleryUrl,
            uploader: g.uploader,
            publishTime: g.publishTime,
            insertTime: g.insertTime,
            downloadOriginalImage: g.downloadOriginalImage,
            priority: g.priority,
            sortOrder: g.sortOrder,
            groupName: g.groupName,
            tags: tagDataString2TagDataList(g.tags).map((tagData) => translatedTagDataTable.get(tagData.namespace, tagData.key)!).toList(),
            tagRefreshTime: g.tagRefreshTime,
          ),
        )
        .toList();
    List<ArchiveSearchVO> archives = archiveDownloadService.archives.map((a) {
      return ArchiveSearchVO(
        gid: a.gid,
        token: a.token,
        title: a.title,
        category: a.category,
        pageCount: a.pageCount,
        galleryUrl: a.galleryUrl,
        coverUrl: a.coverUrl,
        uploader: a.uploader,
        size: a.size,
        publishTime: a.publishTime,
        archivePageUrl: a.archivePageUrl,
        downloadPageUrl: a.downloadPageUrl,
        downloadUrl: a.downloadUrl,
        isOriginal: a.isOriginal,
        insertTime: a.insertTime,
        sortOrder: a.sortOrder,
        groupName: a.groupName,
        tags: tagDataString2TagDataList(a.tags).map((tagData) => translatedTagDataTable.get(tagData.namespace, tagData.key)!).toList(),
        tagRefreshTime: a.tagRefreshTime,
      );
    }).toList();

    if (state.searchType == DownloadSearchConfigTypeEnum.regex) {
      RegExp? regExp;
      try {
        regExp = RegExp(value);
      } catch (_) {
        loadingState = LoadingState.success;
        updateSafely([loadingStateId, bodyId]);
        return;
      }

      state.gallerys = gallerys.where((g) {
        if (regExp!.hasMatch(g.title)) {
          return true;
        }
        if (!isEmptyOrNull(g.uploader) && regExp.hasMatch(g.uploader!)) {
          return true;
        }
        for (TagData tagData in g.tags) {
          if (regExp.hasMatch('${tagData.namespace}:${tagData.key}')) {
            return true;
          }
          if (tagData.translatedNamespace != null && tagData.tagName != null && regExp.hasMatch('${tagData.translatedNamespace}:${tagData.tagName}')) {
            return true;
          }
        }
        return false;
      }).toList();
      state.archives = archives.where((a) {
        if (regExp!.hasMatch(a.title)) {
          return true;
        }
        if (!isEmptyOrNull(a.uploader) && regExp.hasMatch(a.uploader!)) {
          return true;
        }
        for (TagData tagData in a.tags) {
          if (regExp.hasMatch('${tagData.namespace}:${tagData.key}')) {
            return true;
          }
          if (tagData.translatedNamespace != null && tagData.tagName != null && regExp.hasMatch('${tagData.translatedNamespace}:${tagData.tagName}')) {
            return true;
          }
        }
        return false;
      }).toList();
    } else {
      state.gallerys = gallerys.where((g) {
        if (g.title.contains(value)) {
          return true;
        }
        if (!isEmptyOrNull(g.uploader) && g.uploader!.contains(value)) {
          return true;
        }
        for (TagData tagData in g.tags) {
          if ('${tagData.namespace}:${tagData.key}'.contains(value)) {
            return true;
          }
          if (tagData.translatedNamespace != null && tagData.tagName != null && '${tagData.translatedNamespace}:${tagData.tagName}'.contains(value)) {
            return true;
          }
        }
        return false;
      }).toList();
      state.archives = archives.where((a) {
        if (a.title.contains(value)) {
          return true;
        }
        if (!isEmptyOrNull(a.uploader) && a.uploader!.contains(value)) {
          return true;
        }
        for (TagData tagData in a.tags) {
          if ('${tagData.namespace}:${tagData.key}'.contains(value)) {
            return true;
          }
          if (tagData.translatedNamespace != null && tagData.tagName != null && '${tagData.translatedNamespace}:${tagData.tagName}'.contains(value)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    loadingState = LoadingState.success;
    updateSafely([loadingStateId, bodyId]);
  }

  void toggleSearchType() {
    state.searchType = state.searchType == DownloadSearchConfigTypeEnum.simple ? DownloadSearchConfigTypeEnum.regex : DownloadSearchConfigTypeEnum.simple;
    updateSafely([searchFieldId]);
    handleSearchFieldChanged(textEditingController.text);
    storageService.write(StorageEnum.downloadSearchPageType.key, state.searchType.code);
  }

  void goToGalleryReadPage(GallerySearchVO gallery) {
    if (!galleryDownloadService.containGallery(gallery.gid)) {
      return;
    }

    if (ReadSetting.useThirdPartyViewer.isTrue && ReadSetting.thirdPartyViewerPath.value != null) {
      openThirdPartyViewer(galleryDownloadService.computeGalleryDownloadAbsolutePath(gallery.title, gallery.gid));
    } else {
      SuperResolutionService superResolutionService = Get.find<SuperResolutionService>();
      String storageKey = 'readIndexRecord::${gallery.gid}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.downloaded,
          gid: gallery.gid,
          token: gallery.token,
          galleryTitle: gallery.title,
          galleryUrl: gallery.galleryUrl,
          initialIndex: readIndexRecord,
          readProgressRecordStorageKey: storageKey,
          pageCount: gallery.pageCount,
          useSuperResolution: superResolutionService.get(gallery.gid, SuperResolutionType.gallery) != null,
        ),
      );
    }
  }

  Future<void> goToArchiveReadPage(ArchiveSearchVO archive) async {
    if (archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus != ArchiveStatus.completed) {
      return;
    }

    if (ReadSetting.useThirdPartyViewer.isTrue && ReadSetting.thirdPartyViewerPath.value != null) {
      openThirdPartyViewer(archiveDownloadService.computeArchiveUnpackingPath(archive.title, archive.gid));
    } else {
      String storageKey = 'readIndexRecord::${archive.gid}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;
      List<GalleryImage> images = await archiveDownloadService.getUnpackedImages(archive.gid);

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.archive,
          gid: archive.gid,
          galleryTitle: archive.title,
          galleryUrl: archive.galleryUrl,
          initialIndex: readIndexRecord,
          pageCount: images.length,
          isOriginal: archive.isOriginal,
          readProgressRecordStorageKey: storageKey,
          images: images,
          useSuperResolution: superResolutionService.get(archive.gid, SuperResolutionType.archive) != null,
        ),
      );
    }
  }
}
