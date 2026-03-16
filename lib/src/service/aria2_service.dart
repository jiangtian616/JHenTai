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

  Future<String> addUri({
    required String uri,
    String? out,
    String? dir,
    List<String>? headers,
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
    if (headers != null && headers.isNotEmpty) {
      options['header'] = headers;
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

    if (response.data is! Map<String, dynamic>) {
      throw Exception('Invalid aria2 response');
    }
    if (response.data['error'] != null) {
      String error = response.data['error'] is Map ? (response.data['error']['message']?.toString() ?? 'Unknown aria2 error') : 'Unknown aria2 error';
      throw Exception(error);
    }

    String? gid = response.data['result']?.toString();
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

    if (response.data is! Map<String, dynamic>) {
      throw Exception('Invalid aria2 response');
    }
    if (response.data['error'] != null) {
      String error = response.data['error'] is Map ? (response.data['error']['message']?.toString() ?? 'Unknown aria2 error') : 'Unknown aria2 error';
      throw Exception(error);
    }
  }
}
