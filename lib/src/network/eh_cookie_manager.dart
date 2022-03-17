import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/utils/log.dart';

class EHCookieManager extends CookieManager {
  EHCookieManager(CookieJar cookieJar) : super(cookieJar);

  /// just copy from CookieManager
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _saveCookies(response).then((_) => handler.next(response)).catchError((e, stackTrace) {
      var err = DioError(requestOptions: response.requestOptions, error: e);
      err.stackTrace = stackTrace;
      handler.reject(err, true);
    });
  }

  /// eh host -> save cookie for all eh hosts;
  /// other host -> normal
  Future<void> _saveCookies(Response response) async {
    var cookies = response.headers[HttpHeaders.setCookieHeader];
    if (cookies == null) {
      return;
    }

    if (EHConsts.host2Ip.containsKey(response.requestOptions.uri.path)) {
      await EHRequest.storeEhCookiesForAllUri(cookies.map((str) => Cookie.fromSetCookieValue(str)).toList());
    } else {
      await cookieJar.saveFromResponse(
        response.requestOptions.uri,
        cookies.map((str) => Cookie.fromSetCookieValue(str)).toList(),
      );
    }
  }
}
