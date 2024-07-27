import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:retry/retry.dart';

import '../exception/eh_site_exception.dart';
import '../model/profile.dart';
import '../service/jh_service.dart';
import '../service/log.dart';
import 'eh_setting.dart';

SiteSetting siteSetting = SiteSetting();

class SiteSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  static RxBool preferJapaneseTitle = true.obs;

  static Rx<FrontPageDisplayType> frontPageDisplayType = FrontPageDisplayType.compact.obs;

  static RxBool isLargeThumbnail = false.obs;
  static RxInt thumbnailRows = 4.obs;
  static RxInt thumbnailsCountPerPage = 40.obs;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..addAll([userSetting, ehSetting]);

  @override
  ConfigEnum get configEnum => ConfigEnum.siteSetting;

  @override
  void applyConfig(String configString) {
    Map map = jsonDecode(configString);

    preferJapaneseTitle.value = map['preferJapaneseTitle'] ?? true;
    frontPageDisplayType.value = FrontPageDisplayType.values[map['frontPageDisplayType']];
    isLargeThumbnail.value = map['isLargeThumbnail'];
    thumbnailRows.value = map['thumbnailRows'];
    thumbnailsCountPerPage.value = map['thumbnailsCountPerPage'];
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'preferJapaneseTitle': preferJapaneseTitle.value,
      'frontPageDisplayType': frontPageDisplayType.value.index,
      'isLargeThumbnail': isLargeThumbnail.value,
      'thumbnailRows': thumbnailRows.value,
      'thumbnailsCountPerPage': thumbnailsCountPerPage.value,
    });
  }

  @override
  Future<void> doOnInit() async {
    /// listen to login and logout
    ever(userSetting.ipbMemberId, (v) {
      if (userSetting.hasLoggedIn()) {
        fetchDataFromEH();
      } else {
        preferJapaneseTitle.value = true;
        frontPageDisplayType.value = FrontPageDisplayType.compact;
        isLargeThumbnail.value = false;
        thumbnailRows.value = 4;
        thumbnailsCountPerPage.value = 40;
        super.clear();
      }
    });

    ever(ehSetting.site, (_) {
      fetchDataFromEH();
    });
  }

  @override
  void doOnReady() {
    fetchDataFromEH();
  }

  Future<void> fetchDataFromEH() async {
    if (!userSetting.hasLoggedIn()) {
      return;
    }

    log.info('Fetch site setting from EH');

    ({
      bool preferJapaneseTitle,
      List<Profile> profiles,
      FrontPageDisplayType frontPageDisplayType,
      bool isLargeThumbnail,
      int thumbnailRows,
    }) settings;
    try {
      settings = await retry(
        () => ehRequest.requestSettingPage(EHSpiderParser.settingPage2SiteSetting),
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } on DioException catch (e) {
      log.error('Fetch site setting from EH fail', e.errorMsg);
      return;
    } on EHSiteException catch (e) {
      log.error('Fetch site setting from EH fail', e.message);
      return;
    }

    log.info('Fetch site setting from EH success');

    preferJapaneseTitle.value = settings.preferJapaneseTitle;
    frontPageDisplayType.value = settings.frontPageDisplayType;
    isLargeThumbnail.value = settings.isLargeThumbnail;
    thumbnailRows.value = settings.thumbnailRows;
    thumbnailsCountPerPage.value = thumbnailRows.value * (isLargeThumbnail.value ? 5 : 10);
    await save();
  }
}

enum FrontPageDisplayType {
  minimal,
  minimalPlus,
  compact,
  extended,
  thumbnail,
}
