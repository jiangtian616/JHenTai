import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:retry/retry.dart';

import '../exception/eh_site_exception.dart';
import '../model/tag_set.dart';
import '../network/eh_request.dart';
import '../service/storage_service.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';

class MyTagsSetting {
  static Map<int, ({bool enable, Color? tagSetBackGroundColor, List<WatchedTag> tags})> onlineTags = {};
  static List<TagData> localTagSets = [];

  static const int defaultTagSetNo = 1;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('MyTagsSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init MyTagsSetting success');
    } else {
      Log.debug('init MyTagsSetting success: default');
    }

    /// listen to login and logout
    ever(UserSetting.ipbMemberId, (v) {
      if (UserSetting.hasLoggedIn()) {
        refreshAllOnlineTagSets();
      } else {
        _clearOnlineTagSets();
      }
    });
  }

  static Future<void> refreshAllOnlineTagSets() async {
    if (!UserSetting.hasLoggedIn()) {
      return;
    }

    Log.info('refresh MyTagsSetting');

    ({List<({int number, String name})> tagSets, bool tagSetEnable, Color? tagSetBackgroundColor, List<WatchedTag> tags, String apikey}) defaultTagSetPageInfo;
    try {
      defaultTagSetPageInfo = await retry(
        () => EHRequest.requestMyTagsPage(tagSetNo: defaultTagSetNo, parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey),
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } on DioException catch (e) {
      Log.error('getTagSetFailed'.tr, e.errorMsg);
      return;
    } on EHSiteException catch (e) {
      Log.error('getTagSetFailed'.tr, e.message);
      return;
    }

    onlineTags[defaultTagSetNo] = (
      enable: defaultTagSetPageInfo.tagSetEnable,
      tagSetBackGroundColor: defaultTagSetPageInfo.tagSetBackgroundColor,
      tags: defaultTagSetPageInfo.tags,
    );
    Log.info('refresh default tag set success, length: ${onlineTags[defaultTagSetNo]!.tags.length}');

    /// fetch all tag sets
    for (({int number, String name}) tagSet in defaultTagSetPageInfo.tagSets) {
      if (tagSet.number == defaultTagSetNo) {
        continue;
      }
      refreshOnlineTagSets(tagSet.number);
    }
  }

  static Future<void> refreshOnlineTagSets(int tagSetNo) async {
    if (!UserSetting.hasLoggedIn()) {
      return;
    }

    Log.info('refreshOnlineTagSets tagSetNo: $tagSetNo');

    ({List<({int number, String name})> tagSets, bool tagSetEnable, Color? tagSetBackgroundColor, List<WatchedTag> tags, String apikey}) pageInfo;
    try {
      pageInfo = await retry(
        () => EHRequest.requestMyTagsPage(tagSetNo: tagSetNo, parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey),
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } on DioException catch (e) {
      Log.error('getTagSetFailed'.tr, e.errorMsg);
      return;
    } on EHSiteException catch (e) {
      Log.error('getTagSetFailed'.tr, e.message);
      return;
    }

    onlineTags[tagSetNo] = (
      enable: pageInfo.tagSetEnable,
      tagSetBackGroundColor: pageInfo.tagSetBackgroundColor,
      tags: pageInfo.tags,
    );
    Log.info('refresh tag set: $tagSetNo success, length: ${onlineTags[tagSetNo]!.tags.length}');
  }

  static ({Color? tagSetBackGroundColor, WatchedTag tag})? getOnlineTagSetByTagData(TagData tagData) {
    for (({bool enable, Color? tagSetBackGroundColor, List<WatchedTag> tags}) tagSetInfo in onlineTags.values) {
      WatchedTag? tagSet = tagSetInfo.tags.firstWhereOrNull((tagSet) => tagSet.tagData.namespace == tagData.namespace && tagSet.tagData.key == tagData.key);
      if (tagSet != null) {
        return (tagSetBackGroundColor: tagSetInfo.tagSetBackGroundColor, tag: tagSet);
      }
    }

    return null;
  }

  static bool containWatchedOnlineLocalTag(TagData tagData) {
    ({Color? tagSetBackGroundColor, WatchedTag tag})? tagInfo = getOnlineTagSetByTagData(tagData);
    return tagInfo?.tag.watched == true;
  }

  static bool containHiddenOnlineLocalTag(TagData tagData) {
    ({Color? tagSetBackGroundColor, WatchedTag tag})? tagInfo = getOnlineTagSetByTagData(tagData);
    return tagInfo?.tag.hidden == true;
  }

  static bool containLocalTag(TagData tagData) {
    return localTagSets.any((localTag) => localTag.namespace == tagData.namespace && localTag.key == tagData.key);
  }

  static void addLocalTagSet(TagData tagData) {
    Log.debug('addLocalTagSet:$tagData');
    localTagSets.add(tagData);
    _saveLocalTagSets();
  }

  static void removeLocalTagSetByIndex(int index) {
    Log.debug('removeLocalTagSetByIndex:$index');
    localTagSets.removeAt(index);
    _saveLocalTagSets();
  }

  static void removeLocalTagSet(TagData tagData) {
    Log.debug('removeLocalTagSet:$tagData');
    localTagSets.remove(tagData);
    _saveLocalTagSets();
  }

  static Future<void> _clearOnlineTagSets() async {
    onlineTags.clear();
    Log.info('clear MyTagsSetting success');
  }

  static Future<void> _saveLocalTagSets() async {
    await Get.find<StorageService>().write('MyTagsSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'localTagSets': localTagSets,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    if (map['localTagSets'] == null) {
      return;
    }

    localTagSets = (map['localTagSets'] as List).map((e) => TagData.fromJson(e)).toList();
  }
}
