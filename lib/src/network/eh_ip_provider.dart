import 'package:jhentai/src/service/log.dart';

abstract interface class EHIpProvider {
  bool supports(String host);

  String nextIP(String host);

  void addUnavailableIp(String host, String ip);
}

class RoundRobinIpProvider implements EHIpProvider {
  final Map<String, List<String>> _host2Ips = {};
  final Map<String, int> _host2Index = {};
  final Map<String, Map<String, DateTime>> _host2UnavailableIps = {};

  /// Unavailable duration (after this, IP is considered available again)
  static const Duration _unavailableDuration = Duration(minutes: 5);

  RoundRobinIpProvider(Map<String, List<String>> host2Ips) {
    _host2Ips.addAll(host2Ips);
    _host2Ips.forEach((host, ips) {
      _host2Index[host] = 0;
    });
  }

  @override
  bool supports(String host) {
    return _host2Ips.containsKey(host) && _host2Ips[host]!.isNotEmpty;
  }

  @override
  String nextIP(String host) {
    if (!supports(host)) {
      return host;
    }

    int index = _host2Index[host]!;
    do {
      if (_host2UnavailableIps.containsKey(host) &&
          _host2UnavailableIps[host]!.containsKey(_host2Ips[host]![index]) &&
          DateTime.now().difference(_host2UnavailableIps[host]![_host2Ips[host]![index]]!).inMinutes < 5) {
        index = (index + 1) % _host2Ips[host]!.length;
      } else {
        break;
      }
    } while (index != _host2Index[host]);

    String ip = _host2Ips[host]![index];
    _host2Index[host] = (index + 1) % _host2Ips[host]!.length;

    return ip;
  }

  @override
  void addUnavailableIp(String host, String ip) {
    if (!_host2UnavailableIps.containsKey(host)) {
      _host2UnavailableIps[host] = {};
    }

    // Clean up expired entries before adding
    _cleanupExpiredEntries(host);

    _host2UnavailableIps[host]![ip] = DateTime.now();
    log.info('RoundRobinIpProvider addUnavailableIp: $host -> $ip');
  }

  /// Clean up expired entries for a specific host
  void _cleanupExpiredEntries(String host) {
    final hostMap = _host2UnavailableIps[host];
    if (hostMap == null) return;

    final now = DateTime.now();
    hostMap.removeWhere((ip, timestamp) => now.difference(timestamp) > _unavailableDuration);
  }

  /// Periodic cleanup of all hosts (can be called from ScheduleService)
  void cleanupAllExpired() {
    for (final host in _host2UnavailableIps.keys.toList()) {
      _cleanupExpiredEntries(host);
    }
  }
}
