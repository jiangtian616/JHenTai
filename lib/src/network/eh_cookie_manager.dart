import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:jhentai/src/service/storage_service.dart';

import '../setting/network_setting.dart';
import '../utils/cookie_util.dart';

class EHCookieManager extends Interceptor {
  final StorageService storageService;

  EHCookieManager(this.storageService);

  final _cookieKey = 'eh_cookies';

  List<Cookie> get cookies {
    return [...(storageService.read<List?>(_cookieKey) ?? []).cast<String>().map(Cookie.fromSetCookieValue).toList(), Cookie('nw', '1')];
  }

  set cookies(List<Cookie> cookies) {
    List<Cookie> oldCookies = (storageService.read<List?>(_cookieKey) ?? []).cast<String>().map(Cookie.fromSetCookieValue).toList();
    oldCookies.removeWhere((cookie) => cookies.any((c) => c.name == cookie.name));
    oldCookies.addAll(cookies);
    storageService.write(_cookieKey, oldCookies.map((cookie) => cookie.toString()).toList());
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      if (NetworkSetting.currentHost2IP.containsKey(options.uri.host) || NetworkSetting.currentHost2IP.containsValue(options.uri.host)) {
        options.headers[HttpHeaders.cookieHeader] = CookieUtil.parse2String(cookies);
      }
      handler.next(options);
    } on Exception catch (e, stackTrace) {
      var err = DioException(requestOptions: options, error: e, stackTrace: stackTrace);
      handler.reject(err, true);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      _saveEHCookies(response);
      handler.next(response);
    } on Exception catch (e, s) {
      final err = DioException(requestOptions: response.requestOptions, error: e, stackTrace: s);
      return handler.reject(err, true);
    }
  }

  void storeEHCookiesString(String cookiesString) {
    storeEHCookies(CookieUtil.parse2Cookies(cookiesString));
  }

  void storeEHCookies(List<Cookie> cookies) {
    /// https://github.com/Ehviewer-Overhauled/Ehviewer/issues/873
    cookies.removeWhere((cookie) => cookie.name == '__utmp');
    cookies.removeWhere((cookie) => cookie.name == 'igneous' && cookie.value == 'mystery');
    this.cookies = cookies;
  }

  void removeAllCookies() {
    storageService.write(_cookieKey, []);
  }

  void _saveEHCookies(Response response) {
    List<String>? cookieStrs = response.headers[HttpHeaders.setCookieHeader];
    if (cookieStrs == null) {
      return;
    }

    if (NetworkSetting.allHostAndIPs.contains(response.requestOptions.uri.host)) {
      List<Cookie> cookies = cookieStrs.map(Cookie.fromSetCookieValue).map((cookie) => Cookie(cookie.name, cookie.value)).toList();
      storeEHCookies(cookies);
    }
  }
}
