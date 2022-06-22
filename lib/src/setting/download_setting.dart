import 'package:get/get.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart';

import '../service/storage_service.dart';

class DownloadSetting {
  static String defaultDownloadPath = join(PathSetting.getVisibleDir().path, 'download');
  static RxString downloadPath = defaultDownloadPath.obs;
  static RxInt downloadTaskConcurrency = 6.obs;
  static RxInt maximum = 2.obs;
  static Rx<Duration> period = const Duration(seconds: 1).obs;
  static RxInt timeout = 10.obs;
  static RxBool enableStoreMetadataForRestore = true.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('downloadSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init DownloadSetting success', false);
    } else {
      Log.verbose('init DownloadSetting success: default', false);
    }
  }

  static saveDownloadPath(String downloadPath) {
    Log.verbose('saveDownloadPath:$downloadPath}');
    DownloadSetting.downloadPath.value = downloadPath;
    _save();
  }

  static saveDownloadTaskConcurrency(int downloadTaskConcurrency) {
    DownloadSetting.downloadTaskConcurrency.value = downloadTaskConcurrency;
    _save();
  }

  static saveMaximum(int maximum) {
    DownloadSetting.maximum.value = maximum;
    _save();
  }

  static savePeriod(Duration period) {
    DownloadSetting.period.value = period;
    _save();
  }

  static saveTimeout(int value) {
    timeout.value = value;
    _save();
  }

  static saveEnableStoreMetadataToRestore(bool value) {
    enableStoreMetadataForRestore.value = value;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('downloadSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'downloadPath': downloadPath.value,
      'downloadTaskConcurrency': downloadTaskConcurrency.value,
      'maximum': maximum.value,
      'period': period.value.inMilliseconds,
      'timeout': timeout.value,
      'enableStoreMetadataForRestore': enableStoreMetadataForRestore.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    downloadPath.value = map['downloadPath'] ?? downloadPath.value;
    downloadTaskConcurrency.value = map['downloadTaskConcurrency'];
    maximum.value = map['maximum'];
    period.value = Duration(milliseconds: map['period']);
    timeout.value = map['timeout'];
    enableStoreMetadataForRestore.value = map['enableStoreMetadataForRestore'];
  }
}
