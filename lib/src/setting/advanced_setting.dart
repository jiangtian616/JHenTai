import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../service/jh_service.dart';

AdvancedSetting advancedSetting = AdvancedSetting();

class AdvancedSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  RxBool enableLogging = true.obs;
  RxBool enableVerboseLogging = kDebugMode.obs;
  RxBool enableCheckUpdate = true.obs;
  RxBool enableCheckClipboard = true.obs;
  RxBool inNoImageMode = false.obs;
  RxBool enableLanSharing = true.obs;

  /// When true, the download page's "Local" tab shows the LAN gallery directory
  /// (galleries on connected trusted devices) instead of local files.
  RxBool lanLocalTabAsLan = false.obs;

  /// When true (desktop only), closing the window keeps the app resident in the
  /// background (system tray / menu bar) so the LAN sharing server stays up.
  RxBool lanStayResident = false.obs;

  /// Server mode: this device acts as the storage/cache for connected devices.
  /// Images peers browse are downloaded here and cached on THIS device, so the
  /// peer keeps almost no cache of its own.
  RxBool lanServerMode = false.obs;

  /// Whether this device publishes a LAN server endpoint. This is intentionally
  /// desktop-only; mobile can remain a foreground client without claiming a
  /// resident server.
  RxBool lanActAsServer = false.obs;

  /// Active broadcast: when this device discovers a new, untrusted LAN device
  /// it proactively sends it a pairing request instead of waiting for the
  /// user to trust it manually. The peer still decides whether to accept.
  RxBool lanActiveBroadcast = false.obs;

  /// Empty means no fixed server was selected. A non-empty value is the only
  /// peer eligible for automatic LAN gallery/image requests.
  RxString lanPreferredServerDeviceId = ''.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.advancedSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    enableLogging.value = map['enableLogging'];
    enableVerboseLogging.value =
        map['enableVerboseLogging'] ?? enableVerboseLogging.value;
    enableCheckUpdate.value =
        map['enableCheckUpdate'] ?? enableCheckUpdate.value;
    enableCheckClipboard.value =
        map['enableCheckClipboard'] ?? enableCheckClipboard.value;
    inNoImageMode.value = map['inNoImageMode'] ?? inNoImageMode.value;
    enableLanSharing.value = map['enableLanSharing'] ?? enableLanSharing.value;
    lanLocalTabAsLan.value = map['lanLocalTabAsLan'] ?? lanLocalTabAsLan.value;
    lanStayResident.value = map['lanStayResident'] ?? lanStayResident.value;
    final bool mergedServerMode =
        map['lanServerMode'] == true || map['lanActAsServer'] == true;
    lanServerMode.value = mergedServerMode;
    lanActAsServer.value = mergedServerMode;
    lanPreferredServerDeviceId.value =
        map['lanPreferredServerDeviceId'] as String? ??
        lanPreferredServerDeviceId.value;
    lanActiveBroadcast.value =
        map['lanActiveBroadcast'] ?? lanActiveBroadcast.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'enableLogging': enableLogging.value,
      'enableVerboseLogging': enableVerboseLogging.value,
      'enableCheckUpdate': enableCheckUpdate.value,
      'enableCheckClipboard': enableCheckClipboard.value,
      'inNoImageMode': inNoImageMode.value,
      'enableLanSharing': enableLanSharing.value,
      'lanLocalTabAsLan': lanLocalTabAsLan.value,
      'lanStayResident': lanStayResident.value,
      'lanServerMode': lanServerMode.value,
      'lanActAsServer': lanActAsServer.value,
      'lanPreferredServerDeviceId': lanPreferredServerDeviceId.value,
      'lanActiveBroadcast': lanActiveBroadcast.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveEnableLogging(bool enableLogging) async {
    log.debug('saveEnableLogging:$enableLogging');
    this.enableLogging.value = enableLogging;
    await saveBeanConfig();
  }

  Future<void> saveEnableVerboseLogging(bool enableVerboseLogging) async {
    log.debug('saveEnableVerboseLogging:$enableVerboseLogging');
    this.enableVerboseLogging.value = enableVerboseLogging;
    await saveBeanConfig();
  }

  Future<void> saveEnableCheckUpdate(bool enableCheckUpdate) async {
    log.debug('saveEnableCheckUpdate:$enableCheckUpdate');
    this.enableCheckUpdate.value = enableCheckUpdate;
    await saveBeanConfig();
  }

  Future<void> saveEnableCheckClipboard(bool enableCheckClipboard) async {
    log.debug('saveEnableCheckClipboard:$enableCheckClipboard');
    this.enableCheckClipboard.value = enableCheckClipboard;
    await saveBeanConfig();
  }

  Future<void> saveInNoImageMode(bool inNoImageMode) async {
    log.debug('saveInNoImageMode:$inNoImageMode');
    this.inNoImageMode.value = inNoImageMode;
    await saveBeanConfig();
  }

  Future<void> saveLanLocalTabAsLan(bool value) async {
    log.debug('saveLanLocalTabAsLan:$value');
    lanLocalTabAsLan.value = value;
    await saveBeanConfig();
  }

  Future<void> saveLanStayResident(bool value) async {
    log.debug('saveLanStayResident:$value');
    lanStayResident.value = value;
    await saveBeanConfig();
  }

  Future<void> saveLanServerMode(bool value) async {
    log.debug('saveLanServerMode:$value');
    lanServerMode.value = value;
    lanActAsServer.value = value;
    await saveBeanConfig();
  }

  /// Compatibility entry point for older callers. Publishing a LAN endpoint
  /// and providing its storage/cache role are now one user-facing mode.
  Future<void> saveLanActAsServer(bool value) async {
    await saveLanServerMode(value);
  }

  Future<void> saveLanActiveBroadcast(bool value) async {
    log.debug('saveLanActiveBroadcast:$value');
    lanActiveBroadcast.value = value;
    await saveBeanConfig();
  }

  Future<void> saveLanPreferredServerDeviceId(String value) async {
    log.debug('saveLanPreferredServerDeviceId:$value');
    lanPreferredServerDeviceId.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableLanSharing(bool enableLanSharing) async {
    log.debug('saveEnableLanSharing:$enableLanSharing');
    this.enableLanSharing.value = enableLanSharing;
    await saveBeanConfig();
  }
}
