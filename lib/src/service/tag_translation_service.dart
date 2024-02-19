import 'dart:io' as io;
import 'dart:collection';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/locale_consts.dart';
import 'package:jhentai/src/database/dao/tag_count_dao.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_search_order_service.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../database/database.dart';
import '../model/gallery.dart';
import '../model/gallery_tag.dart';
import '../utils/log.dart';

class TagTranslationService extends GetxService {
  final StorageService storageService = Get.find();
  final String tagStoragePrefix = 'tagTrans::';
  final String downloadUrl = 'https://fastly.jsdelivr.net/gh/EhTagTranslation/DatabaseReleases/db.html.json';
  final String savePath = join(PathSetting.getVisibleDir().path, 'tag_translation.json');

  Rx<LoadingState> loadingState = LoadingState.idle.obs;
  RxnString timeStamp = RxnString(null);
  RxString downloadProgress = RxString('0 MB');

  bool get isReady => PreferenceSetting.enableTagZHTranslation.isTrue && (loadingState.value == LoadingState.success || timeStamp.value != null);

  static void init() {
    Get.put(TagTranslationService());
    Log.debug('init TagTranslationService success', false);
  }

  @override
  void onInit() {
    super.onInit();

    loadingState.value = LoadingState.values[storageService.read('TagTranslationServiceLoadingState') ?? 0];
    timeStamp.value = storageService.read('TagTranslationServiceTimestamp');
    if (isReady) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (PreferenceSetting.enableTagZHTranslation.isFalse) {
      return;
    }
    if (loadingState.value == LoadingState.loading) {
      return;
    }

    Log.info('Refresh tag translation data');

    loadingState.value = LoadingState.loading;
    downloadProgress.value = '0 MB';

    /// download translation metadata
    try {
      await retry(
        () => EHRequest.download(
          url: downloadUrl,
          path: savePath,
          receiveTimeout: 10 * 60 * 1000,
          onReceiveProgress: (count, total) => downloadProgress.value = (count / 1024 / 1024).toStringAsFixed(2) + ' MB',
        ),
        maxAttempts: 5,
        onRetry: (error) => Log.warning('Download tag translation data failed, retry.'),
      );
    } on DioException catch (e) {
      Log.error('Download tag translation data failed after 5 times', e.message);
      loadingState.value = LoadingState.error;
      storageService.write('TagTranslationServiceLoadingState', LoadingState.error.index);
      return;
    }

    Log.info('Tag translation data downloaded');

    /// format
    String json = io.File(savePath).readAsStringSync();
    Map dataMap = jsonDecode(json);
    Map head = dataMap['head'] as Map;
    Map committer = head['committer'] as Map;
    String newTimeStamp = committer['when'] as String;
    List dataList = dataMap['data'] as List;

    if (newTimeStamp == timeStamp.value) {
      Log.info('Tag translation data is up to date, timestamp: $timeStamp');
      loadingState.value = LoadingState.success;
      io.File(savePath).delete();
      return;
    }

    List<TagData> tagList = [];
    for (final data in dataList) {
      String namespace = data['namespace'];
      Map tags = data['data'] as Map;
      tags.forEach((key, value) {
        String _key = key as String;
        String tagName = RegExp(r'.*>(.+)<.*').firstMatch((value['name']))!.group(1)!;
        String fullTagName = value['name'];
        String intro = value['intro'];
        String links = value['links'];
        tagList.add(TagData(
          namespace: namespace,
          key: _key,
          translatedNamespace: LocaleConsts.tagNamespace[namespace],
          tagName: tagName,
          fullTagName: fullTagName,
          intro: intro,
          links: links,
        ));
      });
    }

    /// save
    timeStamp.value = null;
    await appDb.transaction(() async {
      await appDb.deleteAllTags();
      for (TagData tag in tagList) {
        await appDb.insertTag(
          tag.namespace,
          tag.key,
          tag.translatedNamespace,
          tag.tagName,
          tag.fullTagName,
          tag.intro,
          tag.links,
        );
      }
    });
    timeStamp.value = newTimeStamp;

    storageService.write('TagTranslationServiceLoadingState', LoadingState.success.index);
    storageService.write('TagTranslationServiceTimestamp', timeStamp.value);

    loadingState.value = LoadingState.success;
    io.File(savePath).delete();
    Log.info('Update tag translation database success, timestamp: $timeStamp');
  }

  /// won't translate keys
  Future<void> translateTagsIfNeeded(LinkedHashMap<String, List<GalleryTag>> tags) async {
    if (!isReady) {
      return;
    }

    List<Future> futures = [];

    tags.forEach((namespace, tags) {
      for (GalleryTag tag in tags) {
        futures.add(
          getTagTranslation(namespace, tag.tagData.key).then((TagData? value) => tag.tagData = value ?? tag.tagData),
        );
      }
    });

    await Future.wait(futures);
  }

  Future<TagData?> getTagTranslation(String namespace, String key) async {
    List<TagData> list = await appDb.selectTagByNamespaceAndKey(namespace, key).get();
    return list.isNotEmpty ? list.first : null;
  }

  Future<List<TagData>> searchTags(String keyword) async {
    List<TagData> tagDatas = await appDb.searchTags('%$keyword%').get();
    tagDatas = tagDatas.where((tag) => tag.namespace != 'rows' && tag.namespace != 'reclass').toList();

    TagSearchOrderOptimizationService tagSearchOrderOptimizationService = Get.find();
    if (!tagSearchOrderOptimizationService.isReady) {
      return tagDatas;
    }

    List<String> namespaceWithKeys = tagDatas.map((tag) => '${tag.namespace}:${tag.key}').toList();
    List<TagCountData> tagCountDatas = await TagCountDao.batchSelectTagCount(namespaceWithKeys);

    Map<TagData, int> tagCountMap = tagDatas.fold({}, (Map<TagData, int> map, tag) {
      map[tag] = tagCountDatas.firstWhereOrNull((tagCount) => tagCount.namespaceWithKey == '${tag.namespace}:${tag.key}')?.count ?? 0;
      return map;
    });

    tagDatas.sort((a, b) {
      return tagCountMap[b]! - tagCountMap[a]!;
    });

    return tagDatas;
  }
}
