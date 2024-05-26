import 'package:flutter/cupertino.dart';
import 'package:get/get_utils/src/platform/platform.dart';
import 'package:http_proxy/http_proxy.dart';
import 'package:jhentai/src/utils/log.dart';
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

  Log.info('systemProxyAddress: $systemProxyAddress');
  return systemProxyAddress;
}

Future<String Function(Uri)> findProxySettingFunc(ValueGetter<String> systemProxyAddress) async {
  String configProxyAddress() {
    String configAddress;
    if (isEmptyOrNull(NetworkSetting.proxyUsername.value?.trim()) && isEmptyOrNull(NetworkSetting.proxyPassword.value?.trim())) {
      configAddress = NetworkSetting.proxyAddress.value;
    } else {
      configAddress = '${NetworkSetting.proxyUsername.value ?? ''}:${NetworkSetting.proxyPassword.value ?? ''}@${NetworkSetting.proxyAddress.value}';
    }
    return configAddress;
  }

  return (_) {
    switch (NetworkSetting.proxyType.value) {
      case JProxyType.system:
        return isEmptyOrNull(systemProxyAddress.call()) ? 'DIRECT' : 'PROXY ${systemProxyAddress.call()}; DIRECT';
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
