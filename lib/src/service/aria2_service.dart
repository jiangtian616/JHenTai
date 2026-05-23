import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/setting/download_setting.dart';

import 'log.dart';

Aria2Service aria2Service = Aria2Service();

class Aria2Service {
  bool get isReady => downloadSetting.enableAria2Push.value && downloadSetting.aria2RpcUrl.value.trim().isNotEmpty;

  String _normalizedRpcUrl() {
    String url = downloadSetting.aria2RpcUrl.value.trim();
    if (url.isEmpty) {
      return url;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (!url.endsWith('/jsonrpc')) {
      if (url.endsWith('/')) {
        url = '${url}jsonrpc';
      } else {
        url = '$url/jsonrpc';
      }
    }
    return url;
  }

  Map<String, dynamic> _parseJsonRpcResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String && data.isNotEmpty) {
      dynamic decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    throw Exception('Invalid aria2 response');
  }

  Future<String> addUri({
    required String uri,
    String? out,
    String? dir,
  }) async {
    Dio dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: downloadSetting.aria2ConnectTimeout.value),
      receiveTimeout: Duration(milliseconds: downloadSetting.aria2ConnectTimeout.value),
    ));

    List<dynamic> params = [];
    if (downloadSetting.aria2Secret.value.trim().isNotEmpty) {
      params.add('token:${downloadSetting.aria2Secret.value.trim()}');
    }
    params.add([uri]);

    Map<String, dynamic> options = {};
    if (out != null && out.isNotEmpty) {
      options['out'] = out;
    }
    if (dir != null && dir.isNotEmpty) {
      options['dir'] = dir;
    }
    if (options.isNotEmpty) {
      params.add(options);
    }

    Response response = await dio.post(
      _normalizedRpcUrl(),
      data: {
        'jsonrpc': '2.0',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'method': 'aria2.addUri',
        'params': params,
      },
    );

    Map<String, dynamic> rpcResult = _parseJsonRpcResponse(response.data);

    if (rpcResult['error'] != null) {
      String error = rpcResult['error'] is Map ? (rpcResult['error']['message']?.toString() ?? 'Unknown aria2 error') : 'Unknown aria2 error';
      throw Exception(error);
    }

    String? gid = rpcResult['result']?.toString();
    if (gid.isBlank == true) {
      throw Exception('Empty aria2 task id');
    }

    log.info('Pushed to aria2, gid: $gid');
    return gid!;
  }

  Future<void> testConnection() async {
    Dio dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: downloadSetting.aria2ConnectTimeout.value),
      receiveTimeout: Duration(milliseconds: downloadSetting.aria2ConnectTimeout.value),
    ));

    List<dynamic> params = [];
    if (downloadSetting.aria2Secret.value.trim().isNotEmpty) {
      params.add('token:${downloadSetting.aria2Secret.value.trim()}');
    }

    Response response = await dio.post(
      _normalizedRpcUrl(),
      data: {
        'jsonrpc': '2.0',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'method': 'aria2.getVersion',
        'params': params,
      },
    );

    Map<String, dynamic> rpcResult = _parseJsonRpcResponse(response.data);

    if (rpcResult['error'] != null) {
      String error = rpcResult['error'] is Map ? (rpcResult['error']['message']?.toString() ?? 'Unknown aria2 error') : 'Unknown aria2 error';
      throw Exception(error);
    }
  }
}
