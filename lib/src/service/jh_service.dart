import '../main.dart';
import '../utils/log.dart';

abstract interface class JHLifeCircleBean {
  JHLifeCircleBean() {
    lifeCircleBeans.add(this);
  }

  List<JHLifeCircleBean> get initDependencies;

  Future<void> init();

  void onReady();

  Future<void> onRefresh();
}

mixin JHLifeCircleBeanErrorCatch {
  List<JHLifeCircleBean> get initDependencies => [];

  Future<void> init() async {
    try {
      await doInit();
      Log.debug('Init $runtimeType success');
    } catch (e, stack) {
      Log.error('Init $runtimeType failed', e, stack);
    }
  }

  Future<void> doInit() async {}

  void onReady() {
    try {
      doOnReady();
      Log.debug('OnReady $runtimeType success');
    } catch (e, stack) {
      Log.error('OnReady $runtimeType failed', e, stack);
    }
  }

  void doOnReady() {}

  Future<void> onRefresh() async {}
}
