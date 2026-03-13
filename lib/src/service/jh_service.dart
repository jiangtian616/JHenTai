import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/path_service.dart';

import '../main.dart';
import 'log.dart';

abstract interface class JHLifeCircleBean {
  List<JHLifeCircleBean> get initDependencies;

  Future<void> initBean();

  void afterBeanReady();
}

mixin JHLifeCircleBeanErrorCatch {
  List<JHLifeCircleBean> get initDependencies => [pathService, log];

  Future<void> initBean() async {
    try {
      await doInitBean();
      log.debug('Init $runtimeType success');
    } catch (e, stack) {
      log.error('Init $runtimeType failed', e, stack);
    }
  }

  Future<void> afterBeanReady() async {
    try {
      await doAfterBeanReady();
      log.trace('$runtimeType afterBeanReady success');
    } catch (e, stack) {
      log.error('$runtimeType afterBeanReady failed', e, stack);
    }
  }

  /// Dispose resources. Called during app termination.
  /// Override doDisposeBean() to provide cleanup logic.
  void disposeBean() {
    try {
      doDisposeBean();
      log.trace('$runtimeType disposeBean success');
    } catch (e, stack) {
      log.error('$runtimeType disposeBean failed', e, stack);
    }
  }

  Future<void> doInitBean();

  Future<void> doAfterBeanReady();

  /// Override to dispose Workers, Timers, and other resources.
  /// Default implementation does nothing - override only if needed.
  void doDisposeBean() {}
}

mixin JHLifeCircleBeanWithConfigStorage {
  List<JHLifeCircleBean> get initDependencies => [pathService, log, localConfigService];

  ConfigEnum get configEnum;

  Future<void> initBean() async {
    try {
      await doInitBean();

      String? configString = await localConfigService.read(configKey: configEnum);
      if (configString != null) {
        applyBeanConfig(configString);
      }

      log.debug(configString == null ? 'Init $runtimeType config success with default' : 'Init $runtimeType config success');
    } catch (e, stack) {
      log.error('Init $runtimeType config failed', e, stack);
    }
  }

  void afterBeanReady() {
    try {
      doAfterBeanReady();
      log.debug('$runtimeType afterBeanReady success');
    } catch (e, stack) {
      log.error('$runtimeType afterBeanReady failed', e, stack);
    }
  }

  Future<void> refreshBean() async {
    try {
      String? configString = await localConfigService.read(configKey: configEnum);
      if (configString == null) {
        log.debug('Refresh $runtimeType config success with default');
      } else {
        applyBeanConfig(configString);
        log.debug('Refresh $runtimeType config success');
      }
    } catch (e, stack) {
      log.error('Refresh $runtimeType config failed', e, stack);
    }
  }

  Future<int> saveBeanConfig() {
    return localConfigService.write(configKey: configEnum, value: toConfigString());
  }

  Future<bool> clearBeanConfig() {
    log.debug('Clear $runtimeType config');
    return localConfigService.delete(configKey: configEnum);
  }

  void applyBeanConfig(String configString);

  Future<void> doInitBean();

  void doAfterBeanReady();

  String toConfigString();
}
