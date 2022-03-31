import 'dart:async';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_db_store/dio_cache_interceptor_db_store.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:path/path.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'eh_cache_interceptor.dart';
import 'eh_cookie_manager.dart';

typedef EHHtmlParser<T> = T Function(Response<String> response);

class EHRequest {
  static late final Dio _dio;
  static late final PersistCookieJar _cookieJar;

  static CacheOptions cacheOption = CacheOptions(
    store: DbCacheStore(databasePath: join(PathSetting.getVisibleDir().path, 'cache')),
    policy: CachePolicy.noCache,
    hitCacheOnErrorExcept: [401, 403],
    maxStale: const Duration(seconds: 60),
    priority: CachePriority.normal,
    cipher: null,
    keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    allowPostMethod: false,
  );

  static Future<void> init() async {
    _dio = Dio(BaseOptions(
      connectTimeout: 5000,
      receiveTimeout: 6000,
    ));

    _cookieJar = PersistCookieJar(storage: FileStorage(PathSetting.appSupportDir.path + "/.cookies/"));
    await _cookieJar.forceInit();

    if ((await _cookieJar.loadForRequest(Uri.parse('https://e-hentai.org'))).isEmpty) {
      await storeEhCookiesForAllUri([]);
    }

    /// error handler
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        if ((response.data.toString()).isEmpty) {
          return handler.reject(
            DioError(
              requestOptions: response.requestOptions,
              error: EHException(type: EHExceptionType.blankBody, msg: "sadPanda".tr),
            ),
          );
        }
        if (response.data.toString().startsWith('Your IP address')) {
          return handler.reject(
            DioError(
              requestOptions: response.requestOptions,
              error: EHException(type: EHExceptionType.banned, msg: response.data),
            ),
          );
        }
        handler.next(response);
      },
    ));

    /// domain fronting
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        if (AdvancedSetting.enableDomainFronting.isFalse) {
          handler.next(options);
          return;
        }

        Uri rawUri = options.uri;
        String host = rawUri.host;
        if (!EHConsts.host2Ip.containsKey(host)) {
          handler.next(options);
          return;
        }

        String ip = EHConsts.host2Ip[host]!;
        Uri newUri = rawUri.replace(host: ip);
        Map<String, dynamic> newHeaders = {...options.headers, 'host': host};
        handler.next(options.copyWith(path: newUri.toString(), headers: newHeaders));
      },
    ));
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        return EHConsts.host2Ip.containsValue(host);
      };
    };

    /// cookies
    _dio.interceptors.add(EHCookieManager(_cookieJar));

    /// cache
    _dio.interceptors.add(EHCacheInterceptor(options: cacheOption));

    Log.info('init EHRequest success', false);
  }

  static Future<void> storeEhCookiesStringForAllUri(String cookiesString) async {
    await storeEhCookiesForAllUri(CookieUtil.parse2Cookies(cookiesString));
  }

  static Future<void> storeEhCookiesForAllUri(List<Cookie> cookies) async {
    /// never warn about offensive gallery
    cookies.add(Cookie("nw", "1"));
    Future.wait(EHConsts.host2Ip.keys.map((host) => _storeCookies('https://' + host, cookies)));
    Future.wait(EHConsts.host2Ip.values.map((ip) => _storeCookies('https://' + ip, cookies)));
  }

  static Future<List<Cookie>> getCookie(Uri uri) async {
    return _cookieJar.loadForRequest(uri);
  }

  static Future<void> removeAllCookies() async {
    await _cookieJar.deleteAll();
    await storeEhCookiesForAllUri([]);
  }

  /// return null if login success, otherwise return error message
  static Future<String?> login(String userName, String passWord) async {
    Response<String> response = await _dio.post(
      EHConsts.EForums,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      queryParameters: {'act': 'Login', 'CODE': '01'},
      data: {
        'referer': 'https://forums.e-hentai.org/index.php?',
        'b': '',
        'bt': '',
        'UserName': userName,
        'PassWord': passWord,
        'CookieDate': 365,
      },
    );

    /// if login success, cookieHeaders's length = 4or5, otherwise 1.
    List<String>? cookieHeaders = response.headers['set-cookie'];
    bool success = cookieHeaders != null && cookieHeaders.length > 2;
    if (success) {
      UserSetting.saveUserInfo(
        userName: userName,
        ipbMemberId: int.parse(
          RegExp(r'ipb_member_id=(\d+);')
              .firstMatch(cookieHeaders.firstWhere((header) => header.contains('ipb_member_id')))!
              .group(1)!,
        ),
        ipbPassHash: RegExp(r'ipb_pass_hash=(\w+);')
            .firstMatch(cookieHeaders.firstWhere((header) => header.contains('ipb_pass_hash')))!
            .group(1)!,
      );
      return null;
    }

    return _parseLoginErrorMsg(response.data!);
  }

  static Future<void> logout() async {
    removeAllCookies();
    UserSetting.clear();
    CookieManager().clearCookies();
  }

  static Future<T> requestHomePage<T>({EHHtmlParser<T>? parser}) async {
    Response<String> response = await _dio.get(EHConsts.EHome);
    parser ??= noOpParser;
    return parser(response);
  }

  /// return null if cookie is wrong
  static Future<T> requestForum<T>(int ipbMemberId, EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.get(
      EHConsts.EForums,
      queryParameters: {
        'showuser': ipbMemberId,
      },
    );
    return parser(response);
  }

  static Future<T> requestGalleryPage<T>({
    required int pageNo,
    required SearchConfig searchConfig,
    required EHHtmlParser<T> parser,
  }) async {
    Response<String> response = await _dio.get(
      searchConfig.toPath(),
      queryParameters: {
        'page': pageNo,
        ...searchConfig.toQueryParameters(),
      },
    );
    return parser(response);
  }

  static Future<T> requestDetailPage<T>({
    required String galleryUrl,
    int thumbnailsPageNo = 0,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    required EHHtmlParser<T> parser,
  }) async {
    Response<String> response = await _dio.get(
      galleryUrl,
      queryParameters: {'p': thumbnailsPageNo},
      cancelToken: cancelToken,
      options: useCacheIfAvailable
          ? cacheOption.copyWith(policy: CachePolicy.forceCache).toOptions()
          : cacheOption.copyWith(policy: CachePolicy.refreshForceCache).toOptions(),
    );
    return parser(response);
  }

  static Future<T> requestRankPage<T>(EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.get(EHConsts.ERanklist);
    return parser(response);
  }

  static Future<String> requestSubmitRating(int gid, String token, int apiuid, String apikey, int rating) async {
    Response<String> response = await _dio.post(
      EHConsts.EApi,
      data: {
        'apikey': apikey,
        'apiuid': apiuid,
        'gid': gid,
        'method': "rategallery",
        'rating': rating,
        'token': token,
      },
    );
    return response.data!;
  }

  static Future<T> requestPopupPage<T>(int gid, String token, String act, T Function(String html) parser) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await _dio.get(
      EHConsts.EPopup,
      queryParameters: {
        'gid': gid,
        't': token,
        'act': act,
      },
    );
    return parser.call(response.data!);
  }

  static Future<T> requestFavoritePage<T>(EHHtmlParser<T> parser) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await _dio.get(EHConsts.EFavorite);
    return parser(response);
  }

  /// favcat: the favorite tag index
  static Future<bool> requestAddFavorite(int gid, String token, int favcat) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await _dio.post(
      EHConsts.EPopup,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      queryParameters: {
        'gid': gid,
        't': token,
        'act': 'addfav',
      },
      data: {
        'favcat': favcat,
        'favnote': '',
        'apply': 'Apply Changes',
        'update': 1,
      },
    );
    return true;
  }

  static Future<bool> requestRemoveFavorite(int gid, String token) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await _dio.post(
      EHConsts.EPopup,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      queryParameters: {
        'gid': gid,
        't': token,
        'act': 'addfav',
      },
      data: {
        'favcat': 'favdel',
        'favnote': '',
        'apply': 'Apply Changes',
        'update': 1,
      },
    );
    return true;
  }

  static Future<T> requestImagePage<T>(
    String href, {
    CancelToken? cancelToken,
    bool useCacheIfAvailable = true,
    required EHHtmlParser<T> parser,
  }) async {
    Response<String> response = await _dio.post(
      href,
      cancelToken: cancelToken,
      options: useCacheIfAvailable ? cacheOption.copyWith(policy: CachePolicy.refreshForceCache).toOptions() : null,
    );
    return parser(response);
  }

  static Future<T> requestTorrentPage<T>(int gid, String token, EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.get(
      EHConsts.ETorrent,
      queryParameters: {
        'gid': gid,
        't': token,
      },
      options: cacheOption.copyWith(policy: CachePolicy.forceCache).toOptions(),
    );
    return parser(response);
  }

  static Future<T> requestSettingPage<T>(EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.get(EHConsts.EUconfig);
    return parser(response);
  }

  static Future<bool> download({
    required String url,
    required String path,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    await _dio.download(
      url,
      path,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
      options: options ??
          Options(
            receiveTimeout: 10000,
            extra: cacheOption.copyWith(policy: CachePolicy.forceCache).toExtra(),
          ),
    );
    return true;
  }

  static Future<String> voteTag(
    int gid,
    String token,
    int apiuid,
    String apikey,
    String namespace,
    String tagName,
    bool isVotingUp,
  ) async {
    Response<String> response = await _dio.post(
      EHConsts.EApi,
      data: {
        'apikey': apikey,
        'apiuid': apiuid,
        'gid': gid,
        'method': "taggallery",
        'token': token,
        'vote': isVotingUp ? 1 : -1,
        'tags': '$namespace:$tagName',
      },
    );
    return response.data!;
  }

  static Future<String> voteComment(
    int gid,
    String token,
    int apiuid,
    String apikey,
    int commentId,
    bool isVotingUp,
  ) async {
    Response<String> response = await _dio.post(
      EHConsts.EApi,
      data: {
        'apikey': apikey,
        'apiuid': apiuid,
        'gid': gid,
        'method': "votecomment",
        'token': token,
        'comment_vote': isVotingUp ? 1 : -1,
        'comment_id': commentId,
      },
    );
    return response.data!;
  }

  static Future<T> requestTagSuggestion<T>(String keyword, EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.post(
      EHConsts.EApi,
      data: {
        'method': "tagsuggest",
        'text': keyword,
      },
    );
    return parser(response);
  }

  static Future<T> requestSendComment<T>({
    required String galleryUrl,
    required String content,
    required EHHtmlParser<T> parser,
  }) async {
    Response<String> response = await _dio.post(
      galleryUrl,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'commenttext_new': content,
      },
    );
    return parser(response);
  }

  static String _parseLoginErrorMsg(String html) {
    if (html.contains('The captcha was not entered correctly')) {
      return 'needCaptcha'.tr;
    }
    return 'userNameOrPasswordMismatch'.tr;
  }

  static Future<void> _storeCookies(String uri, List<Cookie> cookies) async {
    await _cookieJar.saveFromResponse(Uri.parse(uri), cookies);
  }
}
