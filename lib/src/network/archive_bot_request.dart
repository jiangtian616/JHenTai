import 'package:dio/dio.dart';
import 'package:get/get_rx/src/rx_workers/rx_workers.dart';
import 'package:jhentai/src/consts/archive_bot_consts.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';

import '../service/isolate_service.dart';
import '../service/jh_service.dart';
import '../setting/network_setting.dart';
import '../utils/eh_spider_parser.dart';

ArchiveBotRequest archiveBotRequest = ArchiveBotRequest();

class ArchiveBotRequest with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late final Dio _dio;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..addAll([ehRequest, archiveBotSetting]);

  @override
  Future<void> doInitBean() async {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: networkSetting.connectTimeout.value),
      receiveTimeout: Duration(milliseconds: networkSetting.receiveTimeout.value),
    ));

    ever(networkSetting.connectTimeout, (_) {
      setConnectTimeout(networkSetting.connectTimeout.value);
    });
    ever(networkSetting.receiveTimeout, (_) {
      setReceiveTimeout(networkSetting.receiveTimeout.value);
    });
  }

  @override
  Future<void> doAfterBeanReady() async {}

  void setConnectTimeout(int connectTimeout) {
    _dio.options.connectTimeout = Duration(milliseconds: connectTimeout);
  }

  void setReceiveTimeout(int receiveTimeout) {
    _dio.options.receiveTimeout = Duration(milliseconds: receiveTimeout);
  }

  Future<T> requestBalance<T>({required String apiKey, HtmlParser<T>? parser}) async {
    Response response = await _dio.post(
      '${ArchiveBotConsts.proxyServerAddress}/balance',
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'apikey': apiKey,
      },
    );

    return _parseResponse(response, parser);
  }

  Future<T> requestCheckIn<T>({required String apiKey, HtmlParser<T>? parser}) async {
    Response response = await _dio.post(
      '${ArchiveBotConsts.proxyServerAddress}/checkin',
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'apikey': apiKey,
      },
    );

    return _parseResponse(response, parser);
  }

  Future<T> requestResolve<T>({
    required String apiKey,
    required int gid,
    required String token,
    CancelToken? cancelToken,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _dio.post(
      options: Options(contentType: Headers.jsonContentType),
      '${ArchiveBotConsts.proxyServerAddress}/resolve',
      data: {
        'apikey': apiKey,
        'gid': gid,
        'token': token,
      },
      cancelToken: cancelToken,
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
