import 'package:get/get.dart';

import '../utils/log.dart';

class VolumeService extends GetxService {
  static Future<void> init() async {
    if (!GetPlatform.isAndroid) {
      return;
    }
    Get.put(VolumeService());
    Log.debug('init VolumeService success', false);
  }

  void disableVolume() {}
}
