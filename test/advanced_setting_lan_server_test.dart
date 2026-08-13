import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';

void main() {
  test('LAN server role defaults to one disabled capability', () {
    final AdvancedSetting setting = AdvancedSetting();
    expect(setting.lanServerMode.value, isFalse);
    expect(setting.lanActAsServer.value, isFalse);
  });

  test('legacy server preference migrates into the unified role', () {
    final AdvancedSetting setting = AdvancedSetting();
    setting.applyBeanConfig('''
      {
        "enableLogging": true,
        "lanActAsServer": true
      }
    ''');
    expect(setting.lanServerMode.value, isTrue);
    expect(setting.lanActAsServer.value, isTrue);
  });

  test('either old server capability migrates into the unified role', () {
    final AdvancedSetting setting = AdvancedSetting();
    setting.applyBeanConfig('''
      {
        "enableLogging": true,
        "lanServerMode": false,
        "lanActAsServer": true
      }
    ''');
    expect(setting.lanServerMode.value, isTrue);
    expect(setting.lanActAsServer.value, isTrue);
  });

  test('unified role serializes both compatibility keys', () {
    final AdvancedSetting setting = AdvancedSetting();
    setting.lanServerMode.value = true;
    setting.lanActAsServer.value = true;
    final Map<String, dynamic> encoded =
        jsonDecode(setting.toConfigString()) as Map<String, dynamic>;
    expect(encoded['lanServerMode'], isTrue);
    expect(encoded['lanActAsServer'], isTrue);
  });
}
