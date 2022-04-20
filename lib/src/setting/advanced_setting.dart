import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class AdvancedSetting {
  static Rx<Duration> pageCacheMaxAge = const Duration(hours: 1).obs;
  static RxBool enableDomainFronting = false.obs;
  static RxBool enableLogging = true.obs;
  static RxBool enableCheckUpdate = true.obs;

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('advancedSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init AdvancedSetting success', false);
    } else {
      Log.verbose('init AdvancedSetting success: default', false);
    }
  }

  static savePageCacheMaxAge(Duration pageCacheMaxAge) {
    AdvancedSetting.pageCacheMaxAge.value = pageCacheMaxAge;
    _save();
  }

  static saveEnableDomainFronting(bool enableDomainFronting) {
    AdvancedSetting.enableDomainFronting.value = enableDomainFronting;
    _save();
  }

  static saveEnableLogging(bool enableLogging) {
    AdvancedSetting.enableLogging.value = enableLogging;
    _save();
  }

  static saveEnableCheckUpdate(bool enableCheckUpdate) {
    AdvancedSetting.enableCheckUpdate.value = enableCheckUpdate;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('advancedSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'pageCacheMaxAge': pageCacheMaxAge.value.inMilliseconds,
      'enableDomainFronting': enableDomainFronting.value,
      'enableLogging': enableLogging.value,
      'enableCheckUpdate': enableCheckUpdate.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    pageCacheMaxAge.value = Duration(milliseconds: map['pageCacheMaxAge']);
    enableDomainFronting.value = map['enableDomainFronting'];
    enableLogging.value = map['enableLogging'];
    enableCheckUpdate.value = map['enableCheckUpdate'] ?? enableCheckUpdate.value;
  }
}
