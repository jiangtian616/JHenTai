import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:path/path.dart';

import '../setting/network_setting.dart';
import '../setting/path_setting.dart';
import '../utils/cookie_util.dart';
import '../utils/log.dart';

class EHCookieManager extends CookieManager {
  EHCookieManager(CookieJar cookieJar) : super(cookieJar);

  static String userCookies = "";

  static Future<void> init() async {
    PersistCookieJar _cookieJar = PersistCookieJar(
      storage: FileStorage(join(PathSetting.getVisibleDir().path, "cookies")),
    );

    /// For some reason i don't know currently, local [_hostset] file will be broken,
    /// which causes [_cookieJar] init failed, thus no hosts are load into memory.
    /// Temporarily, if error occurs, try load hosts manually.
    try {
      await _cookieJar.storage.init(true, false);
      String? str = await _cookieJar.storage.read(_cookieJar.IndexKey);
      if (str != null && str.isNotEmpty) {
        json.decode(str);
      }
    } on Exception catch (_) {
      Log.warning('cookieJar init failed, use default setting');
      await _cookieJar.storage.write(_cookieJar.IndexKey, json.encode(NetworkSetting.allHostAndIPs.toList()));
    }

    await _cookieJar.forceInit();

    /// eagerly load cookie into memory
    await Future.wait(
      NetworkSetting.allHostAndIPs.map((ip) => _cookieJar.loadForRequest(Uri.parse('https://$ip'))),
    );

    Get.put<EHCookieManager>(EHCookieManager(_cookieJar));

    List<Cookie> cookies = await _cookieJar.loadForRequest(Uri.parse(EHConsts.EHIndex));
    if (cookies.isEmpty && UserSetting.hasLoggedIn()) {
      Log.error('Logged in but cookie is missing, try log out.');
      UserSetting.clear();
    } else {
      userCookies = CookieUtil.parse2String(cookies);
    }

    Log.debug('init EHCookieManager success, cookies length:${cookies.length}', false);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    cookieJar.loadForRequest(options.uri).then((cookies) {
      if (NetworkSetting.currentHost2IP.containsKey(options.uri.host) || NetworkSetting.currentHost2IP.containsValue(options.uri.host)) {
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

  Future<void> storeEhCookiesStringForAllUri(String cookiesString) async {
    await storeEhCookiesForAllUri(CookieUtil.parse2Cookies(cookiesString));
  }

  Future<void> storeEhCookiesForAllUri(List<Cookie> cookies) async {
    /// https://github.com/Ehviewer-Overhauled/Ehviewer/issues/873
    cookies.removeWhere((cookie) => cookie.name == '__utmp');

    cookies.removeWhere((cookie) => cookie.name == 'igneous' && cookie.value == 'mystery');

    /// host
    await Future.wait(
      NetworkSetting.allHostAndIPs.map((host) => cookieJar.saveFromResponse(Uri.parse('https://$host'), cookies)),
    );

    cookieJar.loadForRequest(Uri.parse(EHConsts.EXIndex)).then((v) {
      String newCookieStr = CookieUtil.parse2String(v);
      if (newCookieStr.isNotEmpty && newCookieStr != userCookies) {
        userCookies = newCookieStr;
        Log.debug('New cookie: $userCookies');
      }
    });
  }

  Future<List<Cookie>> getCookie(Uri uri) async {
    return cookieJar.loadForRequest(uri);
  }

  Future<void> removeAllCookies() async {
    try {
      await cookieJar.deleteAll();
    } catch (e) {
      Log.error('removeAllCookies error: $e');
      Log.upload(e);
    }
  }

  /// eh host -> save cookie for all eh hosts
  /// other host -> normal
  Future<void> _saveCookies(Response response) async {
    var cookies = response.headers[HttpHeaders.setCookieHeader];
    if (cookies == null) {
      return;
    }

    if (NetworkSetting.allHostAndIPs.contains(response.requestOptions.uri.host)) {
      await storeEhCookiesForAllUri(
        cookies.map((str) => Cookie.fromSetCookieValue(str)).map((cookie) => Cookie(cookie.name, cookie.value)).toList(),
      );
    } else {
      await cookieJar.saveFromResponse(
        response.requestOptions.uri,
        cookies.map((str) => Cookie.fromSetCookieValue(str)).toList(),
      );
    }
  }
}
