import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/model/config.dart';
import 'package:jhentai/src/service/history_service.dart';
import 'package:jhentai/src/service/local_block_rule_service.dart';
import 'package:jhentai/src/service/storage_service.dart';

import 'jh_service.dart';
import 'log.dart';

CloudConfigService cloudConfigService = CloudConfigService();

class CloudConfigService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static Map<CloudConfigTypeEnum, String> configTypeVersionMap = {
    CloudConfigTypeEnum.settings: '1.0.0',
    CloudConfigTypeEnum.blockRules: '1.0.0',
    CloudConfigTypeEnum.history: '1.0.0',
  };

  static const String localConfigCode = 'local';
  static const String configFileName = 'JHenTaiConfig';

  @override
  Future<void> doOnInit() async {}

  @override
  void doOnReady() {}

  Future<Map<CloudConfigTypeEnum, String>> getCurrentConfigMap() async {
    return {};
    // Map<String, dynamic>? settings = storageService.getData()
    //   ?..remove(StorageEnum.ehCookie.key)
    //   ..remove(StorageEnum.favoriteSetting.key)
    //   ..remove(StorageEnum.downloadSetting.key)
    //   ..remove(StorageEnum.EHSetting.key)
    //   ..remove(StorageEnum.securitySetting.key)
    //   ..remove(StorageEnum.siteSetting.key)
    //   ..remove(StorageEnum.superResolutionSetting.key)
    //   ..remove(StorageEnum.userSetting.key)
    //   ..removeWhere((key, value) => key.startsWith(StorageEnum.isSpreadPage.key));
    //
    // List<LocalBlockRule> blockRules = await localBlockRuleService.getBlockRules();
    //
    // List<Gallery> histories = await historyService.getAllHistory();
    //
    // Map<CloudConfigTypeEnum, String> map = {
    //   CloudConfigTypeEnum.settings: jsonEncode(settings),
    //   CloudConfigTypeEnum.blockRules: jsonEncode(blockRules),
    //   CloudConfigTypeEnum.history: jsonEncode(histories),
    // };
    // return map;
  }

  Future<void> importConfig(CloudConfig config) async {
    // if (config.type == CloudConfigTypeEnum.settings) {
    //   Map<String, dynamic> map = jsonDecode(config.config);
    //   map.forEach(storageService.write);
    // } else if (config.type == CloudConfigTypeEnum.blockRules) {
    //   List list = jsonDecode(config.config);
    //   List<LocalBlockRule> blockRules = list.map((e) => LocalBlockRule.fromJson(e)).toList();
    //   for (LocalBlockRule blockRule in blockRules) {
    //     blockRule.id = null;
    //     await localBlockRuleService.upsertBlockRule(blockRule);
    //   }
    // } else if (config.type == CloudConfigTypeEnum.history) {
    //   List list = await compute((string) => jsonDecode(string), config.config);
    //   List<Gallery> histories = list.map((e) => Gallery.fromJson(e)).toList();
    //   await historyService.batchRecord(histories);
    // }
  }
}
