import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../consts/archive_bot_consts.dart';
import '../service/jh_service.dart';

ArchiveBotSetting archiveBotSetting = ArchiveBotSetting();

class ArchiveBotSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  final RxnString apiAddress = RxnString(ArchiveBotConsts.serverAddress);
  final RxnString apiKey = RxnString(null);
  final RxBool useProxyServer = false.obs;

  bool get isReady => (apiAddress.value != null || useProxyServer.isTrue) && apiKey.value != null;

  @override
  ConfigEnum get configEnum => ConfigEnum.archiveBotSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);
    apiAddress.value = map['apiAddress'] ?? apiAddress.value;
    apiKey.value = map['apiKey'];
    useProxyServer.value = map['useProxyServer'] ?? true;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'apiAddress': apiAddress.value,
      'apiKey': apiKey.value,
      'useProxyServer': useProxyServer.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveAllConfig(String? address, String? key, bool useProxy) async {
    log.debug('saveAllConfig: $address, $key, $useProxy');
    apiAddress.value = address;
    apiKey.value = key;
    useProxyServer.value = useProxy;
    await saveBeanConfig();
  }

  Future<void> saveApiAddress(String? value) async {
    log.debug('saveApiAddress: $value');
    apiAddress.value = value;
    await saveBeanConfig();
  }

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
