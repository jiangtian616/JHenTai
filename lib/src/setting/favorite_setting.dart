import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:retry/retry.dart';

import '../service/storage_service.dart';
import '../utils/eh_spider_parser.dart';

class FavoriteSetting {
  static List<String> favoriteTagNames = [
    'Favorite 0',
    'Favorite 1',
    'Favorite 2',
    'Favorite 3',
    'Favorite 4',
    'Favorite 5',
    'Favorite 6',
    'Favorite 7',
    'Favorite 8',
    'Favorite 9',
  ];
  static LinkedHashMap<String, int> favoriteTagNames2Count = LinkedHashMap<String, int>.of({
    'Favorite 0': -1,
    'Favorite 1': -1,
    'Favorite 2': -1,
    'Favorite 3': -1,
    'Favorite 4': -1,
    'Favorite 5': -1,
    'Favorite 6': -1,
    'Favorite 7': -1,
    'Favorite 8': -1,
    'Favorite 9': -1,
  });

  static bool get inited => favoriteTagNames2Count['Favorite 0'] != -1;

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('favoriteSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init FavoriteSetting success', false);
    } else {
      Log.verbose('init FavoriteSetting success: default', false);
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
    /// only refresh when logged in
    if (!UserSetting.hasLoggedIn()) {
      return;
    }

    try {
      await retry(
        () async {
          favoriteTagNames2Count = await EHRequest.requestFavoritePage(EHSpiderParser.favoritePage2FavoriteTags);
          favoriteTagNames = favoriteTagNames2Count.keys.toList();
          save();
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

  static void incrementFavByIndex(int? index) async {
    if (index == null || index < 0 || index >= favoriteTagNames.length) {
      return;
    }
    favoriteTagNames2Count[FavoriteSetting.favoriteTagNames[index]] =
        favoriteTagNames2Count[FavoriteSetting.favoriteTagNames[index]]! + 1;
  }

  static void decrementFavByIndex(int? index) async {
    if (index == null || index < 0 || index >= favoriteTagNames.length) {
      return;
    }
    favoriteTagNames2Count[FavoriteSetting.favoriteTagNames[index]] =
        favoriteTagNames2Count[FavoriteSetting.favoriteTagNames[index]]! - 1;
  }

  static Future<void> save() async {
    await Get.find<StorageService>().write('favoriteSetting', _toMap());
  }

  static Future<void> _clear() async {
    favoriteTagNames = [
      'Favorite 0',
      'Favorite 1',
      'Favorite 2',
      'Favorite 3',
      'Favorite 4',
      'Favorite 5',
      'Favorite 6',
      'Favorite 7',
      'Favorite 8',
    ];
    favoriteTagNames2Count = LinkedHashMap<String, int>.of({
      'Favorite 0': -1,
      'Favorite 1': -1,
      'Favorite 2': -1,
      'Favorite 3': -1,
      'Favorite 4': -1,
      'Favorite 5': -1,
      'Favorite 6': -1,
      'Favorite 7': -1,
      'Favorite 8': -1,
    });
    Get.find<StorageService>().remove('favoriteSetting');
    Log.info('clear FavoriteSetting success', false);
  }

  static Map<String, dynamic> _toMap() {
    return {
      'favoriteTagNames': jsonEncode(favoriteTagNames),
      'favoriteTagNames2Count': jsonEncode(favoriteTagNames2Count),
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    favoriteTagNames = (jsonDecode(map['favoriteTagNames']) as List).cast<String>();
    favoriteTagNames2Count = LinkedHashMap.of(
        (jsonDecode(map['favoriteTagNames2Count']) as Map).map((key, value) => MapEntry<String, int>(key, value)));
  }
}
