import 'dart:io' as io;
import 'dart:collection';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/locale_consts.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../database/database.dart';
import '../model/gallery.dart';
import '../model/gallery_tag.dart';
import '../setting/style_setting.dart';
import '../utils/log.dart';

class TagTranslationService extends GetxService {
  final StorageService storageService = Get.find();
  final String tagStoragePrefix = 'tagTrans::';
  final String downloadUrl = 'https://cdn.jsdelivr.net/gh/EhTagTranslation/DatabaseReleases/db.html.json';
  final String savePath = join(PathSetting.getVisibleDir().path, 'tag_translation.json');

  Rx<LoadingState> loadingState = LoadingState.idle.obs;
  RxnString timeStamp = RxnString(null);
  RxString downloadProgress = RxString('0 MB');

  static void init() {
    Get.put(TagTranslationService());
    Log.verbose('init TagTranslationService success', false);
  }

  @override
  void onInit() {
    loadingState.value = LoadingState.values[storageService.read('TagTranslationServiceLoadingState') ?? 0];
    timeStamp.value = storageService.read('TagTranslationServiceTimestamp');
    super.onInit();
  }

  Future<void> refresh() async {
    if (StyleSetting.enableTagZHTranslation.isFalse) {
      return;
    }

    if (loadingState.value == LoadingState.loading) {
      return;
    }
    loadingState.value = LoadingState.loading;
    downloadProgress.value = '0 MB';

    List dataList = await _getDataList();
    if (dataList.isEmpty) {
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

    await _clear();
    await _save(tagList);
    storageService.write('TagTranslationServiceLoadingState', LoadingState.success.index);
    storageService.write('TagTranslationServiceTimestamp', timeStamp.value);
    loadingState.value = LoadingState.success;
    Log.info('update tagTranslation database success', false);
    io.File(savePath).delete();
  }

  Future<void> translateGalleryTagsIfNeeded(List<Gallery> gallerys) async {
    if (StyleSetting.enableTagZHTranslation.isTrue && loadingState.value == LoadingState.success) {
      Future.wait(gallerys.map((gallery) {
        return translateTagMap(gallery.tags);
      }).toList());
    }
  }

  Future<void> translateGalleryDetailsTagsIfNeeded(List<GalleryDetail> galleryDetails) async {
    if (StyleSetting.enableTagZHTranslation.isTrue && loadingState.value == LoadingState.success) {
      Future.wait(galleryDetails.map((galleryDetail) {
        return translateTagMap(galleryDetail.fullTags);
      }).toList());
    }
  }

  Future<void> translateGalleryDetailTagsIfNeeded(GalleryDetail galleryDetail) async {
    if (StyleSetting.enableTagZHTranslation.isTrue && loadingState.value == LoadingState.success) {
      await translateTagMap(galleryDetail.fullTags);
    }
  }

  Future<TagData?> getTagTranslation(String namespace, String key) async {
    List<TagData> list = await appDb.selectTagByNamespaceAndKey(namespace, key).get();
    return list.isNotEmpty ? list.first : null;
  }

  Future<List<TagData>> searchTags(String keyword) async {
    return await appDb.searchTags('%$keyword%').get();
  }

  /// won't translate keys
  Future<void> translateTagMap(LinkedHashMap<String, List<GalleryTag>> tags) async {
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

  Future<List> _getDataList() async {
    try {
      await retry(
        () async {
          await EHRequest.download(
              url: downloadUrl,
              path: savePath,
              options: Options(receiveTimeout: 30000),
              onReceiveProgress: (count, total) {
                downloadProgress.value = (count / 1024 / 1024).toStringAsFixed(2) + ' MB';
              });
        },
        maxAttempts: 5,
        onRetry: (error) => Log.warning('download tag translation data failed, retry.', false),
      );
    } on DioError catch (e) {
      Log.error('download tag translation data failed after 3 times', e.message);
      loadingState.value = LoadingState.error;
      return [];
    }

    String json = io.File(savePath).readAsStringSync();
    Map dataMap = jsonDecode(json);

    Map head = dataMap['head'] as Map;
    Map committer = head['committer'] as Map;
    timeStamp.value = committer['when'] as String;

    List dataList = dataMap['data'] as List;

    Log.info('tag translation data downloaded, legnth: ${dataList.length}', false);
    return dataList;
  }

  Future<void> _save(List<TagData> list) async {
    return appDb.transaction(() async {
      for (TagData tag in list) {
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
  }

  Future<int> _clear() async {
    return appDb.deleteAllTags();
  }
}
