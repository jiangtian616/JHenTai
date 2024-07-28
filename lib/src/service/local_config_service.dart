import 'package:drift/drift.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/jh_service.dart';

import '../database/database.dart';

class LocalConfig {
  ConfigEnum configKey;
  String subConfigKey;
  String value;
  String utime;

  LocalConfig({
    required this.configKey,
    required this.subConfigKey,
    required this.value,
    required this.utime,
  });

  Map<String, dynamic> toJson() {
    return {
      "configKey": this.configKey.key,
      "subConfigKey": this.subConfigKey,
      "value": this.value,
      "utime": this.utime,
    };
  }

  factory LocalConfig.fromJson(Map<String, dynamic> json) {
    return LocalConfig(
      configKey: ConfigEnum.from(json["configKey"]),
      subConfigKey: json["subConfigKey"],
      value: json["value"],
      utime: json["utime"],
    );
  }
}

LocalConfigService localConfigService = LocalConfigService();

class LocalConfigService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const String defaultSubConfigKey = '';

  @override
  Future<void> doInitBean() async {}

  @override
  Future<void> doAfterBeanReady() async {}

  Future<int> write({required ConfigEnum configKey, String subConfigKey = defaultSubConfigKey, required String value}) {
    return appDb.managers.localConfig.create(
      (l) => l(configKey: configKey.key, subConfigKey: subConfigKey, value: value, utime: DateTime.now().toString()),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> batchWrite(List<LocalConfigCompanion> localConfigs) async {
    return appDb.managers.localConfig.bulkCreate(
      (l) => localConfigs
          .map((i) => l(
                configKey: i.configKey.value,
                subConfigKey: i.subConfigKey.value,
                value: i.value.value,
                utime: DateTime.now().toString(),
              ))
          .toList(),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<String?> read({required ConfigEnum configKey, String subConfigKey = defaultSubConfigKey}) {
    return appDb.managers.localConfig
        .filter((config) => config.configKey.equals(configKey.key) & config.subConfigKey.equals(subConfigKey))
        .getSingleOrNull()
        .then((value) => value?.value);
  }

  Future<List<LocalConfig>> readWithAllSubKeys({required ConfigEnum configKey}) {
    return appDb.managers.localConfig.filter((config) => config.configKey.equals(configKey.key)).get().then((value) {
      return value
          .map((e) => LocalConfig(
                configKey: ConfigEnum.from(e.configKey),
                subConfigKey: e.subConfigKey,
                value: e.value,
                utime: e.utime,
              ))
          .toList();
    });
  }

  Future<bool> delete({required ConfigEnum configKey, String subConfigKey = defaultSubConfigKey}) {
    return appDb.managers.localConfig
        .filter((config) => config.configKey.equals(configKey.key) & config.subConfigKey.equals(subConfigKey))
        .delete()
        .then((value) => value > 0);
  }
}
