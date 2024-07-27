import 'dart:io' as io;
import 'dart:collection';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/dao/tag_count_dao.dart';
import 'package:jhentai/src/database/dao/tag_dao.dart';
import 'package:jhentai/src/enum/eh_namespace.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/tag_search_order_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../database/database.dart';
import '../enum/config_enum.dart';
import '../model/gallery_tag.dart';
import 'jh_service.dart';
import 'log.dart';

typedef TagAutoCompletionMatch = ({
  String searchText,
  int matchStart,
  int matchEnd,
  TagData tagData,
  ({int start, int end})? namespaceMatch,
  ({int start, int end})? translatedNamespaceMatch,
  ({int start, int end})? keyMatch,
  ({int start, int end})? tagNameMatch,
  double score,
});

TagTranslationService tagTranslationService = TagTranslationService();

class TagTranslationService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  final String downloadUrl = 'https://fastly.jsdelivr.net/gh/EhTagTranslation/DatabaseReleases/db.html.json';
  late final String savePath;

  Rx<LoadingState> loadingState = LoadingState.idle.obs;
  RxnString timeStamp = RxnString(null);
  RxString downloadProgress = RxString('0 MB');

  bool get isReady => preferenceSetting.enableTagZHTranslation.isTrue && (loadingState.value == LoadingState.success || timeStamp.value != null);

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..add(localConfigService);

  @override
  Future<void> doOnInit() async {
    savePath = join(pathService.getVisibleDir().path, 'tag_translation.json');

    localConfigService
        .read(configKey: ConfigEnum.tagTranslationServiceLoadingState)
        .then((value) => loadingState.value = LoadingState.values[value != null ? int.parse(value) : 0]);

    localConfigService.read(configKey: ConfigEnum.tagTranslationServiceTimestamp).then((value) => timeStamp.value = value);
  }

  @override
  void doOnReady() {
    if (isReady) {
      fetchDataFromGithub();
    }
  }

  Future<void> fetchDataFromGithub() async {
    if (preferenceSetting.enableTagZHTranslation.isFalse) {
      return;
    }
    if (loadingState.value == LoadingState.loading) {
      return;
    }

    log.info('Fetch tag translation data from github');

    loadingState.value = LoadingState.loading;
    downloadProgress.value = '0 MB';

    /// download translation metadata
    try {
      await retry(
        () => ehRequest.download(
          url: downloadUrl,
          path: savePath,
          receiveTimeout: 10 * 60 * 1000,
          onReceiveProgress: (count, total) => downloadProgress.value = (count / 1024 / 1024).toStringAsFixed(2) + ' MB',
        ),
        maxAttempts: 5,
        onRetry: (error) => log.warning('Download tag translation data failed, retry.'),
      );
    } on DioException catch (e) {
      log.error('Download tag translation data failed after 5 times', e.errorMsg);
      loadingState.value = LoadingState.error;
      await localConfigService.write(configKey: ConfigEnum.tagTranslationServiceLoadingState, value: loadingState.value.index.toString());
      return;
    }

    log.info('Tag translation data downloaded');

    /// format
    String json = io.File(savePath).readAsStringSync();
    Map dataMap = jsonDecode(json);
    Map head = dataMap['head'] as Map;
    Map committer = head['committer'] as Map;
    String newTimeStamp = committer['when'] as String;
    List dataList = dataMap['data'] as List;

    if (newTimeStamp == timeStamp.value) {
      log.info('Tag translation data is up to date, timestamp: $timeStamp');
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
          translatedNamespace: EHNamespace.findNameSpaceFromDescOrAbbr(namespace)?.chineseDesc,
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
      await TagDao.deleteAllTags();
      for (TagData tag in tagList) {
        await TagDao.insertTag(
          TagData(
            namespace: tag.namespace,
            key: tag.key,
            translatedNamespace: tag.translatedNamespace,
            tagName: tag.tagName,
            fullTagName: tag.fullTagName,
            intro: tag.intro,
            links: tag.links,
          ),
        );
      }
    });

    timeStamp.value = newTimeStamp;
    loadingState.value = LoadingState.success;

    await localConfigService.write(configKey: ConfigEnum.tagTranslationServiceLoadingState, value: loadingState.value.index.toString());
    await localConfigService.write(configKey: ConfigEnum.tagTranslationServiceTimestamp, value: newTimeStamp);

    io.File(savePath).delete();
    log.info('Update tag translation database success, timestamp: $timeStamp');
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

  Future<List<TagData>> translateTagDatasIfNeeded(List<TagData> tags) async {
    if (!isReady) {
      return [];
    }

    List<Future<TagData>> futures = tags.map((tag) => getTagTranslation(tag.namespace, tag.key).then((value) => value ?? tag)).toList();
    List<TagData> translatedTagDatas = await Future.wait(futures);
    return translatedTagDatas.toList();
  }

  Future<TagData?> getTagTranslation(String namespace, String key) async {
    List<TagData> list = await TagDao.selectTagByNamespaceAndKey(namespace, key);
    return list.isNotEmpty ? list.first : null;
  }

  Future<List<TagAutoCompletionMatch>> searchTags(String searchText, {int? limit}) async {
    // xy:"ab cd ef"    xy:"ab cd ef...       (\S+?):"[-~]?([^"\s]+)"?
    // "ab cd ef"       "ab cd ef...          "[-~]?([^"\s]+)"?
    // xy:ab                                  (\S+?):[-~]?(\S+)
    // abcd                                   [-~]?(\S+)
    List<RegExpMatch> matches = RegExp(r'(\S+?):"[-~]?([^"]+)"?|"[-~]?([^"]+)"?|(\S+?):[-~]?(\S+)|[-~]?(\S+)').allMatches(searchText.toLowerCase()).toList();
    if (matches.isEmpty) {
      return [];
    }

    List<TagAutoCompletionMatch> results = [];

    List<({String? sNamespace, String sKey, int matchStart, int matchEnd})> searchList = matches.map((match) {
      int matchStart = match.start;
      int matchEnd = match.end;
      String? sNamespace = match.group(1) ?? match.group(4);
      String sKey = match.group(2) ?? match.group(3) ?? match.group(5) ?? match.group(0)!;
      return (sNamespace: sNamespace, sKey: sKey, matchStart: matchStart, matchEnd: matchEnd);
    }).toList();

    for (int i = 0; i < searchList.length; i++) {
      String searchTextMerged = searchList.sublist(i).map((e) => e.sNamespace != null ? '${e.sNamespace}:${e.sKey}' : e.sKey).join(' ');
      int colonIndex = searchTextMerged.indexOf(':');
      String? sNameSpaceMerged = colonIndex != -1 ? searchTextMerged.substring(0, colonIndex) : null;
      if (EHNamespace.findNameSpaceFromDescOrAbbr(sNameSpaceMerged) != null) {
        sNameSpaceMerged = EHNamespace.findNameSpaceFromDescOrAbbr(sNameSpaceMerged)!.desc;
      }
      String sKeyMerged = searchTextMerged.substring(colonIndex + 1);

      if (sKeyMerged.length <= 1 && GetUtils.hasMatch(sKeyMerged, r'^\w+$')) {
        continue;
      }

      List<TagAutoCompletionMatch> matches = [];
      if (tagSearchOrderOptimizationService.isReady) {
        List<TagData> tagDatas =
            sNameSpaceMerged != null ? await TagDao.searchFullTags(sNameSpaceMerged, '%$sKeyMerged%') : await TagDao.searchTags('%$sKeyMerged%');
        matches = await _markTagDatasByFrequency(searchText, searchList[i].matchStart, searchList[i].matchEnd, sNameSpaceMerged, sKeyMerged, tagDatas);
      } else {
        List<TagData> tagDatas = sNameSpaceMerged != null
            ? await TagDao.searchFullTagsIncludeIntro(sNameSpaceMerged, '%$sKeyMerged%')
            : await TagDao.searchTagsIncludeIntro('%$sKeyMerged%');
        matches = await _markTagDatasByScore(searchText, searchList[i].matchStart, searchList[i].matchEnd, sNameSpaceMerged, sKeyMerged, tagDatas);
      }

      matches.removeWhere((match) => results.any((result) => result.tagData == match.tagData));
      matches.sort((a, b) {
        return b.score.compareTo(a.score);
      });
      results.addAll(matches);
    }

    return limit == null ? results : results.take(limit).toList();
  }

  Future<List<TagAutoCompletionMatch>> _markTagDatasByFrequency(
      String searchText, int matchStart, int matchEnd, String? sNamespace, String sKey, List<TagData> tagDatas) async {
    List<String> namespaceWithKeys = tagDatas.map((tag) => '${tag.namespace}:${tag.key}').toList();
    List<TagCountData> tagCountDatas = await TagCountDao.batchSelectTagCount(namespaceWithKeys);

    Map<TagData, int> tagCountMap = tagDatas.fold({}, (Map<TagData, int> map, tag) {
      map[tag] = tagCountDatas.firstWhereOrNull((tagCount) => tagCount.namespaceWithKey == '${tag.namespace}:${tag.key}')?.count ?? 0;
      return map;
    });

    return tagDatas.map((tagData) {
      int keyIndex = tagData.key.indexOf(sKey.toLowerCase());
      int tagNameIndex = tagData.tagName?.indexOf(sKey.toLowerCase()) ?? -1;
      return (
        searchText: searchText,
        matchStart: matchStart,
        matchEnd: matchEnd,
        tagData: tagData,
        score: tagCountMap[tagData]!.toDouble(),
        namespaceMatch: sNamespace != null ? (start: 0, end: tagData.namespace.length) : null,
        translatedNamespaceMatch: sNamespace != null ? (start: 0, end: tagData.translatedNamespace!.length) : null,
        keyMatch: keyIndex != -1 ? (start: keyIndex, end: keyIndex + sKey.length) : null,
        tagNameMatch: tagNameIndex != -1 ? (start: tagNameIndex, end: tagNameIndex + sKey.length) : null
      );
    }).toList();
  }

  /// https://github.com/EhTagTranslation/EhSyringe/blob/15a8ec2a8e52d8730099ec2193cf66bb0a2721ca/src/plugin/suggest.ts#L57
  Future<List<TagAutoCompletionMatch>> _markTagDatasByScore(
      String searchText, int matchStart, int matchEnd, String? sNamespace, String sKey, List<TagData> tagDatas) async {
    Map<EHNamespace, double> namespaceScoreMap = {
      EHNamespace.other: 10,
      EHNamespace.female: 9,
      EHNamespace.male: 8.5,
      EHNamespace.mixed: 8,
      EHNamespace.parody: 3.3,
      EHNamespace.character: 2.8,
      EHNamespace.artist: 2.5,
      EHNamespace.cosplayer: 2.4,
      EHNamespace.group: 2.2,
      EHNamespace.language: 2,
      EHNamespace.reclass: 1,
      EHNamespace.temp: 0.1,
      EHNamespace.rows: 0,
    };

    return tagDatas.map((tagData) {
      double score = 0;

      int keyIndex = tagData.key.indexOf(sKey.toLowerCase());
      if (keyIndex != -1) {
        score +=
            namespaceScoreMap[EHNamespace.findNameSpaceFromDescOrAbbr(tagData.namespace)]! * (sKey.length + 1) / tagData.key.length * (keyIndex == 0 ? 2 : 1);
      }

      int tagNameIndex = tagData.tagName?.indexOf(sKey) ?? -1;
      if (tagNameIndex != -1) {
        score += namespaceScoreMap[EHNamespace.findNameSpaceFromDescOrAbbr(tagData.namespace)]! *
            (sKey.length + 1) /
            tagData.tagName!.length *
            (tagNameIndex == 0 ? 2 : 1);
      }

      bool introContains = tagData.intro?.contains(sKey.toLowerCase()) ?? false;
      if (introContains) {
        score += namespaceScoreMap[EHNamespace.findNameSpaceFromDescOrAbbr(tagData.namespace)]! * (sKey.length + 1) / tagData.intro!.length * 0.5;
      }

      return (
        searchText: searchText,
        matchStart: matchStart,
        matchEnd: matchEnd,
        tagData: tagData,
        score: score,
        namespaceMatch: sNamespace != null ? (start: 0, end: tagData.namespace.length) : null,
        translatedNamespaceMatch: sNamespace != null ? (start: 0, end: tagData.translatedNamespace!.length) : null,
        keyMatch: keyIndex != -1 ? (start: keyIndex, end: keyIndex + sKey.length) : null,
        tagNameMatch: tagNameIndex != -1 ? (start: tagNameIndex, end: tagNameIndex + sKey.length) : null,
      );
    }).toList();
  }
}
