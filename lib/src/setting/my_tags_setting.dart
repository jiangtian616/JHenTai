import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:retry/retry.dart';

import '../exception/eh_exception.dart';
import '../model/tag_set.dart';
import '../network/eh_request.dart';
import '../service/storage_service.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';

class MyTagsSetting {
  static List<TagSet> onlineTagSets = [];
  static List<TagData> localTagSets = [];

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
        refreshOnlineTagSets();
      } else {
        _clearOnlineTagSets();
      }
    });
  }

  static Future<void> refreshOnlineTagSets() async {
    if (!UserSetting.hasLoggedIn()) {
      return;
    }

    Log.info('refresh MyTagsSetting');

    Map<String, dynamic> map;
    try {
      map = await retry(
        () => EHRequest.requestMyTagsPage(
          tagSetNo: 1,
          parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey,
        ),
        retryIf: (e) => e is DioError,
        maxAttempts: 3,
      );
    } on DioError catch (e) {
      Log.error('getTagSetFailed'.tr, e.message);
      return;
    } on EHException catch (e) {
      Log.error('getTagSetFailed'.tr, e.message);
      return;
    }

    onlineTagSets = map['tagSets'] ?? onlineTagSets;

    Log.info('refresh MyTagsSetting success, length: ${onlineTagSets.length}');
  }

  static TagSet? getOnlineTagSetByTagData(TagData tagData) {
    return onlineTagSets.firstWhereOrNull((tagSet) => tagSet.tagData.namespace == tagData.namespace && tagSet.tagData.key == tagData.key);
  }

  static bool containWatchedOnlineLocalTag(TagData tagData) {
    TagSet? tagSet = getOnlineTagSetByTagData(tagData);
    return tagSet?.watched == true;
  }

  static bool containHiddenOnlineLocalTag(TagData tagData) {
    TagSet? tagSet = getOnlineTagSetByTagData(tagData);
    return tagSet?.hidden == true;
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
    onlineTagSets.clear();
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
