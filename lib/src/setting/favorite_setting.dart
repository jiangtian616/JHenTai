import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';

class FavoriteSetting {
  static List<String>? favoriteTagNames;
  static LinkedHashMap<String, int>? favoriteTagNames2Count;

  static bool get inited =>
      favoriteTagNames2Count != null &&
      favoriteTagNames2Count!.isNotEmpty &&
      favoriteTagNames != null &&
      favoriteTagNames!.isNotEmpty;

  static Future<bool> init() async {
    /// only init when logged in
    if (!UserSetting.hasLoggedIn()) {
      return false;
    }

    try {
      favoriteTagNames2Count = await EHRequest.getFavoriteTags();
      favoriteTagNames = favoriteTagNames2Count?.keys.toList();
    } on DioError catch (e) {
      Log.error('FavoriteSetting init fail', e.message);
      return false;
    }
    Log.info('FavoriteSetting init success', false);
    return true;
  }
}
