import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_cookie_manager.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:retry/retry.dart';

import '../service/storage_service.dart';
import '../utils/log.dart';

class SiteSetting {
  static Rx<FrontPageDisplayType> frontPageDisplayType = FrontPageDisplayType.compact.obs;

  static RxBool isLargeThumbnail = false.obs;
  static RxInt thumbnailRows = 4.obs;
  static RxInt thumbnailsCountPerPage = 40.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('siteSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init SiteSetting success', false);
    } else {
      Log.debug('init SiteSetting success: default', false);
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
    if (!UserSetting.hasLoggedIn()) {
      return;
    }

    Log.info('refresh SiteSetting', false);

    Map<String, dynamic> result = {};
    try {
      await retry(
        () async => result = await EHRequest.requestSettingPage(EHSpiderParser.settingPage2SiteSetting),
        retryIf: (e) => e is DioError,
        maxAttempts: 3,
      );
    } on DioError catch (e) {
      Log.error('refresh SiteSetting fail', e.message);
      return;
    }

    frontPageDisplayType.value = result['frontPageDisplayType'];
    isLargeThumbnail.value = result['isLargeThumbnail'];
    thumbnailRows.value = result['thumbnailRows'];
    thumbnailsCountPerPage.value = thumbnailRows.value * (isLargeThumbnail.value ? 5 : 10);

    /// JHenTai's profile
    String? jHenTaiProfileNo = result['jHenTaiProfileNo'];
    if (jHenTaiProfileNo != null) {
      Log.debug('Find JHenTai profile: $jHenTaiProfileNo');
      Get.find<EHCookieManager>().storeEhCookiesForAllUri([Cookie('sp', jHenTaiProfileNo)]);
    } else {
      Log.debug('Create JHenTai profile');
      retry(EHRequest.createProfile, retryIf: (e) => e is DioError, maxAttempts: 3);
    }

    Log.info('refresh SiteSetting success', false);
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('siteSetting', _toMap());
  }

  static Future<void> _clear() async {
    frontPageDisplayType.value = FrontPageDisplayType.compact;
    isLargeThumbnail.value = false;
    thumbnailRows.value = 4;
    thumbnailsCountPerPage.value = 40;
    Get.find<StorageService>().remove('siteSetting');
    Log.info('clear SiteSetting success', false);
  }

  static Map<String, dynamic> _toMap() {
    return {
      'frontPageDisplayType': frontPageDisplayType.value.index,
      'isLargeThumbnail': isLargeThumbnail.value,
      'thumbnailRows': thumbnailRows.value,
      'thumbnailsCountPerPage': thumbnailsCountPerPage.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    frontPageDisplayType.value = FrontPageDisplayType.values[map['frontPageDisplayType']];
    isLargeThumbnail.value = map['isLargeThumbnail'];
    thumbnailRows.value = map['thumbnailRows'];
    thumbnailsCountPerPage.value = map['thumbnailsCountPerPage'];
  }
}

enum FrontPageDisplayType {
  minimal,
  minimalPlus,
  compact,
  extended,
  thumbnail,
}
