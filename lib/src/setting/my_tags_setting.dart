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
import '../service/jh_service.dart';
import '../utils/eh_spider_parser.dart';
import '../service/log.dart';

MyTagsSetting myTagsSetting = MyTagsSetting();

class MyTagsSetting with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  Map<int, ({bool enable, Color? tagSetBackGroundColor, List<WatchedTag> tags})> onlineTags = {};

  static const int defaultTagSetNo = 1;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..add(userSetting);

  @override
  Future<void> doInitBean() async {
    /// listen to login and logout
    ever(userSetting.ipbMemberId, (v) {
      if (userSetting.hasLoggedIn()) {
        refreshAllOnlineTagSets();
      } else {
        _clearOnlineTagSets();
      }
    });
  }

  @override
  Future<void> doAfterBeanReady() async {
    refreshAllOnlineTagSets();
  }

  Future<void> refreshAllOnlineTagSets() async {
    if (!userSetting.hasLoggedIn()) {
      return;
    }

    log.info('refresh MyTagsSetting');

    ({List<({int number, String name})> tagSets, bool tagSetEnable, Color? tagSetBackgroundColor, List<WatchedTag> tags, String apikey}) defaultTagSetPageInfo;
    try {
      defaultTagSetPageInfo = await retry(
        () => ehRequest.requestMyTagsPage(tagSetNo: defaultTagSetNo, parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey),
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

  Future<void> refreshOnlineTagSets(int tagSetNo) async {
    if (!userSetting.hasLoggedIn()) {
      return;
    }

    log.info('refreshOnlineTagSets tagSetNo: $tagSetNo');

    ({List<({int number, String name})> tagSets, bool tagSetEnable, Color? tagSetBackgroundColor, List<WatchedTag> tags, String apikey}) pageInfo;
    try {
      pageInfo = await retry(
        () => ehRequest.requestMyTagsPage(tagSetNo: tagSetNo, parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey),
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

  ({Color? tagSetBackGroundColor, WatchedTag tag})? getOnlineTagSetByTagData(TagData tagData) {
    for (({bool enable, Color? tagSetBackGroundColor, List<WatchedTag> tags}) tagSetInfo in onlineTags.values) {
      WatchedTag? tagSet = tagSetInfo.tags.firstWhereOrNull((tagSet) => tagSet.tagData.namespace == tagData.namespace && tagSet.tagData.key == tagData.key);
      if (tagSet != null) {
        return (tagSetBackGroundColor: tagSetInfo.tagSetBackGroundColor, tag: tagSet);
      }
    }

    return null;
  }

  bool containWatchedOnlineTag(TagData tagData) {
    ({Color? tagSetBackGroundColor, WatchedTag tag})? tagInfo = getOnlineTagSetByTagData(tagData);
    return tagInfo?.tag.watched == true;
  }

  bool containHiddenOnlineTag(TagData tagData) {
    ({Color? tagSetBackGroundColor, WatchedTag tag})? tagInfo = getOnlineTagSetByTagData(tagData);
    return tagInfo?.tag.hidden == true;
  }

  Future<void> _clearOnlineTagSets() async {
    onlineTags.clear();
    log.debug('clear MyTagsSetting success');
  }
}
