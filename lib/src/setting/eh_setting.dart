import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:retry/retry.dart';

import '../exception/eh_site_exception.dart';
import '../service/jh_service.dart';
import '../utils/eh_spider_parser.dart';

EHSetting ehSetting = EHSetting();

class EHSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxString site = 'EH'.obs;
  RxBool redirect2Eh = true.obs;
  Rx<LoadingState> refreshState = LoadingState.idle.obs;
  RxInt currentConsumption = (-1).obs;
  RxInt totalLimit = 5000.obs;
  RxInt resetCost = (-1).obs;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..add(userSetting);

  @override
  ConfigEnum get configEnum => ConfigEnum.EHSetting;

  @override
  void applyConfig(String configString) {
    Map map = jsonDecode(configString);

    site.value = map['site'];
    redirect2Eh.value = map['redirect2Eh'] ?? redirect2Eh.value;
    totalLimit.value = map['totalLimit'];
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'site': site.value,
      'redirect2Eh': redirect2Eh.value,
      'totalLimit': totalLimit.value,
    });
  }

  @override
  Future<void> doOnInit() async {
    /// listen to logout
    ever(userSetting.ipbMemberId, (v) {
      if (userSetting.hasLoggedIn()) {
        fetchDataFromEH();
      } else {
        site.value = 'EH';
        currentConsumption.value = -1;
        clear();
      }
    });
  }

  @override
  void doOnReady() {
    fetchDataFromEH();
  }

  void fetchDataFromEH() async {
    /// only refresh when logged in
    if (!userSetting.hasLoggedIn()) {
      return;
    }

    log.info('Fetch eh setting from EH');

    refreshState.value = LoadingState.loading;
    Map<String, int> map = {};
    try {
      await retry(
        () async {
          map = await EHRequest.requestHomePage(parser: EHSpiderParser.homePage2ImageLimit);
        },
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } on DioException catch (e) {
      log.error('Fetch eh setting from EH fail', e.errorMsg);
      refreshState.value = LoadingState.error;
      return;
    } on EHSiteException catch (e) {
      log.error('Fetch eh setting from EH fail', e.message);
      refreshState.value = LoadingState.error;
      return;
    }

    log.info('Fetch eh setting from EH success');

    currentConsumption.value = map['currentConsumption']!;
    totalLimit.value = map['totalLimit']!;
    resetCost.value = map['resetCost']!;
    refreshState.value = LoadingState.idle;
    await save();
  }

  Future<void> saveRedirect2Eh(bool redirect2Eh) async {
    log.debug('saveRedirect2Eh:$redirect2Eh');
    this.redirect2Eh.value = redirect2Eh;
    await save();
  }

  Future<void> saveSite(String site) async {
    log.debug('saveSite:$site');
    this.site.value = site;
    await save();

    EHRequest.storeEHCookies([Cookie('sp', site)]);

    siteSetting.fetchDataFromEH();
  }
}
