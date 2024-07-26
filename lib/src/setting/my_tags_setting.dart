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
import '../utils/eh_spider_parser.dart';
import '../service/log.dart';

class MyTagsSetting {
  static Map<int, ({bool enable, Color? tagSetBackGroundColor, List<WatchedTag> tags})> onlineTags = {};

  static const int defaultTagSetNo = 1;

  static void init() {
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

    log.info('refresh MyTagsSetting');

    ({List<({int number, String name})> tagSets, bool tagSetEnable, Color? tagSetBackgroundColor, List<WatchedTag> tags, String apikey}) defaultTagSetPageInfo;
    try {
      defaultTagSetPageInfo = await retry(
        () => EHRequest.requestMyTagsPage(tagSetNo: defaultTagSetNo, parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey),
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } on DioException catch (e) {
      log.error('getTagSetFailed'.tr, e.errorMsg);
      return;
    } on EHSiteException catch (e) {
      log.error('getTagSetFailed'.tr, e.message);
      return;
    }

    onlineTags[defaultTagSetNo] = (
      enable: defaultTagSetPageInfo.tagSetEnable,
      tagSetBackGroundColor: defaultTagSetPageInfo.tagSetBackgroundColor,
      tags: defaultTagSetPageInfo.tags,
    );
    log.info('refresh default tag set success, length: ${onlineTags[defaultTagSetNo]!.tags.length}');

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

    log.info('refreshOnlineTagSets tagSetNo: $tagSetNo');

    ({List<({int number, String name})> tagSets, bool tagSetEnable, Color? tagSetBackgroundColor, List<WatchedTag> tags, String apikey}) pageInfo;
    try {
      pageInfo = await retry(
        () => EHRequest.requestMyTagsPage(tagSetNo: tagSetNo, parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey),
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } on DioException catch (e) {
      log.error('getTagSetFailed'.tr, e.errorMsg);
      return;
    } on EHSiteException catch (e) {
      log.error('getTagSetFailed'.tr, e.message);
      return;
    }

    onlineTags[tagSetNo] = (
      enable: pageInfo.tagSetEnable,
      tagSetBackGroundColor: pageInfo.tagSetBackgroundColor,
      tags: pageInfo.tags,
    );
    log.info('refresh tag set: $tagSetNo success, length: ${onlineTags[tagSetNo]!.tags.length}');
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

  static bool containWatchedOnlineTag(TagData tagData) {
    ({Color? tagSetBackGroundColor, WatchedTag tag})? tagInfo = getOnlineTagSetByTagData(tagData);
    return tagInfo?.tag.watched == true;
  }

  static bool containHiddenOnlineTag(TagData tagData) {
    ({Color? tagSetBackGroundColor, WatchedTag tag})? tagInfo = getOnlineTagSetByTagData(tagData);
    return tagInfo?.tag.hidden == true;
  }

  static Future<void> _clearOnlineTagSets() async {
    onlineTags.clear();
    log.info('clear MyTagsSetting success');
  }
}
