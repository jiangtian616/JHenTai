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
    'e-hentai.org': ['172.66.132.196', '172.66.140.62'],
    'exhentai.org': [
      '178.175.128.251',
      '178.175.128.252',
      '178.175.128.253',
      '178.175.128.254',
      '178.175.129.251',
      '178.175.129.252',
      '178.175.129.253',
      '178.175.129.254',
      '178.175.132.19',
      '178.175.132.20',
      '178.175.132.21',
      '178.175.132.22'
    ],
    'upld.e-hentai.org': ['95.211.208.236', '89.149.221.236'],
    'api.e-hentai.org': ['37.48.92.161', '212.7.202.51', '5.79.104.110', '37.48.81.204', '212.7.200.104'],
    'forums.e-hentai.org': ['172.66.132.196', '172.66.140.62'],
  };

  Set<String> get allHostAndIPs => host2IPs.keys.toSet()..addAll(allIPs);

  Set<String> get allIPs => host2IPs.values.flattened.toSet();

  @override
  ConfigEnum get configEnum => ConfigEnum.networkSetting;

  @override
  void applyBeanConfig(String configString) {
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
    await saveBeanConfig();
  }

  Future<void> saveCacheImageExpireDuration(Duration cacheImageExpireDuration) async {
    log.debug('saveCacheImageExpireDuration:$cacheImageExpireDuration');
    this.cacheImageExpireDuration.value = cacheImageExpireDuration;
    await saveBeanConfig();
  }

  Future<void> saveEnableDomainFronting(bool enableDomainFronting) async {
    log.debug('saveEnableDomainFronting:$enableDomainFronting');
    this.enableDomainFronting.value = enableDomainFronting;
    await saveBeanConfig();
  }

  Future<void> saveProxy(JProxyType proxyType, String proxyAddress, String? proxyUsername, String? proxyPassword) async {
    log.debug('saveProxy:$proxyType,$proxyAddress,$proxyUsername,$proxyPassword');
    this.proxyType.value = proxyType;
    this.proxyAddress.value = proxyAddress;
    this.proxyUsername.value = proxyUsername;
    this.proxyPassword.value = proxyPassword;
    await saveBeanConfig();
  }

  Future<void> saveConnectTimeout(int connectTimeout) async {
    log.debug('saveConnectTimeout:$connectTimeout');
    this.connectTimeout.value = connectTimeout;
    await saveBeanConfig();
  }

  Future<void> saveReceiveTimeout(int receiveTimeout) async {
    log.debug('saveReceiveTimeout:$receiveTimeout');
    this.receiveTimeout.value = receiveTimeout;
    await saveBeanConfig();
  }
}

enum JProxyType { system, http, socks5, socks4, direct }
