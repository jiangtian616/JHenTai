import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/service/log.dart';

import '../service/jh_service.dart';

EHSetting ehSetting = EHSetting();

class EHSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxString site = 'EH'.obs;
  RxBool redirect2Eh = true.obs;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..add(userSetting);

  @override
  ConfigEnum get configEnum => ConfigEnum.EHSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    site.value = map['site'];
    redirect2Eh.value = map['redirect2Eh'] ?? redirect2Eh.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'site': site.value,
      'redirect2Eh': redirect2Eh.value,
    });
  }

  @override
  Future<void> doInitBean() async {
    /// listen to logout
    ever(userSetting.ipbMemberId, (v) {
      if (!userSetting.hasLoggedIn()) {
        site.value = 'EH';
        clearBeanConfig();
      }
    });
  }

  @override
  void doAfterBeanReady() {}

  Future<void> saveSite(String site) async {
    log.debug('saveSite:$site');
    this.site.value = site;
    await saveBeanConfig();
  }

  Future<void> saveRedirect2Eh(bool redirect2Eh) async {
    log.debug('saveRedirect2Eh:$redirect2Eh');
    this.redirect2Eh.value = redirect2Eh;
    await saveBeanConfig();
  }
}
