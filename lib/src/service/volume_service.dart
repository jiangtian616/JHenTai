import 'package:get/get.dart';

import '../utils/log.dart';

class VolumeService extends GetxService {
  static void init() {
    if (!GetPlatform.isAndroid) {
      return;
    }
    Get.put(VolumeService());
    Log.debug('init VolumeService success', false);
  }

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  void disableVolume() {}
}
