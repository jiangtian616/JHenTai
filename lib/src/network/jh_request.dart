import 'package:dio/dio.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:get/get_core/get_core.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:jhentai/src/consts/jh_consts.dart';
import 'package:jhentai/src/network/jh_cookie_manager.dart';

import '../service/isolate_service.dart';
import '../service/storage_service.dart';
import '../setting/network_setting.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';
import '../utils/proxy_util.dart';

class JHRequest {
  static late final Dio _dio;
  static late final JHCookieManager _cookieManager;
  static late final String systemProxyAddress;

  static Future<void> init() async {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: NetworkSetting.connectTimeout.value),
      receiveTimeout: Duration(milliseconds: NetworkSetting.receiveTimeout.value),
    ));

    systemProxyAddress = await getSystemProxyAddress();

    await _initProxy();

    _initCookieManager();

    Log.debug('init JHRequest success');
  }

  static Future<void> _initProxy() async {
    SocksProxy.initProxy(
      onCreate: (client) => client.badCertificateCallback = (_, String host, __) {
        return NetworkSetting.allIPs.contains(host);
      },
      findProxy: await findProxySettingFunc(() => systemProxyAddress),
    );
  }

  static void _initCookieManager() {
    _cookieManager = JHCookieManager(Get.find<StorageService>());
    _dio.interceptors.add(_cookieManager);
  }

  static Future<T> requestAlive<T>({HtmlParser<T>? parser}) async {
    Response response = await _dio.get('${JHConsts.serverAddress}/alive');

    return _parseResponse(response, parser);
  }

  static Future<T> requestListConfig<T>({int? type, HtmlParser<T>? parser}) async {
    Response response = await _dio.get(
      '${JHConsts.serverAddress}/api/config/list',
      queryParameters: {
        if (type != null) 'type': type,
      },
    );

    return _parseResponse(response, parser);
  }

  static Future<T> requestConfigByShareCode<T>({required String shareCode, HtmlParser<T>? parser}) async {
    Response response = await _dio.get(
      '${JHConsts.serverAddress}/api/config/getByShareCode',
      queryParameters: {
        'shareCode': shareCode,
      },
    );

    return _parseResponse(response, parser);
  }

  static Future<T> requestBatchUploadConfig<T>({
    required List<({int type, String version, String config})> configs,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _dio.post(
      '${JHConsts.serverAddress}/api/config/upload',
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'configs': configs
            .map((c) => {
                  'type': c.type,
                  'version': c.version,
                  'config': c.config,
                })
            .toList(),
      },
    );

    return _parseResponse(response, parser);
  }

  static Future<T> requestDeleteConfig<T>({required int id, HtmlParser<T>? parser}) async {
    Response response = await _dio.post(
      '${JHConsts.serverAddress}/api/config/delete',
      queryParameters: {
        'id': id,
      },
    );

    return _parseResponse(response, parser);
  }

  static Future<T> _parseResponse<T>(Response response, HtmlParser<T>? parser) async {
    if (parser == null) {
      return response as T;
    }
    return IsolateService.run((list) => parser(list[0], list[1]), [response.headers, response.data]);
  }
}
