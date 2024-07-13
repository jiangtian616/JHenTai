import 'dart:io';

import 'package:dio/dio.dart';
import 'package:jhentai/src/consts/jh_consts.dart';
import 'package:jhentai/src/service/storage_service.dart';

import '../enum/config_enum.dart';
import '../setting/network_setting.dart';
import '../utils/cookie_util.dart';

class JHCookieManager extends Interceptor {
  final StorageService storageService;

  JHCookieManager(this.storageService);

  List<Cookie> get ehCookies {
    return [...(storageService.read<List?>(ConfigEnum.ehCookie.key) ?? []).cast<String>().map(Cookie.fromSetCookieValue).toList(), Cookie('nw', '1')];
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      if (Uri.parse(JHConsts.serverAddress).host == options.uri.host) {
        options.headers[HttpHeaders.cookieHeader] = CookieUtil.parse2String(ehCookies);
      }
      handler.next(options);
    } on Exception catch (e, stackTrace) {
      var err = DioException(requestOptions: options, error: e, stackTrace: stackTrace);
      handler.reject(err, true);
    }
  }
}
