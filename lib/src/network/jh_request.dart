import 'package:dio/dio.dart';
import 'package:jhentai/src/consts/jh_consts.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/network/jh_cookie_manager.dart';

import '../service/isolate_service.dart';
import '../service/jh_service.dart';
import '../setting/network_setting.dart';
import '../utils/eh_spider_parser.dart';

JHRequest jhRequest = JHRequest();

class JHRequest with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late final Dio _dio;
  late final JHCookieManager _cookieManager;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..add(ehRequest);

  @override
  Future<void> doInitBean() async {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: networkSetting.connectTimeout.value),
      receiveTimeout: Duration(milliseconds: networkSetting.receiveTimeout.value),
    ));

    await _initCookieManager();
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> _initCookieManager() async {
    _cookieManager = JHCookieManager();
    _dio.interceptors.add(_cookieManager);
  }

  Future<T> requestAlive<T>({HtmlParser<T>? parser}) async {
    Response response = await _dio.get('${JHConsts.serverAddress}/alive');

    return _parseResponse(response, parser);
  }

  Future<T> requestListConfig<T>({int? type, HtmlParser<T>? parser}) async {
    Response response = await _dio.get(
      '${JHConsts.serverAddress}/api/config/list',
      queryParameters: {
        if (type != null) 'type': type,
      },
    );

    return _parseResponse(response, parser);
  }

  Future<T> requestConfigByShareCode<T>({required String shareCode, HtmlParser<T>? parser}) async {
    Response response = await _dio.get(
      '${JHConsts.serverAddress}/api/config/getByShareCode',
      queryParameters: {
        'shareCode': shareCode,
      },
    );

    return _parseResponse(response, parser);
  }

  Future<T> requestBatchUploadConfig<T>({
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

  Future<T> requestDeleteConfig<T>({required int id, HtmlParser<T>? parser}) async {
    Response response = await _dio.post(
      '${JHConsts.serverAddress}/api/config/delete',
      queryParameters: {
        'id': id,
      },
    );

    return _parseResponse(response, parser);
  }

  Future<T> _parseResponse<T>(Response response, HtmlParser<T>? parser) async {
    if (parser == null) {
      return response as T;
    }
    return isolateService.run((list) => parser(list[0], list[1]), [response.headers, response.data]);
  }
}
