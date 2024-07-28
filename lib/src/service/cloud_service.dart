import 'package:drift/drift.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/model/config.dart';
import 'package:jhentai/src/service/isolate_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/service/search_history_service.dart';

import '../database/database.dart';
import 'history_service.dart';
import 'jh_service.dart';
import 'local_block_rule_service.dart';
import 'log.dart';

CloudConfigService cloudConfigService = CloudConfigService();

class CloudConfigService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static Map<CloudConfigTypeEnum, String> configTypeVersionMap = {
    CloudConfigTypeEnum.readIndexRecord: '1.0.0',
    CloudConfigTypeEnum.quickSearch: '1.0.0',
    CloudConfigTypeEnum.searchHistory: '1.0.0',
    CloudConfigTypeEnum.blockRules: '1.0.0',
    CloudConfigTypeEnum.history: '1.0.0',
  };

  static const int localConfigId = -1;
  static const String localConfigCode = 'local';
  static const String configFileName = 'JHenTaiConfig';

  @override
  Future<void> doInitBean() async {}

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> importConfig(CloudConfig config) async {
    log.info('importConfig: ${config.type}');

    switch (config.type) {
      case CloudConfigTypeEnum.readIndexRecord:
        List list = await isolateService.jsonDecodeAsync(config.config);
        List<LocalConfig> readIndexRecords = list.map((e) => LocalConfig.fromJson(e)).toList();
        await localConfigService.batchWrite(readIndexRecords
            .map((e) => LocalConfigCompanion(
                  configKey: Value(e.configKey.key),
                  subConfigKey: Value(e.subConfigKey),
                  value: Value(e.value),
                  utime: Value(e.utime),
                ))
            .toList());
        break;
      case CloudConfigTypeEnum.quickSearch:
        await localConfigService.write(configKey: ConfigEnum.quickSearch, value: config.config);
        await quickSearchService.refreshBean();
        break;
      case CloudConfigTypeEnum.searchHistory:
        List list = await isolateService.jsonDecodeAsync(config.config);
        List<String> searchHistories = list.map((e) => e as String).toList();
        for (String searchHistory in searchHistories) {
          searchHistoryService.writeHistory(searchHistory);
        }
        break;
      case CloudConfigTypeEnum.blockRules:
        List list = await isolateService.jsonDecodeAsync(config.config);
        List<LocalBlockRule> blockRules = list.map((e) => LocalBlockRule.fromJson(e)).toList();
        for (LocalBlockRule blockRule in blockRules) {
          blockRule.id = null;
          await localBlockRuleService.upsertBlockRule(blockRule);
        }
        break;
      case CloudConfigTypeEnum.history:
        List list = await isolateService.jsonDecodeAsync(config.config);
        List<GalleryHistoryV2Data> histories = list.map((e) => GalleryHistoryV2Data.fromJson(e)).toList();
        await historyService.batchRecord(histories);
        break;
    }
  }

  Future<CloudConfig?> getLocalConfig(CloudConfigTypeEnum type) async {
    String configValue;
    switch (type) {
      case CloudConfigTypeEnum.readIndexRecord:
        List<LocalConfig> readIndexRecords = await localConfigService.readWithAllSubKeys(configKey: ConfigEnum.readIndexRecord);
        if (readIndexRecords.isEmpty) {
          return null;
        }
        configValue = await isolateService.jsonEncodeAsync(readIndexRecords);
        break;
      case CloudConfigTypeEnum.quickSearch:
        String? quickSearches = await localConfigService.read(configKey: ConfigEnum.quickSearch);
        if (quickSearches == null) {
          return null;
        }
        configValue = quickSearches;
        break;
      case CloudConfigTypeEnum.searchHistory:
        String? searchHistories = await localConfigService.read(configKey: ConfigEnum.searchHistory);
        if (searchHistories == null) {
          return null;
        }
        configValue = searchHistories;
        break;
      case CloudConfigTypeEnum.blockRules:
        List<LocalBlockRule> blockRules = await localBlockRuleService.getBlockRules();
        configValue = await isolateService.jsonEncodeAsync(blockRules);
        break;
      case CloudConfigTypeEnum.history:
        List<GalleryHistoryV2Data> histories = await historyService.getLatest10000RawHistory();
        configValue = await isolateService.jsonEncodeAsync(histories);
        break;
    }

    return CloudConfig(
      id: localConfigId,
      shareCode: localConfigCode,
      identificationCode: localConfigCode,
      type: type,
      version: CloudConfigService.configTypeVersionMap[type]!,
      config: configValue,
      ctime: DateTime.now(),
    );
  }
}
