import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../service/jh_service.dart';

ArchiveBotSetting archiveBotSetting = ArchiveBotSetting();

class ArchiveBotSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  final RxnString apiKey = RxnString(null);

  @override
  ConfigEnum get configEnum => ConfigEnum.archiveBotSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);
    apiKey.value = map['apiKey'] ?? '';
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'apiKey': apiKey.value,
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
}
