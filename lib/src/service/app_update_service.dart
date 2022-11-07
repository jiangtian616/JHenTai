import 'package:get/get.dart';
import 'package:jhentai/src/service/storage_service.dart';

import '../utils/log.dart';

class AppUpdateService extends GetxService {
  StorageService storageService = Get.find();

  static const int version = 1;

  static void init() {
    Get.put(AppUpdateService(), permanent: true);
  }

  @override
  onInit() async {
    super.onInit();

    int? oldVersion = storageService.read('appVersion');
    Log.debug('old version: $oldVersion, current version: $version');

    if ((oldVersion ?? 0) >= version) {
      return;
    }

    storageService.write('appVersion', version);
  }
}
