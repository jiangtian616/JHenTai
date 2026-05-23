import 'dart:async';
import 'dart:io';
import 'package:system_network_proxy_platform_interface/system_network_proxy_platform_interface.dart';

class SystemNetworkProxyMacos extends SystemNetworkProxyPlatform {
  static SystemNetworkProxyMacos instance = SystemNetworkProxyMacos();

  static normalizeOutput(String output) {
    return output.trim().replaceAll("'", "");
    // return RegExp(r"^\s*'(?<content>\w+)'\s*$").firstMatch(output)?.namedGroup('content');
  }

  static concatCommands(List<String> commands) {
    return commands.join(' && ');
  }

  /// Returns `true` if this platform is able to getProxyEnable.
  @override
  Future<bool> getProxyEnable() async {
    try {
      var results = await Process.run('bash', [
        '-c',
        concatCommands([
          'networksetup -getwebproxy wi-fi',
        ])
      ]);
      print(
          'get proxyEnable, exitCode: ${results.exitCode}, stdout: ${results.stdout}');
      var proxyEnableLine = (results.stdout as String)
          .split('\n')
          .where((item) => item.contains('Enabled'))
          .first
          .trim();
      return proxyEnableLine.endsWith('Yes');
    } catch (e) {
      print(e);
      return false;
    }
  }

  /// Returns `true` if this platform is able to setProxyEnable [proxyEnable].
  @override
  Future<bool> setProxyEnable(bool proxyEnable) async {
    try {
      var proxyMode = proxyEnable ? 'on' : 'off';
      var results = await Process.run('bash', [
        '-c',
        concatCommands([
          'networksetup -setwebproxystate wi-fi $proxyMode',
          // 'networksetup -setsecurewebproxystate wi-fi $proxyMode',
        ])
      ]);
      print(
          'set proxyEnable, exitCode: ${results.exitCode}, stdout: ${results.stdout}');
      return results.exitCode == 0;
    } catch (e) {
      print(e);
      return false;
    }
  }

  /// Returns `true` if this platform is able to getProxyServer.
  @override
  Future<String> getProxyServer() async {
    try {
      var results = await Process.run('bash', [
        '-c',
        concatCommands([
          'networksetup -getwebproxy wi-fi',
        ])
      ]);
      print(
          'get proxyServer, exitCode: ${results.exitCode}, stdout: ${results.stdout}');

      var match = RegExp(
              r"^.*Enabled: (?<enabled>.*)\nServer: (?<server>.*)\nPort: (?<port>.*)\n.*$",
              multiLine: true)
          .firstMatch(results.stdout);
      var server = match?.namedGroup('server') ?? '';
      var port = match?.namedGroup('port') ?? '';
      if (server == '') {
        return '';
      }
      return '$server:$port';
    } catch (e) {
      print(e);
      return '';
    }
  }

  /// Returns `true` if this platform is able to setProxyServer [proxyServer].
  @override
  Future<bool> setProxyServer(String proxyServer) async {
    try {
      var match = RegExp(r"^(?:http://)?(?<host>.+):(?<port>\d+)$")
          .firstMatch(proxyServer);
      if (match == null) {
        print('proxyServer parse error!');
        return false;
      }
      var host = match.namedGroup('host');
      var port = match.namedGroup('port');
      var results = await Process.run('bash', [
        '-c',
        concatCommands([
          'networksetup -setwebproxy wi-fi $host $port',
          // 'networksetup -setsecurewebproxy wi-fi $host $port',
        ])
      ]);
      print(
          'set proxyServer, exitCode: ${results.exitCode}, stdout: ${results.stdout}');
      return results.exitCode == 0;
    } catch (e) {
      print(e);
      return false;
    }
  }
}
