import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';

import '../service/jh_service.dart';
import '../service/log.dart';

PerformanceSetting performanceSetting = PerformanceSetting();

class PerformanceSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxInt maxGalleryNum4Animation = 30.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.performanceSetting;

  @override
  void applyConfig(String configString) {
    Map map = jsonDecode(configString);

    maxGalleryNum4Animation.value = map['maxGalleryNum4Animation'] ?? maxGalleryNum4Animation.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'maxGalleryNum4Animation': maxGalleryNum4Animation.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> setMaxGalleryNum4Animation(int value) async {
    log.debug('setMaxGalleryNum4Animation:$value');
    maxGalleryNum4Animation.value = value;
    await save();
  }
}
