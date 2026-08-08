import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';

import '../service/jh_service.dart';
import '../service/log.dart';

PerformanceSetting performanceSetting = PerformanceSetting();

class PerformanceSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxInt maxGalleryNum4Animation = 30.obs;

  /// Whether gallery-grid covers are decoded at a size closer to their
  /// displayed size (instead of the full native resolution), trading a small
  /// amount of quality for significantly lower decode time and memory.
  RxBool enableCoverDecodeOptimization = true.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.performanceSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    maxGalleryNum4Animation.value = map['maxGalleryNum4Animation'] ?? maxGalleryNum4Animation.value;
    enableCoverDecodeOptimization.value = map['enableCoverDecodeOptimization'] ?? enableCoverDecodeOptimization.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'maxGalleryNum4Animation': maxGalleryNum4Animation.value,
      'enableCoverDecodeOptimization': enableCoverDecodeOptimization.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> setMaxGalleryNum4Animation(int value) async {
    log.debug('setMaxGalleryNum4Animation:$value');
    maxGalleryNum4Animation.value = value;
    await saveBeanConfig();
  }

  Future<void> setEnableCoverDecodeOptimization(bool value) async {
    log.debug('setEnableCoverDecodeOptimization:$value');
    enableCoverDecodeOptimization.value = value;
    await saveBeanConfig();
  }
}
