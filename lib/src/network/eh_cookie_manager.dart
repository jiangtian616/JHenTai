import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../enum/config_enum.dart';
import '../service/local_config_service.dart';
import '../setting/network_setting.dart';
import '../utils/cookie_util.dart';

class EHCookieManager extends Interceptor {
  final LocalConfigService localConfigService;

  List<Cookie> cookies = [];

  EHCookieManager(this.localConfigService);

  Future<void> initCookies() async {
    cookies = await loadCookies();
  }

  Future<List<Cookie>> loadCookies() async {
    List<Cookie> cookies = [Cookie('nw', '1')];

    String? string = await localConfigService.read(configKey: ConfigEnum.ehCookie);
    if (string != null) {
      List list = jsonDecode(string);
      cookies.addAll(list.cast<String>().map(Cookie.fromSetCookieValue).toList());
    }

    return cookies;
  }

  Future<void> setCookies(List<Cookie> cookies) async {
    cookies.removeWhere((cookie) => cookies.any((c) => c.name == cookie.name));
    cookies.addAll(cookies);

    List<Cookie> storeCookies = List.from(cookies)..remove(Cookie('nw', '1'));
    await localConfigService.write(configKey: ConfigEnum.ehCookie, value: jsonEncode(storeCookies.map((cookie) => cookie.toString()).toList()));
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      if (networkSetting.allHostAndIPs.contains(options.uri.host)) {
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

  Future<void> storeEHCookiesString(String cookiesString) {
    return storeEHCookies(CookieUtil.parse2Cookies(cookiesString));
  }

  Future<void> storeEHCookies(List<Cookie> cookies) async {
    /// https://github.com/Ehviewer-Overhauled/Ehviewer/issues/873
    cookies.removeWhere((cookie) => cookie.name == '__utmp');
    cookies.removeWhere((cookie) => cookie.name == 'igneous' && cookie.value == 'mystery');
    await setCookies(cookies);
  }

  Future<void> removeAllCookies() {
    return localConfigService.delete(configKey: ConfigEnum.ehCookie);
  }

  Future<void> _saveEHCookies(Response response) async {
    List<String>? cookieStrs = response.headers[HttpHeaders.setCookieHeader];
    if (cookieStrs == null) {
      return;
    }

    if (networkSetting.allHostAndIPs.contains(response.requestOptions.uri.host)) {
      List<Cookie> cookies = cookieStrs.map(Cookie.fromSetCookieValue).map((cookie) => Cookie(cookie.name, cookie.value)).toList();
      await storeEHCookies(cookies);
    }
  }
}
