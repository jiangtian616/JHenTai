import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/log.dart';

enum VolumeEventType { volumeUp, volumeDown }

class VolumeService extends GetxService {
  late final MethodChannel methodChannel;

  static const int volumeUp = 1;
  static const int volumeDown = -1;

  static void init() {
    Get.put(VolumeService(), permanent: true);
    Log.debug('init VolumeService success', false);
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    if (!GetPlatform.isAndroid) {
      return;
    }
    methodChannel = const MethodChannel('top.jtmonster.jhentai.volume.event.intercept');
  }

  @override
  void onClose() {
    super.onClose();
    cancelListen();
  }

  Future<void> setInterceptVolumeEvent(bool value) async {
    if (!GetPlatform.isAndroid) {
      return;
    }

    try {
      await methodChannel.invokeMethod('set', value);
    } on PlatformException catch (e) {
      Log.error('Set intercept volume event error!', e);
      Log.upload(e);
    }
  }

  void listen(Function(VolumeEventType)? onData) {
    if (!GetPlatform.isAndroid) {
      return;
    }

    methodChannel.setMethodCallHandler((MethodCall call) {
      if (call.method == 'event') {
        final int eventType = call.arguments as int;
        if (eventType == volumeUp) {
          onData?.call(VolumeEventType.volumeUp);
        } else if (eventType == volumeDown) {
          onData?.call(VolumeEventType.volumeDown);
        }
      }
      return Future.value();
    });
  }

  void cancelListen() {
    if (!GetPlatform.isAndroid) {
      return;
    }

    methodChannel.setMethodCallHandler(null);
  }
}
