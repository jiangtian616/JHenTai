import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:path/path.dart';

import '../setting/path_setting.dart';
import '../utils/cookie_util.dart';
import '../utils/log.dart';

class EHCookieManager extends CookieManager {
  EHCookieManager(CookieJar cookieJar) : super(cookieJar);

  static Future<void> init() async {
    PersistCookieJar _cookieJar = PersistCookieJar(
      storage: FileStorage(join(PathSetting.appSupportDir.path, "cookies")),
    );

    /// For some reason i don't know currently, local [_hostset] file will be broken,
    /// which causes [_cookieJar] init failed, thus no hosts are load into memory.
    /// Temporarily, if error occurs, try load hosts manually.
    try {
      String? str = await _cookieJar.storage.read(_cookieJar.IndexKey);
      if (str != null && str.isNotEmpty) {
        json.decode(str);
      }
    } on Exception catch (e) {
      Log.warning('cookieJar init failed, use default setting', false);
      Set<String> defaultHostSet = EHConsts.host2Ip.entries.fold<Set<String>>(
        <String>{},
        (previousValue, entry) => previousValue..addAll([entry.key, entry.value]),
      );
      await _cookieJar.storage.write(_cookieJar.IndexKey, json.encode(defaultHostSet.toList()));
    }
    await _cookieJar.forceInit();

    /// eagerly load cookie into memory
    await Future.wait(
      EHConsts.host2Ip.entries.map(
        (entry) => Future.wait([
          _cookieJar.loadForRequest(Uri.parse('https://${entry.key}')),
          _cookieJar.loadForRequest(Uri.parse('https://${entry.value}')),
        ]),
      ),
    );

    Get.put<EHCookieManager>(EHCookieManager(_cookieJar));

    Log.verbose('init EHCookieManager success', false);
  }

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

  Future<void> storeEhCookiesStringForAllUri(String cookiesString) async {
    await storeEhCookiesForAllUri(CookieUtil.parse2Cookies(cookiesString));
  }

  Future<void> storeEhCookiesForAllUri(List<Cookie> cookies) async {
    await Future.wait(
      EHConsts.host2Ip.keys.map((host) => cookieJar.saveFromResponse(Uri.parse('https://$host'), cookies)),
    );
    await Future.wait(
      EHConsts.host2Ip.values.map((ip) => cookieJar.saveFromResponse(Uri.parse('https://$ip'), cookies)),
    );
  }

  Future<List<Cookie>> getCookie(Uri uri) async {
    return cookieJar.loadForRequest(uri);
  }

  Future<void> removeAllCookies() async {
    await cookieJar.deleteAll();
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
      await storeEhCookiesForAllUri(
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
