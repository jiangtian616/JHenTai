import 'dart:io';

import 'package:dio/dio.dart';
import 'package:jhentai/src/consts/jh_consts.dart';
import 'package:jhentai/src/network/eh_request.dart';

import '../utils/cookie_util.dart';

class JHCookieManager extends Interceptor {

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      if (Uri.parse(JHConsts.serverAddress).host == options.uri.host) {
        options.headers[HttpHeaders.cookieHeader] = CookieUtil.parse2String(ehRequest.cookies);
      }
      handler.next(options);
    } on Exception catch (e, stackTrace) {
      var err = DioException(requestOptions: options, error: e, stackTrace: stackTrace);
      handler.reject(err, true);
    }
  }
}
