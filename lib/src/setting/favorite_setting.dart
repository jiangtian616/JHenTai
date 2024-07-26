import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:retry/retry.dart';

import '../exception/eh_site_exception.dart';
import '../service/storage_service.dart';
import '../utils/eh_spider_parser.dart';

class FavoriteSetting {
  static RxList<String> favoriteTagNames = [
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
  ].obs;
  static List<int> favoriteCounts = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1];

  static bool get inited => favoriteTagNames[0] != 'Favorite 0' || favoriteCounts[0] != -1;

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>(ConfigEnum.favoriteSetting.key);
    if (map != null) {
      _initFromMap(map);
      log.debug('init FavoriteSetting success', false);
    } else {
      log.debug('init FavoriteSetting success: default', false);
    }

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
    /// only refresh when logged in
    if (!UserSetting.hasLoggedIn()) {
      return;
    }

    log.info('refresh FavoriteSetting');
    try {
      await retry(
        () async {
          Map<String, List> map = await EHRequest.requestFavoritePage(EHSpiderParser.favoritePage2FavoriteTagsAndCounts);
          favoriteTagNames.value = map['favoriteTagNames'] as List<String>;
          favoriteCounts = map['favoriteCounts'] as List<int>;
          save();
        },
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } on DioException catch (e) {
      log.error('refresh FavoriteSetting fail', e.errorMsg);
      return;
    } on EHSiteException catch (e) {
      log.error('refresh FavoriteSetting fail', e.message);
      return;
    }

    log.info('refresh FavoriteSetting success');
  }

  static void incrementFavByIndex(int? index) async {
    if (index == null || index < 0 || index >= favoriteTagNames.length) {
      return;
    }
    favoriteCounts[index]++;
  }

  static void decrementFavByIndex(int? index) async {
    if (index == null || index < 0 || index >= favoriteTagNames.length) {
      return;
    }
    favoriteCounts[index]--;
  }

  static Future<void> save() async {
    await Get.find<StorageService>().write(ConfigEnum.favoriteSetting.key, _toMap());
  }

  static Future<void> _clear() async {
    favoriteTagNames.value = [
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
    favoriteCounts = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1];
    Get.find<StorageService>().remove(ConfigEnum.favoriteSetting.key);
    log.info('clear FavoriteSetting success');
  }

  static Map<String, dynamic> _toMap() {
    return {
      'favoriteTagNames': jsonEncode(favoriteTagNames.value),
      'favoriteCounts': jsonEncode(favoriteCounts),
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    favoriteTagNames.value = (jsonDecode(map['favoriteTagNames']) as List).cast<String>();
    favoriteCounts = (jsonDecode(map['favoriteCounts']) as List).cast<int>();
  }
}
