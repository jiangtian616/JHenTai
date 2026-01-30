import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../enum/config_enum.dart';
import '../service/local_config_service.dart';
import '../service/log.dart';
import '../setting/network_setting.dart';
import '../utils/cookie_util.dart';

class EHCookieManager extends Interceptor {
  final LocalConfigService localConfigService;

  List<Cookie> cookies = [Cookie('nw', '1'), Cookie('datatags', '1')];

  EHCookieManager(this.localConfigService);

  Future<void> initCookies() async {
    String? string = await localConfigService.read(configKey: ConfigEnum.ehCookie);
    if (string != null) {
      List list = jsonDecode(string);
      cookies.addAll(list.cast<String>().map(Cookie.fromSetCookieValue).toList());
    }
  }

  Future<void> replaceCookies(List<Cookie> cookies) async {
    this.cookies.removeWhere((cookie) => cookies.any((c) => c.name == cookie.name));
    this.cookies.addAll(cookies);

    List<Cookie> storeCookies = List.from(this.cookies)..removeWhere((cookie) => cookie.name == 'nw' || cookie.name == 'datatags');
    await localConfigService.write(configKey: ConfigEnum.ehCookie, value: jsonEncode(storeCookies.map((cookie) => cookie.toString()).toList()));
  }

  Future<void> removeCookies(List<String> cookieNames) async {
    cookies.removeWhere((cookie) => cookieNames.any((name) => cookie.name == name));

    List<Cookie> storeCookies = List.from(cookies)..removeWhere((cookie) => cookie.name == 'nw' || cookie.name == 'datatags');
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
      // Fire-and-forget: Cookie persistence adds ~5-15ms latency per request.
      // Cookies are already set in memory before save; persistence only affects
      // next app launch. Acceptable tradeoff for response speed.
      _saveEHCookies(response).catchError((e) {
        log.error('save cookies failed', e);
      });
      handler.next(response);
    } on Exception catch (e, s) {
      final err = DioException(requestOptions: response.requestOptions, error: e, stackTrace: s);
      handler.reject(err, true);
    }
  }

  Future<void> storeEHCookies(List<Cookie> cookies) async {
    /// https://github.com/Ehviewer-Overhauled/Ehviewer/issues/873
    cookies.removeWhere((cookie) => cookie.name == '__utmp');
    cookies.removeWhere((cookie) => cookie.name == 'igneous' && cookie.value == 'mystery');
    await replaceCookies(cookies);
  }

  Future<bool> removeAllCookies() async {
    bool success = await localConfigService.delete(configKey: ConfigEnum.ehCookie);
    cookies = [Cookie('nw', '1'), Cookie('datatags', '1')];
    return success;
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
