import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';

import '../service/jh_service.dart';
import '../service/log.dart';

NetworkSetting networkSetting = NetworkSetting();

class NetworkSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  /// Cache config version. v2 merged the separate page/image cache durations
  /// into the smart cache switch and its retention period. v3 adds the
  /// optional space limit and eviction policy.
  static const int cacheConfigVersion = 3;

  /// Fallback retention when smart cache is off: pages stay for a short time,
  /// images keep the previous default. Users no longer configure these.
  static const Duration fallbackPageCacheMaxAge = Duration(hours: 1);
  static const Duration fallbackImageCacheExpireDuration = Duration(days: 7);

  /// Smart cache: when enabled, pages and images you viewed are kept for
  /// [smartCacheRetention] so revisiting them doesn't re-download. A zero
  /// duration is the persisted sentinel for no time-based expiry.
  RxBool enableSmartCache = true.obs;
  Rx<Duration> smartCacheRetention = const Duration(days: 7).obs;

  bool get isSmartCacheRetentionUnlimited =>
      enableSmartCache.isTrue && smartCacheRetention.value == Duration.zero;

  /// 0 means no space limit.
  RxInt smartCacheMaxSizeMB = 0.obs;
  Rx<SmartCacheEvictPolicy> smartCacheEvictPolicy =
      SmartCacheEvictPolicy.addedDate.obs;

  /// The retention actually in effect. When smart cache is on it governs both
  /// the page cache and the image cache; otherwise fixed short-lived defaults
  /// are used.
  Duration get effectivePageCacheMaxAge =>
      enableSmartCache.isTrue
          ? smartCacheRetention.value
          : fallbackPageCacheMaxAge;
  Duration get effectiveCacheImageExpireDuration =>
      enableSmartCache.isTrue
          ? smartCacheRetention.value
          : fallbackImageCacheExpireDuration;
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
      '178.175.132.22',
    ],
    'upld.e-hentai.org': ['95.211.208.236', '89.149.221.236'],
    'api.e-hentai.org': [
      '37.48.92.161',
      '212.7.202.51',
      '5.79.104.110',
      '37.48.81.204',
      '212.7.200.104',
    ],
    'forums.e-hentai.org': ['172.66.132.196', '172.66.140.62'],
  };

  Set<String> get allHostAndIPs => host2IPs.keys.toSet()..addAll(allIPs);

  Set<String> get allIPs => host2IPs.values.flattened.toSet();

  @override
  ConfigEnum get configEnum => ConfigEnum.networkSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    final int version = map['cacheConfigVersion'] ?? 1;
    enableSmartCache.value =
        version < cacheConfigVersion
            ? true
            : (map['enableSmartCache'] ?? enableSmartCache.value);
    smartCacheRetention.value = Duration(
      milliseconds:
          map['smartCacheRetention'] ??
          smartCacheRetention.value.inMilliseconds,
    );
    smartCacheMaxSizeMB.value =
        version < cacheConfigVersion
            ? 0
            : (map['smartCacheMaxSizeMB'] ?? smartCacheMaxSizeMB.value);
    smartCacheEvictPolicy.value =
        version < cacheConfigVersion
            ? SmartCacheEvictPolicy.addedDate
            : SmartCacheEvictPolicy.values[map['smartCacheEvictPolicy'] ??
                smartCacheEvictPolicy.value.index];
    enableDomainFronting.value =
        map['enableDomainFronting'] ?? enableDomainFronting.value;
    proxyType.value =
        JProxyType.values[map['proxyType'] ?? proxyType.value.index];
    proxyAddress.value = map['proxyAddress'] ?? proxyAddress.value;
    proxyUsername.value = map['proxyUsername'] ?? proxyUsername.value;
    proxyPassword.value = map['proxyPassword'] ?? proxyPassword.value;
    connectTimeout.value = map['connectTimeout'] ?? connectTimeout.value;
    receiveTimeout.value = map['receiveTimeout'] ?? receiveTimeout.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'cacheConfigVersion': cacheConfigVersion,
      'enableSmartCache': enableSmartCache.value,
      'smartCacheRetention': smartCacheRetention.value.inMilliseconds,
      'smartCacheMaxSizeMB': smartCacheMaxSizeMB.value,
      'smartCacheEvictPolicy': smartCacheEvictPolicy.value.index,
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

  Future<void> saveEnableSmartCache(bool value) async {
    log.debug('saveEnableSmartCache:$value');
    enableSmartCache.value = value;
    await saveBeanConfig();
  }

  Future<void> saveSmartCacheRetention(Duration value) async {
    log.debug('saveSmartCacheRetention:$value');
    smartCacheRetention.value = value;
    await saveBeanConfig();
  }

  Future<void> saveSmartCacheMaxSizeMB(int value) async {
    log.debug('saveSmartCacheMaxSizeMB:$value');
    smartCacheMaxSizeMB.value = value;
    await saveBeanConfig();
  }

  Future<void> saveSmartCacheEvictPolicy(SmartCacheEvictPolicy value) async {
    log.debug('saveSmartCacheEvictPolicy:$value');
    smartCacheEvictPolicy.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableDomainFronting(bool enableDomainFronting) async {
    log.debug('saveEnableDomainFronting:$enableDomainFronting');
    this.enableDomainFronting.value = enableDomainFronting;
    await saveBeanConfig();
  }

  Future<void> saveProxy(
    JProxyType proxyType,
    String proxyAddress,
    String? proxyUsername,
    String? proxyPassword,
  ) async {
    log.debug(
      'saveProxy:$proxyType,$proxyAddress,$proxyUsername,$proxyPassword',
    );
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

enum SmartCacheEvictPolicy { addedDate, usageFrequency }
