import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:retry/retry.dart';

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
    if (inited) {
      return true;
    }

    try {
      retry(
        () async {
          favoriteTagNames2Count = await EHRequest.getFavoriteTags();
          favoriteTagNames = favoriteTagNames2Count?.keys.toList();
        },
        retryIf: (e) => e is DioError,
        maxAttempts: 4,
      );
    } on DioError catch (e) {
      Log.error('FavoriteSetting init fail', e.message);
      return false;
    }

    Log.info('init FavoriteSetting success', false);
    return true;
  }
}
