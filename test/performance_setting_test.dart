import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/setting/performance_setting.dart';

void main() {
  test('experimental reader features default to off for existing users', () {
    final setting = PerformanceSetting();

    setting.applyBeanConfig('{"maxGalleryNum4Animation": 42}');

    expect(setting.enableReaderEngine2.value, isFalse);
    expect(setting.enablePerformanceGovernor.value, isFalse);
    expect(setting.enableProgressiveImagePipeline.value, isFalse);
  });

  test('experimental reader features round-trip through config JSON', () {
    final setting = PerformanceSetting();
    setting.enableReaderEngine2.value = true;
    setting.enablePerformanceGovernor.value = true;
    setting.enableProgressiveImagePipeline.value = true;

    final encoded =
        jsonDecode(setting.toConfigString()) as Map<String, dynamic>;
    expect(encoded['enableReaderEngine2'], isTrue);
    expect(encoded['enablePerformanceGovernor'], isTrue);
    expect(encoded['enableProgressiveImagePipeline'], isTrue);

    final restored = PerformanceSetting();
    restored.applyBeanConfig(setting.toConfigString());
    expect(restored.enableReaderEngine2.value, isTrue);
    expect(restored.enablePerformanceGovernor.value, isTrue);
    expect(restored.enableProgressiveImagePipeline.value, isTrue);
  });
}
