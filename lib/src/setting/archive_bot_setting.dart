import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../service/jh_service.dart';

ArchiveBotSetting archiveBotSetting = ArchiveBotSetting();

class ArchiveBotSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  final RxnString apiKey = RxnString(null);
  final RxBool useProxyServer = true.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.archiveBotSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);
    apiKey.value = map['apiKey'];
    useProxyServer.value = map['useProxyServer'] ?? true;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'apiKey': apiKey.value,
      'useProxyServer': useProxyServer.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveApiKey(String? value) async {
    log.debug('saveApiKey: $value');
    apiKey.value = value;
    await saveBeanConfig();
  }

  Future<void> saveUseProxyServer(bool value) async {
    log.debug('saveUseProxyServer: $value');
    useProxyServer.value = value;
    await saveBeanConfig();
  }
}
