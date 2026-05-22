import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get/get_utils/src/platform/platform.dart';
import 'package:http_proxy/http_proxy.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/string_uril.dart';

import '../setting/network_setting.dart';

Future<String> _getDesktopSystemProxyAddress() async {
  try {
    if (Platform.isMacOS) {
      ProcessResult results =
          await Process.run('bash', ['-c', 'networksetup -getwebproxy wi-fi']);
      RegExpMatch? match = RegExp(
        r'^.*Enabled: (?<enabled>.*)\nServer: (?<server>.*)\nPort: (?<port>.*)\n.*$',
        multiLine: true,
      ).firstMatch(results.stdout as String);
      String server = match?.namedGroup('server') ?? '';
      String port = match?.namedGroup('port') ?? '';
      return server.isEmpty ? '' : '$server:$port';
    }

    if (Platform.isLinux) {
      ProcessResult results = await Process.run('bash', [
        '-c',
        'gsettings get org.gnome.system.proxy.http host && gsettings get org.gnome.system.proxy.http port'
      ]);
      List<String> lines = (results.stdout as String)
          .split('\n')
          .where((item) => item.isNotEmpty)
          .toList();
      if (lines.length < 2) {
        return '';
      }
      String host = lines.first.trim().replaceAll("'", '');
      return host.isEmpty ? '' : '$host:${lines[1]}';
    }

    if (Platform.isWindows) {
      ProcessResult results = await Process.run('reg', [
        'query',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyServer',
      ]);
      String proxyServerLine = (results.stdout as String)
          .split('\r\n')
          .where((item) => item.contains('ProxyServer'))
          .first;
      List<String> parts = proxyServerLine.split(RegExp(r'\s+'));
      return parts.isEmpty ? '' : parts.last;
    }
  } catch (e) {
    log.error('getSystemProxyAddressFailed', e.toString());
  }

  return '';
}

Future<String> getSystemProxyAddress() async {
  String systemProxyAddress = '';

  if (GetPlatform.isDesktop) {
    systemProxyAddress = await _getDesktopSystemProxyAddress();
  }
  if (GetPlatform.isMobile) {
    HttpProxy httpProxy = await HttpProxy.createHttpProxy();
    if (!isEmptyOrNull(httpProxy.host) && !isEmptyOrNull(httpProxy.port)) {
      systemProxyAddress = '${httpProxy.host}:${httpProxy.port}';
    }
  }

  log.info('systemProxyAddress: $systemProxyAddress');
  return systemProxyAddress;
}

Future<String Function(Uri)> findProxySettingFunc(
    ValueGetter<String> systemProxyAddress) async {
  String configProxyAddress() {
    String configAddress;
    if (isEmptyOrNull(networkSetting.proxyUsername.value?.trim()) &&
        isEmptyOrNull(networkSetting.proxyPassword.value?.trim())) {
      configAddress = networkSetting.proxyAddress.value;
    } else {
      configAddress =
          '${networkSetting.proxyUsername.value ?? ''}:${networkSetting.proxyPassword.value ?? ''}@${networkSetting.proxyAddress.value}';
    }
    return configAddress;
  }

  return (_) {
    switch (networkSetting.proxyType.value) {
      case JProxyType.system:
        return isEmptyOrNull(systemProxyAddress.call())
            ? 'DIRECT'
            : 'PROXY ${systemProxyAddress.call()}; DIRECT';
      case JProxyType.http:
        return 'PROXY ${configProxyAddress()}; DIRECT';
      case JProxyType.socks5:
        return 'SOCKS5 ${configProxyAddress()}; DIRECT';
      case JProxyType.socks4:
        return 'SOCKS4 ${configProxyAddress()}; DIRECT';
      case JProxyType.direct:
        return 'DIRECT';
    }
  };
}
