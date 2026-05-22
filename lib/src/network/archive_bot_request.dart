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

  /// Workers that need disposal
  late Worker _connectTimeoutLister;
  late Worker _receiveTimeoutLister;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..addAll([ehRequest, archiveBotSetting]);

  @override
  Future<void> doInitBean() async {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: networkSetting.connectTimeout.value),
      receiveTimeout: Duration(milliseconds: networkSetting.receiveTimeout.value),
    ));

    _connectTimeoutLister = ever(networkSetting.connectTimeout, (_) {
      setConnectTimeout(networkSetting.connectTimeout.value);
    });
    _receiveTimeoutLister = ever(networkSetting.receiveTimeout, (_) {
      setReceiveTimeout(networkSetting.receiveTimeout.value);
    });
  }

  @override
  Future<void> doAfterBeanReady() async {}

  @override
  void doDisposeBean() {
    _connectTimeoutLister.dispose();
    _receiveTimeoutLister.dispose();
    _dio.close();
  }

  void setConnectTimeout(int connectTimeout) {
    _dio.options.connectTimeout = Duration(milliseconds: connectTimeout);
  }

  void setReceiveTimeout(int receiveTimeout) {
    _dio.options.receiveTimeout = Duration(milliseconds: receiveTimeout);
  }

  Future<T> requestBalance<T>({
    String? apiAddress,
    required String apiKey,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _dio.post(
      '${archiveBotSetting.useProxyServer.value ? ArchiveBotConsts.proxyServerAddress : apiAddress}/balance',
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'apikey': apiKey,
      },
    );

    return _parseResponse(response, parser);
  }

  Future<T> requestCheckIn<T>({
    String? apiAddress,
    required String apiKey,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _dio.post(
      '${archiveBotSetting.useProxyServer.value ? ArchiveBotConsts.proxyServerAddress : apiAddress}/checkin',
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'apikey': apiKey,
      },
    );

    return _parseResponse(response, parser);
  }

  Future<T> requestResolve<T>({
    String? apiAddress,
    required String apiKey,
    required int gid,
    required String token,
    bool reParse = true,
    CancelToken? cancelToken,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _dio.post(
      '${archiveBotSetting.useProxyServer.value ? ArchiveBotConsts.proxyServerAddress : apiAddress}/resolve',
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'apikey': apiKey,
        'gid': gid,
        'token': token,
        'force_resolve': reParse,
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
