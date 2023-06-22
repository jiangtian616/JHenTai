import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/preference_setting.dart';

import '../service/storage_service.dart';
import '../utils/log.dart';

enum ProxyType { system, http, socks5, socks4, direct }

class NetworkSetting {
  static Rx<Duration> pageCacheMaxAge = const Duration(hours: 1).obs;
  static RxBool enableDomainFronting =
      PreferenceSetting.locale.value.languageCode == 'zh' && PreferenceSetting.locale.value.countryCode == 'CN' ? true.obs : false.obs;
  static Rx<ProxyType> proxyType = ProxyType.system.obs;
  static RxString proxyAddress = 'localhost:1080'.obs;
  static RxnString proxyUsername = RxnString();
  static RxnString proxyPassword = RxnString();
  static RxInt connectTimeout = 6000.obs;
  static RxInt receiveTimeout = 6000.obs;

  static RxString eHentaiIP = '172.67.0.127'.obs;
  static RxString exHentaiIP = '178.175.129.254'.obs;
  static RxString upldIP = '94.100.18.249'.obs;
  static RxString apiIP = '178.162.147.246'.obs;
  static RxString forumsIP = '94.100.18.243'.obs;

  static const Map<String, List<String>> host2IPs = {
    'e-hentai.org': ['172.67.0.127', '104.20.135.21', '104.20.134.21'],
    'exhentai.org': ['178.175.129.254', '178.175.132.20', '178.175.132.22', '178.175.128.252', '178.175.128.254', '178.175.129.252'],
    'upld.e-hentai.org': ['94.100.18.249', '94.100.18.247'],
    'api.e-hentai.org': ['178.162.147.246', '81.171.10.55', '178.162.139.18', '37.48.89.16'],
    'forums.e-hentai.org': ['94.100.18.243', '104.20.134.21', '104.20.135.21', '172.67.0.127'],
  };

  static Map<String, String> get currentHost2IP => {
        'e-hentai.org': eHentaiIP.value,
        'exhentai.org': exHentaiIP.value,
        'upld.e-hentai.org': upldIP.value,
        'api.e-hentai.org': apiIP.value,
        'forums.e-hentai.org': forumsIP.value,
      };

  static Set<String> get allHostAndIPs => host2IPs.keys.toSet()..addAll(allIPs);

  static Set<String> get allIPs => host2IPs.values.flattened.toSet()..addAll(currentHost2IP.values);

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('networkSetting');
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

  static saveProxy(ProxyType proxyType, String proxyAddress, String? proxyUsername, String? proxyPassword) {
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
    _save();
  }

  static saveReceiveTimeout(int receiveTimeout) {
    Log.debug('saveReceiveTimeout:$receiveTimeout');
    NetworkSetting.receiveTimeout.value = receiveTimeout;
    _save();
  }

  static saveEHentaiIP(String ip) {
    Log.debug('saveEHentaiIP:$ip');
    NetworkSetting.eHentaiIP.value = ip;
    _save();
  }

  static saveEXHentaiIP(String ip) {
    Log.debug('saveEXHentaiIP:$ip');
    NetworkSetting.exHentaiIP.value = ip;
    _save();
  }

  static saveUpldIP(String ip) {
    Log.debug('saveUpldIP:$proxyAddress');
    NetworkSetting.upldIP.value = ip;
    _save();
  }

  static saveApiIP(String ip) {
    Log.debug('saveApiIP:$ip');
    NetworkSetting.apiIP.value = ip;
    _save();
  }

  static saveForumsIP(String ip) {
    Log.debug('saveForumsIP:$ip');
    NetworkSetting.forumsIP.value = ip;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('networkSetting', _toMap());
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
      'eHentaiIP': eHentaiIP.value,
      'exHentaiIP': exHentaiIP.value,
      'upldIP': upldIP.value,
      'apiIP': apiIP.value,
      'forumsIP': forumsIP.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    pageCacheMaxAge.value = Duration(milliseconds: map['pageCacheMaxAge'] ?? pageCacheMaxAge.value);
    enableDomainFronting.value = map['enableDomainFronting'] ?? enableDomainFronting.value;
    proxyType.value = ProxyType.values[map['proxyType'] ?? proxyType.value.index];
    proxyAddress.value = map['proxyAddress'] ?? proxyAddress.value;
    proxyUsername.value = map['proxyUsername'] ?? proxyUsername.value;
    proxyPassword.value = map['proxyPassword'] ?? proxyPassword.value;
    connectTimeout.value = map['connectTimeout'] ?? connectTimeout.value;
    receiveTimeout.value = map['receiveTimeout'] ?? receiveTimeout.value;
    eHentaiIP.value = map['eHentaiIP'] ?? eHentaiIP.value;
    exHentaiIP.value = map['exHentaiIP'] ?? exHentaiIP.value;
    upldIP.value = map['upldIP'] ?? upldIP.value;
    apiIP.value = map['apiIP'] ?? apiIP.value;
    forumsIP.value = map['forumsIP'] ?? forumsIP.value;
  }
}
