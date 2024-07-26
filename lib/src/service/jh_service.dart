import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/path_service.dart';

import '../main.dart';
import 'log.dart';

abstract interface class JHLifeCircleBean {
  JHLifeCircleBean() {
    lifeCircleBeans.add(this);
  }

  List<JHLifeCircleBean> get initDependencies;

  Future<void> onInit();

  void onReady();
}

mixin JHLifeCircleBeanErrorCatch {
  List<JHLifeCircleBean> get initDependencies => [pathService, log];

  Future<void> onInit() async {
    try {
      await doOnInit();
      log.debug('Init $runtimeType success');
    } catch (e, stack) {
      log.error('Init $runtimeType failed', e, stack);
    }
  }

  void onReady() {
    try {
      doOnReady();
      log.debug('OnReady $runtimeType success');
    } catch (e, stack) {
      log.error('OnReady $runtimeType failed', e, stack);
    }
  }

  Future<void> doOnInit();

  void doOnReady();
}

mixin JHLifeCircleBeanWithConfigStorage {
  List<JHLifeCircleBean> get initDependencies => [pathService, log, localConfigService];

  ConfigEnum get configEnum;

  Future<void> onInit() async {
    try {
      String? configString = await localConfigService.read(configKey: configEnum);
      if (configString != null) {
        applyConfig(configString);
      }
      await doOnInit();
      log.debug(configString == null ? 'Init $runtimeType config success with default' : 'Init $runtimeType config success');
    } catch (e, stack) {
      log.error('Init $runtimeType config failed', e, stack);
    }
  }

  void onReady() {
    try {
      doOnReady();
      log.debug('OnReady $runtimeType success');
    } catch (e, stack) {
      log.error('OnReady $runtimeType failed', e, stack);
    }
  }

  Future<void> onRefresh() async {
    try {
      String? configString = await localConfigService.read(configKey: configEnum);
      if (configString == null) {
        log.debug('Refresh $runtimeType config success with default');
      } else {
        applyConfig(configString);
        log.debug('Refresh $runtimeType config success');
      }
    } catch (e, stack) {
      log.error('Refresh $runtimeType config failed', e, stack);
    }
  }

  Future<bool> save() {
    return localConfigService.write(configKey: configEnum, value: toConfigString());
  }

  Future<bool> clear() {
    log.debug('Clear $runtimeType config');
    return localConfigService.delete(configKey: configEnum);
  }

  void applyConfig(String configString);

  Future<void> doOnInit();

  void doOnReady();

  String toConfigString();
}
