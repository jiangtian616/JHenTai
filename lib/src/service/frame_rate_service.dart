import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';

import 'jh_service.dart';

FrameRateService frameRateService = FrameRateService();

class FrameRateService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  @override
  Future<void> doInitBean() async {
    if (GetPlatform.isAndroid) {
      await FlutterDisplayMode.setHighRefreshRate();
    }
  }

  @override
  Future<void> doAfterBeanReady() async {}
}
