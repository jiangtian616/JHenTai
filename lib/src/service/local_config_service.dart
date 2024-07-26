import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/jh_service.dart';

import '../database/database.dart';

LocalConfigService localConfigService = LocalConfigService();

class LocalConfigService implements JHLifeCircleBean {
  static const String defaultSubConfigKey = '';

  @override
  Future<void> onInit() async {}

  @override
  void onReady() async {}

  @override
  Future<void> onRefresh() async {}

  Future<bool> write({required ConfigEnum configKey, String subConfigKey = defaultSubConfigKey, required String value}) {
    return appDb.managers.localConfig.replace(
      LocalConfigCompanion.insert(configKey: configKey.key, subConfigKey: subConfigKey, value: value),
    );
  }

  Future<String?> read({required ConfigEnum configKey, String subConfigKey = defaultSubConfigKey}) {
    return appDb.managers.localConfig
        .filter((config) => config.configKey.equals(configKey.key) & config.subConfigKey.equals(subConfigKey))
        .getSingleOrNull()
        .then((value) => value?.value);
  }

  Future<bool> delete({required ConfigEnum configKey, String subConfigKey = defaultSubConfigKey}) {
    return appDb.managers.localConfig.filter((config) => config.configKey.equals(configKey.key) & config.subConfigKey.equals(subConfigKey)).delete().then((value) => value > 0);
  }
}
