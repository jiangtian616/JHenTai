import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/network/eh_request.dart';

/// just copy from CookieManager and overrides [onRequest] & [_saveCookies]
class EHCookieManager extends CookieManager {
  EHCookieManager(CookieJar cookieJar) : super(cookieJar);

  CookieJar get() => cookieJar;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    cookieJar.loadForRequest(options.uri).then((cookies) {
      if (EHConsts.host2Ip.containsKey(options.uri.host) || EHConsts.host2Ip.containsValue(options.uri.host)) {
        cookies.add(Cookie('nw', '1'));
      }
      var cookie = CookieManager.getCookies(cookies);
      if (cookie.isNotEmpty) {
        options.headers[HttpHeaders.cookieHeader] = cookie;
      }
      handler.next(options);
    }).catchError((e, stackTrace) {
      var err = DioError(requestOptions: options, error: e);
      err.stackTrace = stackTrace;
      handler.reject(err, true);
    });
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _saveCookies(response).then((_) => handler.next(response)).catchError((e, stackTrace) {
      var err = DioError(requestOptions: response.requestOptions, error: e);
      err.stackTrace = stackTrace;
      handler.reject(err, true);
    });
  }

  /// eh host -> save cookie for all eh hosts
  /// other host -> normal
  Future<void> _saveCookies(Response response) async {
    var cookies = response.headers[HttpHeaders.setCookieHeader];
    if (cookies == null) {
      return;
    }

    if (EHConsts.host2Ip.containsKey(response.requestOptions.uri.host) ||
        EHConsts.host2Ip.containsValue(response.requestOptions.uri.host)) {
      await EHRequest.storeEhCookiesForAllUri(
        cookies
            .map((str) => Cookie.fromSetCookieValue(str))
            .map((cookie) => Cookie(cookie.name, cookie.value))
            .toList(),
      );
    } else {
      await cookieJar.saveFromResponse(
        response.requestOptions.uri,
        cookies.map((str) => Cookie.fromSetCookieValue(str)).toList(),
      );
    }
  }
}
