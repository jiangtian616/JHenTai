import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:retry/retry.dart';

import '../service/storage_service.dart';
import '../utils/eh_spider_parser.dart';

class EHSetting {
  static RxString site = 'EH'.obs;
  static Rx<LoadingState> refreshState = LoadingState.idle.obs;
  static RxInt currentConsumption = (-1).obs;
  static RxInt totalLimit = 5000.obs;
  static RxInt resetCost = (-1).obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('EHSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init EHSetting success', false);
    } else {
      Log.debug('init EHSetting success: default', false);
    }

    /// listen to logout
    ever(UserSetting.ipbMemberId, (v) {
      if (UserSetting.hasLoggedIn()) {
        refresh();
      } else {
        _clear();
      }
    });
  }

  static void refresh() async {
    /// only refresh when logged in
    if (!UserSetting.hasLoggedIn()) {
      return;
    }

    Log.info('refresh EHSetting', false);
    refreshState.value = LoadingState.loading;
    Map<String, int> map = {};
    try {
      await retry(
        () async {
          map = await EHRequest.requestHomePage(parser: EHSpiderParser.homePage2ImageLimit);
        },
        retryIf: (e) => e is DioError,
        maxAttempts: 3,
      );
    } on DioError catch (e) {
      Log.error('refresh EHSetting fail', e.message);
      refreshState.value = LoadingState.error;
      return;
    }

    currentConsumption.value = map['currentConsumption']!;
    totalLimit.value = map['totalLimit']!;
    resetCost.value = map['resetCost']!;
    refreshState.value = LoadingState.idle;
    _save();
    Log.info('refresh EHSetting success', false);
  }

  static saveSite(String site) {
    Log.debug('saveSite:$site');
    EHSetting.site.value = site;
    _save();
  }

  static saveTotalLimit(int totalLimit) {
    Log.debug('saveTotalLimit:$totalLimit');
    EHSetting.totalLimit.value = totalLimit;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('EHSetting', _toMap());
  }

  static Future<void> _clear() async {
    site.value = 'EH';
    currentConsumption.value = -1;
    Get.find<StorageService>().remove('EHSetting');
    Log.info('clear EHSetting success', false);
  }

  static Map<String, dynamic> _toMap() {
    return {
      'site': site.value,
      'totalLimit': totalLimit.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    site.value = map['site'];
    totalLimit.value = map['totalLimit'];
  }
}
