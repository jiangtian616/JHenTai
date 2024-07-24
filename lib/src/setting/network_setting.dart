import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/network/eh_request.dart';

import '../service/storage_service.dart';
import '../utils/log.dart';

enum JProxyType { system, http, socks5, socks4, direct }

class NetworkSetting {
  static Rx<Duration> pageCacheMaxAge = const Duration(hours: 1).obs;
  static RxBool enableDomainFronting = false.obs;
  static Rx<JProxyType> proxyType = JProxyType.system.obs;
  static RxString proxyAddress = 'localhost:1080'.obs;
  static RxnString proxyUsername = RxnString();
  static RxnString proxyPassword = RxnString();
  static RxInt connectTimeout = 6000.obs;
  static RxInt receiveTimeout = 6000.obs;

  static const Map<String, List<String>> host2IPs = {
    'e-hentai.org': ['104.20.18.168', '104.20.19.168', '172.67.2.238'],
    'exhentai.org': ['178.175.129.254', '178.175.132.20', '178.175.132.22', '178.175.128.252', '178.175.128.254', '178.175.129.252'],
    'upld.e-hentai.org': ['94.100.18.249', '94.100.18.247'],
    'api.e-hentai.org': ['178.162.147.246', '81.171.10.55', '178.162.139.18', '37.48.89.16'],
    'forums.e-hentai.org': ['104.20.18.168', '104.20.19.168', '172.67.2.238'],
  };

  static Set<String> get allHostAndIPs => host2IPs.keys.toSet()..addAll(allIPs);

  static Set<String> get allIPs => host2IPs.values.flattened.toSet();

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>(ConfigEnum.networkSetting.key);
    if (map != null) {
      _initFromMap(map);
      Log.debug('init NetworkSetting success', false);
    } else {
      Log.debug('init NetworkSetting success: default', false);
    }
  }

  static savePageCacheMaxAge(Duration pageCacheMaxAge) {
    Log.debug('savePageCacheMaxAge:$pageCacheMaxAge');
    NetworkSetting.pageCacheMaxAge.value = pageCacheMaxAge;
    _save();
  }

  static saveEnableDomainFronting(bool enableDomainFronting) {
    Log.debug('saveEnableDomainFronting:$enableDomainFronting');
    NetworkSetting.enableDomainFronting.value = enableDomainFronting;
    _save();
  }

  static saveProxy(JProxyType proxyType, String proxyAddress, String? proxyUsername, String? proxyPassword) {
    Log.debug('saveProxy:$proxyType,$proxyAddress,$proxyUsername,$proxyPassword');
    NetworkSetting.proxyType.value = proxyType;
    NetworkSetting.proxyAddress.value = proxyAddress;
    NetworkSetting.proxyUsername.value = proxyUsername;
    NetworkSetting.proxyPassword.value = proxyPassword;
    _save();
  }

  static saveConnectTimeout(int connectTimeout) {
    Log.debug('saveConnectTimeout:$connectTimeout');
    NetworkSetting.connectTimeout.value = connectTimeout;
    EHRequest.setConnectTimeout(connectTimeout);
    _save();
  }

  static saveReceiveTimeout(int receiveTimeout) {
    Log.debug('saveReceiveTimeout:$receiveTimeout');
    NetworkSetting.receiveTimeout.value = receiveTimeout;
    EHRequest.setReceiveTimeout(receiveTimeout);
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write(ConfigEnum.networkSetting.key, _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'pageCacheMaxAge': pageCacheMaxAge.value.inMilliseconds,
      'enableDomainFronting': enableDomainFronting.value,
      'proxyType': proxyType.value.index,
      'proxyAddress': proxyAddress.value,
      'proxyUsername': proxyUsername.value,
      'proxyPassword': proxyPassword.value,
      'connectTimeout': connectTimeout.value,
      'receiveTimeout': receiveTimeout.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    pageCacheMaxAge.value = Duration(milliseconds: map['pageCacheMaxAge'] ?? pageCacheMaxAge.value);
    enableDomainFronting.value = map['enableDomainFronting'] ?? enableDomainFronting.value;
    proxyType.value = JProxyType.values[map['proxyType'] ?? proxyType.value.index];
    proxyAddress.value = map['proxyAddress'] ?? proxyAddress.value;
    proxyUsername.value = map['proxyUsername'] ?? proxyUsername.value;
    proxyPassword.value = map['proxyPassword'] ?? proxyPassword.value;
    connectTimeout.value = map['connectTimeout'] ?? connectTimeout.value;
    receiveTimeout.value = map['receiveTimeout'] ?? receiveTimeout.value;
  }
}
