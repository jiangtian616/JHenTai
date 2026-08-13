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

  /// Experimental reader features are opt-in so upgrades preserve the
  /// existing reader behavior until the user explicitly enables them.
  RxBool enableReaderEngine2 = false.obs;
  RxBool enablePerformanceGovernor = false.obs;
  RxBool enableProgressiveImagePipeline = false.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.performanceSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    maxGalleryNum4Animation.value = map['maxGalleryNum4Animation'] ?? maxGalleryNum4Animation.value;
    enableCoverDecodeOptimization.value = map['enableCoverDecodeOptimization'] ?? enableCoverDecodeOptimization.value;
    enableReaderEngine2.value =
        map['enableReaderEngine2'] ?? enableReaderEngine2.value;
    enablePerformanceGovernor.value = map['enablePerformanceGovernor'] ??
        enablePerformanceGovernor.value;
    enableProgressiveImagePipeline.value =
        map['enableProgressiveImagePipeline'] ??
            enableProgressiveImagePipeline.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'maxGalleryNum4Animation': maxGalleryNum4Animation.value,
      'enableCoverDecodeOptimization': enableCoverDecodeOptimization.value,
      'enableReaderEngine2': enableReaderEngine2.value,
      'enablePerformanceGovernor': enablePerformanceGovernor.value,
      'enableProgressiveImagePipeline':
          enableProgressiveImagePipeline.value,
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

  Future<void> setEnableReaderEngine2(bool value) async {
    log.debug('setEnableReaderEngine2:$value');
    enableReaderEngine2.value = value;
    await saveBeanConfig();
  }

  Future<void> setEnablePerformanceGovernor(bool value) async {
    log.debug('setEnablePerformanceGovernor:$value');
    enablePerformanceGovernor.value = value;
    await saveBeanConfig();
  }

  Future<void> setEnableProgressiveImagePipeline(bool value) async {
    log.debug('setEnableProgressiveImagePipeline:$value');
    enableProgressiveImagePipeline.value = value;
    await saveBeanConfig();
  }
}
