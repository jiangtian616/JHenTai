import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/utils/proxy_util.dart';

void main() {
  group('shouldBypassProxy', () {
    test('bypasses local network addresses', () {
      expect(shouldBypassProxy(Uri.parse('http://localhost:43822')), isTrue);
      expect(shouldBypassProxy(Uri.parse('http://192.168.1.8:43822')), isTrue);
      expect(shouldBypassProxy(Uri.parse('http://10.0.0.5:43822')), isTrue);
      expect(shouldBypassProxy(Uri.parse('http://172.20.0.4:43822')), isTrue);
      expect(shouldBypassProxy(Uri.parse('http://169.254.1.2:43822')), isTrue);
      expect(shouldBypassProxy(Uri.parse('http://[fd12::8]:43822')), isTrue);
      expect(shouldBypassProxy(Uri.parse('http://device.local:43822')), isTrue);
    });

    test('keeps public addresses eligible for the configured proxy', () {
      expect(shouldBypassProxy(Uri.parse('https://e-hentai.org')), isFalse);
      expect(shouldBypassProxy(Uri.parse('https://172.66.132.196')), isFalse);
    });

    test('returns DIRECT for LAN and the proxy for public requests', () async {
      final JProxyType previousType = networkSetting.proxyType.value;
      networkSetting.proxyType.value = JProxyType.system;
      try {
        final String Function(Uri) findProxy = await findProxySettingFunc(
          () => '127.0.0.1:1080',
        );

        expect(findProxy(Uri.parse('ws://192.168.1.8:43822')), 'DIRECT');
        expect(
          findProxy(Uri.parse('https://e-hentai.org')),
          'PROXY 127.0.0.1:1080; DIRECT',
        );
      } finally {
        networkSetting.proxyType.value = previousType;
      }
    });
  });
}
