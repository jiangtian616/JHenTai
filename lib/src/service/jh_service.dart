import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/local_config_service.dart';

import '../main.dart';
import '../utils/log.dart';

abstract interface class JHLifeCircleBean {
  JHLifeCircleBean() {
    lifeCircleBeans.add(this);
  }

  List<JHLifeCircleBean> get initDependencies;

  Future<void> onInit();

  void onReady();
}

mixin JHLifeCircleBeanErrorCatch {
  List<JHLifeCircleBean> get initDependencies => [];

  Future<void> onInit() async {
    try {
      await doOnInit();
      Log.debug('Init $runtimeType success');
    } catch (e, stack) {
      Log.error('Init $runtimeType failed', e, stack);
    }
  }

  void onReady() {
    try {
      doOnReady();
      Log.debug('OnReady $runtimeType success');
    } catch (e, stack) {
      Log.error('OnReady $runtimeType failed', e, stack);
    }
  }

  Future<void> doOnInit();

  void doOnReady();
}

mixin JHLifeCircleBeanWithConfigStorage {
  List<JHLifeCircleBean> get initDependencies => [localConfigService];

  ConfigEnum get configEnum;

  Future<void> onInit() async {
    try {
      String? configString = await localConfigService.read(configKey: configEnum);
      if (configString != null) {
        applyConfig(configString);
      }
      await doOnInit();
      Log.debug(configString == null ? 'Init $runtimeType success with default' : 'Init $runtimeType success');
    } catch (e, stack) {
      Log.error('Init $runtimeType failed', e, stack);
    }
  }

  void onReady() {
    try {
      doOnReady();
      Log.debug('OnReady $runtimeType success');
    } catch (e, stack) {
      Log.error('OnReady $runtimeType failed', e, stack);
    }
  }

  Future<void> onRefresh() async {
    try {
      String? configString = await localConfigService.read(configKey: configEnum);
      if (configString == null) {
        Log.debug('Refresh $runtimeType success with default');
      } else {
        applyConfig(configString);
        Log.debug('Refresh $runtimeType success');
      }
    } catch (e, stack) {
      Log.error('Refresh $runtimeType failed', e, stack);
    }
  }

  Future<bool> save() {
    return localConfigService.write(configKey: configEnum, value: toConfigString());
  }

  void applyConfig(String configString);

  Future<void> doOnInit();

  void doOnReady();

  String toConfigString();
}
