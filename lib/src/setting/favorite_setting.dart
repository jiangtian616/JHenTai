import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:retry/retry.dart';

import '../service/storage_service.dart';
import '../utils/eh_spider_parser.dart';

class FavoriteSetting {
  static List<String> favoriteTagNames = [

  ];
  static LinkedHashMap<String, int> favoriteTagNames2Count = LinkedHashMap<String, int>();

  static bool get inited => favoriteTagNames2Count.isNotEmpty && favoriteTagNames.isNotEmpty;

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('favoriteSetting');
    if (map != null) {
      _initFromMap(map);
      Log.info('init FavoriteSetting success', false);
    } else {
      Log.info('init FavoriteSetting success: default', false);
    }

    /// listen to login and logout
    ever(UserSetting.userName, (v) {
      if (UserSetting.hasLoggedIn()) {
        refresh();
      } else {
        _clear();
      }
    });
  }

  static Future<void> refresh() async {
    /// only init when logged in
    if (!UserSetting.hasLoggedIn()) {
      return;
    }
    if (inited) {
      return;
    }

    try {
      await retry(
        () async {
          favoriteTagNames2Count = await EHRequest.requestFavoritePage(EHSpiderParser.favoritePage2FavoriteTags);
          favoriteTagNames = favoriteTagNames2Count.keys.toList();
        },
        retryIf: (e) => e is DioError,
        maxAttempts: 3,
      );
    } on DioError catch (e) {
      Log.error('refresh FavoriteSetting fail', e.message);
      return;
    }

    Log.info('refresh FavoriteSetting success', false);
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('favoriteSetting', _toMap());
  }

  static Future<void> _clear() async {
    favoriteTagNames.clear();
    favoriteTagNames2Count.clear();
    _save();
    Log.info('clear FavoriteSetting success', false);
  }

  static Map<String, dynamic> _toMap() {
    return {
      'favoriteTagNames': jsonEncode(favoriteTagNames),
      'favoriteTagNames2Count': jsonEncode(favoriteTagNames2Count),
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    favoriteTagNames = (jsonDecode(map['favoriteTagNames']) as List).map((e) => e as String).toList();
    favoriteTagNames2Count = LinkedHashMap.of(
        (jsonDecode(map['favoriteTagNames2Count']) as Map).map((key, value) => MapEntry<String, int>(key, value)));
  }
}
