import 'dart:collection';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../database/database.dart';
import '../utils/log.dart';

class TagTranslationService extends GetxService {
  final StorageService storageService = Get.find();
  final String tagStoragePrefix = 'tagTrans::';
  final String downloadUrl = 'https://cdn.jsdelivr.net/gh/EhTagTranslation/DatabaseReleases/db.html.json';
  final String savePath = join(PathSetting.getVisiblePath().path, 'tag_translation.json');

  bool hasData = false;
  RxnString timeStamp = RxnString(null);

  static void init() {
    Get.put(TagTranslationService());
    Log.info('init TagTranslationService success', false);
  }

  void onInit() {
    hasData = storageService.read('TagTranslationServiceHasData') ?? false;
    timeStamp.value = storageService.read('TagTranslationServiceTimestamp');
    super.onInit();
  }

  Future<void> updateDatabase() async {
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
        String intro = value['intro'];
        String links = value['links'];
        tagList.add(TagData(namespace: namespace, key: _key, tagName: tagName, intro: intro, links: links));
      });
    }

    await _clear();
    await _save(tagList);
    storageService.write('TagTranslationServiceHasData', true);
    storageService.write('TagTranslationServiceTimestamp', timeStamp.value);
    hasData = true;
    Log.info('update tagTranslation database success', false);
    File(savePath).delete();
  }

  Future<TagData?> getTagTranslation(String key, [String? namespace]) async {
    if (namespace == null) {
      List<TagData> list = (await appDb.selectTagsByKey(key).get());
      return list.isNotEmpty ? list.first : null;
    }
    List<TagData> list = (await appDb.selectTagByNamespaceAndKey(namespace, key).get());
    return list.isNotEmpty ? list.first : null;
  }

  Future<LinkedHashMap<String, List<String>>> getTagMapTranslation(LinkedHashMap<String, List<String>> tags) async {
    LinkedHashMap<String, List<String>> translatedTags = LinkedHashMap();

    Iterator iterator = tags.entries.iterator;
    while (iterator.moveNext()) {
      MapEntry<String, List<String>> entry = iterator.current;
      String namespace = entry.key;
      List<String> tagNames = entry.value;

      String newCategory = (await getTagTranslation(namespace, 'rows'))?.tagName ?? namespace;
      List<String> newTagNames = [];
      for (String tagName in tagNames) {
        newTagNames.add((await getTagTranslation(tagName, namespace))?.tagName ?? tagName);
      }
      translatedTags[newCategory] = newTagNames;
    }
    return translatedTags;
  }

  Future<List> _getDataList() async {
    try {
      await retry(
        () async {
          await EHRequest.download(
            url: downloadUrl,
            path: savePath,
            options: Options(receiveTimeout: 30000),
          );
        },
        maxAttempts: 5,
        onRetry: (error) => Log.warning('download tag translation data failed, retry.', false),
      );
    } on DioError catch (e) {
      Log.error('download tag translation data failed after 3 times', e.message);
      return [];
    }

    String json = File(savePath).readAsStringSync();
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
          tag.tagName,
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
