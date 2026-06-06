import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';

import 'jh_service.dart';
import 'log.dart';

FrameRateService frameRateService = FrameRateService();

class FrameRateService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  @override
  Future<void> doInitBean() async {
    if (GetPlatform.isAndroid) {
      List<DisplayMode> modes = await FlutterDisplayMode.supported;
      log.debug('display modes: $modes');
      
      await FlutterDisplayMode.setHighRefreshRate();
    }
  }

  @override
  Future<void> doAfterBeanReady() async {}
}
