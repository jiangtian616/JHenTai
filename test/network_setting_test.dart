import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/setting/network_setting.dart';

void main() {
  group('NetworkSetting merged cache config', () {
    test('smart cache is enabled by default with 7-day retention', () {
      final NetworkSetting setting = NetworkSetting();

      expect(setting.enableSmartCache.value, isTrue);
      expect(setting.smartCacheRetention.value, const Duration(days: 7));
      expect(setting.effectivePageCacheMaxAge, const Duration(days: 7));
      expect(
        setting.effectiveCacheImageExpireDuration,
        const Duration(days: 7),
      );
    });

    test('legacy v1 config migrates smart cache to enabled', () {
      final NetworkSetting setting = NetworkSetting();

      setting.applyBeanConfig(
        jsonEncode({
          'pageCacheMaxAge': 60 * 60 * 1000,
          'cacheImageExpireDuration': 7 * 24 * 60 * 60 * 1000,
          'enableSmartCache': false,
          'smartCacheRetention': 3 * 24 * 60 * 60 * 1000,
        }),
      );

      expect(setting.enableSmartCache.value, isTrue);
      expect(setting.smartCacheRetention.value, const Duration(days: 3));
    });

    test('v2 config preserves the user choice', () {
      final NetworkSetting setting = NetworkSetting();

      setting.applyBeanConfig(
        jsonEncode({
          'cacheConfigVersion': NetworkSetting.cacheConfigVersion,
          'enableSmartCache': false,
          'smartCacheRetention': 3 * 24 * 60 * 60 * 1000,
        }),
      );

      expect(setting.enableSmartCache.value, isFalse);
      expect(setting.effectivePageCacheMaxAge, const Duration(hours: 1));
      expect(
        setting.effectiveCacheImageExpireDuration,
        const Duration(days: 7),
      );
    });

    test(
      'zero retention persists as unlimited while smart cache is enabled',
      () {
        final NetworkSetting setting = NetworkSetting();

        setting.applyBeanConfig(
          jsonEncode({
            'cacheConfigVersion': NetworkSetting.cacheConfigVersion,
            'enableSmartCache': true,
            'smartCacheRetention': 0,
          }),
        );

        expect(setting.smartCacheRetention.value, Duration.zero);
        expect(setting.isSmartCacheRetentionUnlimited, isTrue);
        expect(
          (jsonDecode(setting.toConfigString())
              as Map<String, dynamic>)['smartCacheRetention'],
          0,
        );
      },
    );

    test('serialized config contains only merged cache keys', () {
      final NetworkSetting setting = NetworkSetting();
      final Map<String, dynamic> map =
          jsonDecode(setting.toConfigString()) as Map<String, dynamic>;

      expect(map['cacheConfigVersion'], NetworkSetting.cacheConfigVersion);
      expect(map['enableSmartCache'], isTrue);
      expect(map['smartCacheRetention'], 7 * 24 * 60 * 60 * 1000);
      expect(map.containsKey('pageCacheMaxAge'), isFalse);
      expect(map.containsKey('cacheImageExpireDuration'), isFalse);
    });
  });
}
