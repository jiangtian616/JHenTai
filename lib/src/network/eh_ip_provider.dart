import 'dart:async';

import 'package:jhentai/src/utils/log.dart';

abstract interface class EHIpProvider {
  bool supports(String host);

  String nextIP(String host);

  void addUnavailableIp(String host, String ip);
}

class RoundRobinIpProvider implements EHIpProvider {
  final Map<String, List<String>> _host2Ips = {};
  final Map<String, int> _host2Index = {};
  final Map<String, Map<String, DateTime>> _host2UnavailableIps = {};

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
    _host2UnavailableIps[host]![ip] = DateTime.now();
    Log.info('RoundRobinIpProvider addUnavailableIp: $host -> $ip');
  }
}
