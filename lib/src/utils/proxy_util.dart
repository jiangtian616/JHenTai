import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get/get_utils/src/platform/platform.dart';
import 'package:http_proxy/http_proxy.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:system_network_proxy/system_network_proxy.dart';

import '../setting/network_setting.dart';

Future<String> getSystemProxyAddress() async {
  String systemProxyAddress = '';

  if (GetPlatform.isDesktop) {
    SystemNetworkProxy.init();
    systemProxyAddress = await SystemNetworkProxy.getProxyServer();
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
  ValueGetter<String> systemProxyAddress,
) async {
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

  return (Uri uri) {
    if (shouldBypassProxy(uri)) {
      return 'DIRECT';
    }

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

/// LAN pairing and WebSocket sessions must not be routed through the system
/// proxy. The proxy is commonly unable to reach private addresses, and even
/// when it can, the extra hop breaks peer discovery/pairing timeouts.
bool shouldBypassProxy(Uri uri) {
  final String host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (host == 'localhost' || host.endsWith('.local')) {
    return true;
  }

  final InternetAddress? address = InternetAddress.tryParse(host);
  if (address == null) {
    return false;
  }
  if (address.isLoopback) {
    return true;
  }

  final List<int> raw = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return raw[0] == 10 ||
        (raw[0] == 172 && raw[1] >= 16 && raw[1] <= 31) ||
        (raw[0] == 192 && raw[1] == 168) ||
        (raw[0] == 169 && raw[1] == 254);
  }

  // IPv6 unique-local (fc00::/7) and link-local (fe80::/10) addresses are
  // also valid peer addresses on local networks.
  return (raw[0] & 0xfe) == 0xfc || (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80);
}
