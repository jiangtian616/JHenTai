import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/network/eh_request.dart';

import '../service/jh_service.dart';
import '../service/log.dart';

NetworkSetting networkSetting = NetworkSetting();

class NetworkSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  Rx<Duration> pageCacheMaxAge = const Duration(hours: 1).obs;
  Rx<Duration> cacheImageExpireDuration = const Duration(days: 7).obs;
  RxBool enableDomainFronting = false.obs;
  Rx<JProxyType> proxyType = JProxyType.system.obs;
  RxString proxyAddress = 'localhost:1080'.obs;
  RxnString proxyUsername = RxnString();
  RxnString proxyPassword = RxnString();
  RxInt connectTimeout = 6000.obs;
  RxInt receiveTimeout = 6000.obs;

  static const Map<String, List<String>> host2IPs = {
    'e-hentai.org': ['104.20.18.168', '104.20.19.168', '172.67.2.238'],
    'exhentai.org': ['178.175.129.254', '178.175.132.20', '178.175.132.22', '178.175.128.252', '178.175.128.254', '178.175.129.252'],
    'upld.e-hentai.org': ['94.100.18.249', '94.100.18.247'],
    'api.e-hentai.org': ['178.162.147.246', '81.171.10.55', '178.162.139.18', '37.48.89.16'],
    'forums.e-hentai.org': ['104.20.18.168', '104.20.19.168', '172.67.2.238'],
  };

  Set<String> get allHostAndIPs => host2IPs.keys.toSet()..addAll(allIPs);

  Set<String> get allIPs => host2IPs.values.flattened.toSet();

  @override
  ConfigEnum get configEnum => ConfigEnum.networkSetting;

  @override
  void applyConfig(String configString) {
    Map map = jsonDecode(configString);

    pageCacheMaxAge.value = Duration(milliseconds: map['pageCacheMaxAge'] ?? pageCacheMaxAge.value.inMilliseconds);
    cacheImageExpireDuration.value = Duration(milliseconds: map['cacheImageExpireDuration'] ?? cacheImageExpireDuration.value.inMilliseconds);
    enableDomainFronting.value = map['enableDomainFronting'] ?? enableDomainFronting.value;
    proxyType.value = JProxyType.values[map['proxyType'] ?? proxyType.value.index];
    proxyAddress.value = map['proxyAddress'] ?? proxyAddress.value;
    proxyUsername.value = map['proxyUsername'] ?? proxyUsername.value;
    proxyPassword.value = map['proxyPassword'] ?? proxyPassword.value;
    connectTimeout.value = map['connectTimeout'] ?? connectTimeout.value;
    receiveTimeout.value = map['receiveTimeout'] ?? receiveTimeout.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'pageCacheMaxAge': pageCacheMaxAge.value.inMilliseconds,
      'cacheImageExpireDuration': cacheImageExpireDuration.value.inMilliseconds,
      'enableDomainFronting': enableDomainFronting.value,
      'proxyType': proxyType.value.index,
      'proxyAddress': proxyAddress.value,
      'proxyUsername': proxyUsername.value,
      'proxyPassword': proxyPassword.value,
      'connectTimeout': connectTimeout.value,
      'receiveTimeout': receiveTimeout.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> savePageCacheMaxAge(Duration pageCacheMaxAge) async {
    log.debug('savePageCacheMaxAge:$pageCacheMaxAge');
    this.pageCacheMaxAge.value = pageCacheMaxAge;
    await save();
  }

  Future<void> saveCacheImageExpireDuration(Duration cacheImageExpireDuration) async {
    log.debug('saveCacheImageExpireDuration:$cacheImageExpireDuration');
    this.cacheImageExpireDuration.value = cacheImageExpireDuration;
    await save();
  }

  Future<void> saveEnableDomainFronting(bool enableDomainFronting) async {
    log.debug('saveEnableDomainFronting:$enableDomainFronting');
    this.enableDomainFronting.value = enableDomainFronting;
    await save();
  }

  Future<void> saveProxy(JProxyType proxyType, String proxyAddress, String? proxyUsername, String? proxyPassword) async {
    log.debug('saveProxy:$proxyType,$proxyAddress,$proxyUsername,$proxyPassword');
    this.proxyType.value = proxyType;
    this.proxyAddress.value = proxyAddress;
    this.proxyUsername.value = proxyUsername;
    this.proxyPassword.value = proxyPassword;
    await save();
  }

  Future<void> saveConnectTimeout(int connectTimeout) async {
    log.debug('saveConnectTimeout:$connectTimeout');
    this.connectTimeout.value = connectTimeout;
    await save();
  }

  Future<void> saveReceiveTimeout(int receiveTimeout) async {
    log.debug('saveReceiveTimeout:$receiveTimeout');
    this.receiveTimeout.value = receiveTimeout;
    await save();
  }
}

enum JProxyType { system, http, socks5, socks4, direct }
