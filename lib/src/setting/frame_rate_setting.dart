import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import '../utils/log.dart';

class FrameRateSetting {
  static Future<void> init() async {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } on PlatformException catch (e) {
      Log.error('init FrameRateSetting failed', e);
      Log.upload(e);
    }
    Log.debug('init FrameRateSetting success');
  }
}
