import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../consts/archive_bot_consts.dart';
import '../model/archive_bot_response/archive_resolve_vo.dart';
import '../model/archive_bot_response/balance_vo.dart';
import '../model/archive_bot_response/check_in_vo.dart';
import '../service/jh_service.dart';

ArchiveBotSetting archiveBotSetting = ArchiveBotSetting();

enum ArchiveBotType {
  ehArBot(0),
  archiveAtHome(1),
  ;

  final int code;

  const ArchiveBotType(this.code);

  String get defaultServerAddress {
    switch (this) {
      case ArchiveBotType.ehArBot:
        return ArchiveBotConsts.defaultEhArBotServerAddress;
      case ArchiveBotType.archiveAtHome:
        return ArchiveBotConsts.defaultArchiveAtHomeServerAddress;
    }
  }

  BalanceVO parseBalance(Map<String, dynamic> data) {
    switch (this) {
      case ArchiveBotType.ehArBot:
        return BalanceVO.fromEhArBotResponse(data);
      case ArchiveBotType.archiveAtHome:
        return BalanceVO.fromArchiveAtHomeResponse(data);
    }
  }

  CheckInVO parseCheckIn(Map<String, dynamic> data) {
    switch (this) {
      case ArchiveBotType.ehArBot:
        return CheckInVO.fromEhArBotResponse(data);
      case ArchiveBotType.archiveAtHome:
        return CheckInVO.fromArchiveAtHomeResponse(data);
    }
  }

  ArchiveResolveVO parseResolve(Map<String, dynamic> data) {
    switch (this) {
      case ArchiveBotType.ehArBot:
        return ArchiveResolveVO.fromEhArBotResponse(data);
      case ArchiveBotType.archiveAtHome:
        return ArchiveResolveVO.fromArchiveAtHomeResponse(data);
    }
  }

  static ArchiveBotType fromCode(int code) {
    return ArchiveBotType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ArchiveBotType.ehArBot,
    );
  }
}

class ArchiveBotSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  final Rx<ArchiveBotType> botType = ArchiveBotType.ehArBot.obs;

  /// Only used when botType == ehArBot
  final RxnString apiAddress = RxnString(ArchiveBotConsts.defaultEhArBotServerAddress);

  final RxnString apiKey = RxnString(null);

  bool get isReady => apiKey.value != null && apiAddress.value != null;

  @override
  ConfigEnum get configEnum => ConfigEnum.archiveBotSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);
    apiKey.value = map['apiKey'];

    if (map['botType'] != null) {
      botType.value = ArchiveBotType.fromCode(map['botType'] as int);
    }

    apiAddress.value = map['apiAddress'];
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'botType': botType.value.code,
      'apiAddress': apiAddress.value,
      'apiKey': apiKey.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveConfig({
    required ArchiveBotType type,
    String? address,
    String? key,
  }) async {
    log.debug('saveConfig: type=$type, address=$address, key=$key');
    botType.value = type;
    apiAddress.value = address;
    apiKey.value = key;
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
}
