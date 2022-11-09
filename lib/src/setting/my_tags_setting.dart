import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/setting/user_setting.dart';

import '../model/tag_set.dart';
import '../network/eh_request.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';

class MyTagsSetting {
  static List<TagSet> tagSets = [];

  static void init() {
    /// listen to login and logout
    ever(UserSetting.ipbMemberId, (v) {
      if (UserSetting.hasLoggedIn()) {
        refresh();
      } else {
        _clear();
      }
    });
  }

  static Future<void> refresh() async {
    if (!UserSetting.hasLoggedIn()) {
      return;
    }

    Log.info('refresh MyTagsSetting');

    Map<String, dynamic> map;
    try {
      map = await EHRequest.requestMyTagsPage(
        tagSetNo: 1,
        parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey,
      );
    } on DioError catch (e) {
      Log.error('getTagSetFailed'.tr, e.message);
      return;
    }

    tagSets = map['tagSets'];

    Log.info('refresh MyTagsSetting success, length: ${tagSets.length}');
  }

  static TagSet? getTagSetByTagData(TagData tagData) {
    return tagSets.firstWhereOrNull((tagSet) => tagSet.tagData.namespace == tagData.namespace && tagSet.tagData.key == tagData.key);
  }

  static Future<void> _clear() async {
    tagSets.clear();
    Log.info('clear MyTagsSetting success');
  }
}
