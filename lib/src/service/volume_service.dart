import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/log.dart';

class VolumeService extends GetxService {
  static const platform = MethodChannel('volume.event.intercept');

  static void init() {
    Get.put(VolumeService());
    Log.debug('init VolumeService success', false);
  }

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  Future<void> setInterceptVolumeEvent(bool value) async {
    if (!GetPlatform.isAndroid) {
      return;
    }

    try {
      await platform.invokeMethod('set', value);
    } on PlatformException catch (e) {
      Log.error('Set intercept volume event error!', e);
      Log.upload(e);
    }
  }
}
