import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:retry/retry.dart';

import '../exception/eh_exception.dart';
import '../service/storage_service.dart';
import '../utils/eh_spider_parser.dart';

class EHSetting {
  static RxString site = 'EH'.obs;
  static RxBool redirect2Eh = true.obs;
  static Rx<LoadingState> refreshState = LoadingState.idle.obs;
  static RxInt currentConsumption = (-1).obs;
  static RxInt totalLimit = 5000.obs;
  static RxInt resetCost = (-1).obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('EHSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init EHSetting success, site: $site');
    } else {
      Log.debug('init EHSetting success: default');
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

    Log.info('refresh EHSetting');
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
    } on EHException catch (e) {
      Log.error('refresh EHSetting fail', e.message);
      refreshState.value = LoadingState.error;
      return;
    }

    currentConsumption.value = map['currentConsumption']!;
    totalLimit.value = map['totalLimit']!;
    resetCost.value = map['resetCost']!;
    refreshState.value = LoadingState.idle;
    _save();
    Log.info('refresh EHSetting success');
  }

  static saveSite(String site) {
    Log.debug('saveSite:$site');
    EHSetting.site.value = site;
    _save();
    SiteSetting.refresh();
  }

  static saveRedirect2Eh(bool redirect2Eh) {
    Log.debug('saveRedirect2Eh:$redirect2Eh');
    EHSetting.redirect2Eh.value = redirect2Eh;
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
    Log.info('clear EHSetting success');
  }

  static Map<String, dynamic> _toMap() {
    return {
      'site': site.value,
      'redirect2Eh': redirect2Eh.value,
      'totalLimit': totalLimit.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    site.value = map['site'];
    redirect2Eh.value = map['redirect2Eh'] ?? redirect2Eh.value;
    totalLimit.value = map['totalLimit'];
  }
}
