import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/get_utils/src/platform/platform.dart';
import 'package:http_proxy/http_proxy.dart';
import 'package:integral_isolates/integral_isolates.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/eh_site_exception.dart';
import 'package:jhentai/src/model/gallery_page.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/network/eh_timeout_translator.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:system_network_proxy/system_network_proxy.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:webview_flutter/webview_flutter.dart' show WebViewCookieManager;
import '../setting/network_setting.dart';
import 'eh_cache_manager.dart';
import 'eh_cookie_manager.dart';

class EHRequest {
  static late final Dio _dio;
  static late final EHCookieManager _cookieManager;
  static late final EHCacheManager _cacheManager;
  static late final StatefulIsolate _isolate;

  static List<Cookie> get cookies => _cookieManager.cookies;

  static Future<void> init() async {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: NetworkSetting.connectTimeout.value),
      receiveTimeout: Duration(milliseconds: NetworkSetting.receiveTimeout.value),
    ));

    _initDomainFronting();

    await _initProxy();

    _initCookies();

    _initCertificateForAndroidWithOldVersion();

    _initCacheManager();

    _initTimeOutTranslator();

    _isolate = StatefulIsolate();

    Log.debug('init EHRequest success');
  }

  static void _initDomainFronting() {
    /// domain fronting interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        if (NetworkSetting.enableDomainFronting.isFalse) {
          handler.next(options);
          return;
        }

        String rawPath = options.path;
        String host = options.uri.host;
        if (!NetworkSetting.host2IPs.containsKey(host)) {
          handler.next(options);
          return;
        }

        handler.next(options.copyWith(
          path: rawPath.replaceFirst(host, NetworkSetting.currentHost2IP[host]!),
          headers: {...options.headers, 'host': host},
        ));
      },
    ));
  }

  static Future<void> _initProxy() async {
    /// proxy setting
    String systemProxyAddress = '';

    if (GetPlatform.isDesktop) {
      SystemNetworkProxy.init();
      systemProxyAddress = await SystemNetworkProxy.getProxyServer();
    }
    if (GetPlatform.isMobile) {
      HttpProxy httpProxy = await HttpProxy.createHttpProxy();
      if (!isEmptyOrNull(httpProxy.host) && !isEmptyOrNull(httpProxy.port)) {
        systemProxyAddress = '${httpProxy.host}:${httpProxy.port}';
      }
    }
    Log.info('System Proxy Address: $systemProxyAddress');

    String getConfigAddress() {
      String configAddress;
      if (isEmptyOrNull(NetworkSetting.proxyUsername.value) && isEmptyOrNull(NetworkSetting.proxyPassword.value)) {
        configAddress = NetworkSetting.proxyAddress.value;
      } else {
        configAddress = '${NetworkSetting.proxyUsername.value ?? ''}:${NetworkSetting.proxyPassword.value ?? ''}@${NetworkSetting.proxyAddress.value}';
      }
      return configAddress;
    }

    SocksProxy.initProxy(
      onCreate: (client) => client.badCertificateCallback = (_, String host, __) {
        return NetworkSetting.allIPs.contains(host);
      },
      findProxy: (_) {
        switch (NetworkSetting.proxyType.value) {
          case ProxyType.system:
            return isEmptyOrNull(systemProxyAddress) ? 'DIRECT' : 'PROXY $systemProxyAddress; DIRECT';
          case ProxyType.http:
            return 'PROXY ${getConfigAddress()}; DIRECT';
          case ProxyType.socks5:
            return 'SOCKS5 ${getConfigAddress()}; DIRECT';
          case ProxyType.socks4:
            return 'SOCKS4 ${getConfigAddress()}; DIRECT';
          case ProxyType.direct:
            return 'DIRECT';
        }
      },
    );
  }

  static void _initCookies() {
    _cookieManager = EHCookieManager(Get.find<StorageService>());
    _dio.interceptors.add(_cookieManager);
  }

  /// https://github.com/dart-lang/io/issues/83
  static void _initCertificateForAndroidWithOldVersion() {
    if (GetPlatform.isAndroid) {
      const isrgRootX1 = '''-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
''';
      SecurityContext.defaultContext.setTrustedCertificatesBytes(Uint8List.fromList(isrgRootX1.codeUnits));
    }
  }

  static void _initCacheManager() {
    _cacheManager = EHCacheManager(
      options: CacheOptions(
        policy: CachePolicy.disable,
        expire: NetworkSetting.pageCacheMaxAge.value,
        store: SqliteCacheStore(appDb: appDb),
      ),
    );
    _dio.interceptors.add(_cacheManager);
  }

  static void _initTimeOutTranslator() {
    _dio.interceptors.add(EHTimeoutTranslator());
  }

  static void storeEHCookiesString(String cookiesString) {
    _cookieManager.storeEHCookiesString(cookiesString);
  }

  static void storeEHCookies(List<Cookie> cookies) {
    _cookieManager.storeEHCookies(cookies);
  }

  static void removeAllCookies() {
    _cookieManager.removeAllCookies();
  }

  static Future<void> removeCacheByUrl(String url) {
    return _cacheManager.removeCacheByUrl(url);
  }

  static Future<void> removeCacheByEHUrl(String url) {
    Uri uri = Uri.parse(url);

    List<Future> futures = [];
    futures.add(_cacheManager.removeCacheByUrl(uri.toString()));

    NetworkSetting.host2IPs[uri.host]?.forEach((ip) {
      futures.add(_cacheManager.removeCacheByUrl(uri.replace(host: ip).toString()));
    });

    return Future.wait(futures);
  }

  static Future<void> removeCacheByGalleryUrlAndPage(String galleryUrl, int pageIndex) {
    Uri uri = Uri.parse(galleryUrl);
    uri = uri.replace(queryParameters: {'p': pageIndex.toString()});

    List<Future> futures = [];
    futures.add(removeCacheByUrlPrefix(uri.toString()));

    NetworkSetting.host2IPs[uri.host]?.forEach((ip) {
      futures.add(removeCacheByUrlPrefix(uri.replace(host: ip).toString()));
    });

    return Future.wait(futures);
  }

  static Future<void> removeCacheByUrlPrefix(String url) {
    return _cacheManager.removeCacheByUrlPrefix(url);
  }

  static Future<void> removeAllCache() {
    return _cacheManager.removeAllCache();
  }

  static Future<T> requestLogin<T>(String userName, String passWord, EHHtmlParser<T> parser) async {
    Response response = await _postWithErrorHandler(
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
    return _parseResponse(response, parser);
  }

  static Future<void> requestLogout() async {
    removeAllCookies();
    UserSetting.clear();
    if (!GetPlatform.isDesktop) {
      WebViewCookieManager().clearCookies();
    }
  }

  static Future<T> requestHomePage<T>({EHHtmlParser<T>? parser}) async {
    Response response = await _getWithErrorHandler(EHConsts.EHome);
    return _parseResponse(response, parser);
  }

  static Future<T> requestForum<T>(int ipbMemberId, EHHtmlParser<T> parser) async {
    Response response = await _getWithErrorHandler(
      EHConsts.EForums,
      queryParameters: {
        'showuser': ipbMemberId,
      },
    );
    return _parseResponse(response, parser);
  }

  /// [url]: used for file search
  static Future<T> requestGalleryPage<T>({
    String? url,
    String? prevGid,
    String? nextGid,
    DateTime? seek,
    SearchConfig? searchConfig,
    required EHHtmlParser<T> parser,
  }) async {
    Response response = await _getWithErrorHandler(
      url ?? searchConfig!.toPath(),
      queryParameters: {
        if (prevGid != null) 'prev': prevGid,
        if (nextGid != null) 'next': nextGid,
        if (seek != null) 'seek': DateFormat('yyyy-MM-dd').format(seek),
        ...?searchConfig?.toQueryParameters(),
      },
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestDetailPage<T>({
    required String galleryUrl,
    int thumbnailsPageIndex = 0,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    required EHHtmlParser<T> parser,
  }) async {
    Response response = await _getWithErrorHandler(
      galleryUrl,
      queryParameters: {
        'p': thumbnailsPageIndex,

        /// show all comments
        'hc': PreferenceSetting.showAllComments.isTrue ? 1 : 0,
      },
      cancelToken: cancelToken,
      options: useCacheIfAvailable ? CacheOptions.cacheOptions.toOptions() : CacheOptions.noCacheOptions.toOptions(),
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestRanklistPage<T>({required RanklistType ranklistType, required int pageNo, required EHHtmlParser<T> parser}) async {
    int tl;

    switch (ranklistType) {
      case RanklistType.day:
        tl = 15;
        break;
      case RanklistType.month:
        tl = 13;
        break;
      case RanklistType.year:
        tl = 12;
        break;
      case RanklistType.allTime:
        tl = 11;
        break;
      default:
        tl = 15;
    }

    Response response = await _getWithErrorHandler('${EHConsts.ERanklist}?tl=$tl&p=$pageNo');
    return _parseResponse(response, parser);
  }

  static Future<T> requestSubmitRating<T>(int gid, String token, int apiuid, String apikey, int rating, EHHtmlParser<T> parser) async {
    Response response = await _postWithErrorHandler(
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
    return _parseResponse(response, parser);
  }

  static Future<T> requestPopupPage<T>(int gid, String token, String act, EHHtmlParser<T> parser) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response response = await _getWithErrorHandler(
      EHConsts.EPopup,
      queryParameters: {
        'gid': gid,
        't': token,
        'act': act,
      },
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestFavoritePage<T>(EHHtmlParser<T> parser) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response response = await _getWithErrorHandler(EHConsts.EFavorite);

    return _parseResponse(response, parser);
  }

  static Future<T> requestChangeFavoriteSortOrder<T>(FavoriteSortOrder sortOrder, {EHHtmlParser<T>? parser}) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response response = await _getWithErrorHandler(
      EHConsts.EFavorite,
      queryParameters: {
        'inline_set': sortOrder == FavoriteSortOrder.publishedTime ? 'fs_p' : 'fs_f',
      },
    );

    return _parseResponse(response, parser);
  }

  /// favcat: the favorite tag index
  static Future<T> requestAddFavorite<T>(int gid, String token, int favcat, {EHHtmlParser<T>? parser}) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response response = await _postWithErrorHandler(
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
        'apply': 'Add to Favorites',
        'update': 1,
      },
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestRemoveFavorite<T>(int gid, String token, {EHHtmlParser<T>? parser}) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response response = await _postWithErrorHandler(
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
    return _parseResponse(response, parser);
  }

  static Future<T> requestImagePage<T>(
    String href, {
    CancelToken? cancelToken,
    bool useCacheIfAvailable = true,
    required EHHtmlParser<T> parser,
  }) async {
    Response response = await _getWithErrorHandler(
      href,
      cancelToken: cancelToken,
      options: useCacheIfAvailable ? CacheOptions.cacheOptions.toOptions() : CacheOptions.noCacheOptions.toOptions(),
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestTorrentPage<T>(int gid, String token, EHHtmlParser<T> parser) async {
    Response response = await _getWithErrorHandler(
      EHConsts.ETorrent,
      queryParameters: {
        'gid': gid,
        't': token,
      },
      options: CacheOptions.cacheOptions.toOptions(),
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestSettingPage<T>(EHHtmlParser<T> parser) async {
    Response response = await _getWithErrorHandler(EHConsts.EUconfig);
    return _parseResponse(response, parser);
  }

  static Future<T> createProfile<T>({EHHtmlParser<T>? parser}) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EUconfig,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'profile_action': 'create',
        'profile_name': 'JHenTai',
        'profile_set': '616',
      },
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestMyTagsPage<T>({int tagSetNo = 1, required EHHtmlParser<T> parser}) async {
    Response response = await _getWithErrorHandler(
      EHConsts.EMyTags,
      queryParameters: {'tagset': tagSetNo},
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestStatPage<T>({required int gid, required String token, required EHHtmlParser<T> parser}) async {
    Response response = await _getWithErrorHandler(
      '${EHConsts.EStat}?gid=$gid&t=$token',
      options: CacheOptions.cacheOptions.toOptions(),
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestAddTagSet<T>({
    required String tag,
    String? tagColor,
    required int tagWeight,
    required bool watch,
    required bool hidden,
    EHHtmlParser<T>? parser,
  }) async {
    Map data = {
      'usertag_action': "add",
      'tagname_new': tag,
      'tagcolor_new': tagColor ?? "",
      'usertag_target': 0,
      'tagweight_new': tagWeight,
    };

    if (hidden) {
      data['taghide_new'] = 'on';
    }
    if (watch) {
      data['tagwatch_new'] = 'on';
    }

    Response response;
    try {
      response = await _postWithErrorHandler(
        EHConsts.EMyTags,
        options: Options(contentType: Headers.formUrlEncodedContentType),
        data: data,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 302) {
        response = e.response!;
      } else {
        rethrow;
      }
    }

    return _parseResponse(response, parser);
  }

  static Future<T> requestDeleteTagSet<T>({required int tagSetId, EHHtmlParser<T>? parser}) async {
    Response response;
    try {
      response = await _postWithErrorHandler(
        EHConsts.EMyTags,
        options: Options(contentType: Headers.formUrlEncodedContentType),
        data: {
          'usertag_action': 'mass',
          'tagname_new': '',
          'tagcolor_new': '',
          'usertag_target': 0,
          'tagweight_new': 10,
          'modify_usertags[]': tagSetId,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 302) {
        rethrow;
      }
      response = e.response!;
    }

    return _parseResponse(response, parser);
  }

  static Future<T> requestUpdateTagSet<T>({
    required int apiuid,
    required String apikey,
    required int tagId,
    required String? tagColor,
    required int tagWeight,
    required bool watch,
    required bool hidden,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EHApi,
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'method': "setusertag",
        'apiuid': apiuid,
        'apikey': apikey,
        'tagcolor': tagColor ?? "",
        'taghide': hidden ? 1 : 0,
        'tagwatch': watch ? 1 : 0,
        'tagid': tagId,
        'tagweight': tagWeight.toString(),
      },
    );
    return _parseResponse(response, parser);
  }

  static Future<T> download<T>({
    required String url,
    required String path,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    bool appendMode = false,
    bool preserveHeaderCase = true,
    int? receiveTimeout,
    String? range,
    bool deleteOnError = true,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _dio.download(
      url,
      path,
      onReceiveProgress: onReceiveProgress,
      shouldAppendFile: appendMode,
      cancelToken: cancelToken,
      deleteOnError: deleteOnError,
      options: Options(
        preserveHeaderCase: preserveHeaderCase,
        headers: range == null ? null : {'Range': range},
        receiveTimeout: Duration(milliseconds: receiveTimeout ?? 0),
      ),
    );

    if (parser == null) {
      return response as T;
    }
    return parser(response.headers, response.data);
  }

  static Future<T> voteTag<T>(int gid, String token, int apiuid, String apikey, String tag, bool isVotingUp, {EHHtmlParser<T>? parser}) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EApi,
      data: {
        'apikey': apikey,
        'apiuid': apiuid,
        'gid': gid,
        'method': "taggallery",
        'token': token,
        'vote': isVotingUp ? 1 : -1,
        'tags': tag,
      },
    );
    return _parseResponse(response, parser);
  }

  static Future<T> voteComment<T>(int gid, String token, int apiuid, String apikey, int commentId, bool isVotingUp, {EHHtmlParser<T>? parser}) async {
    Response response = await _postWithErrorHandler(
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
    return _parseResponse(response, parser);
  }

  static Future<T> requestTagSuggestion<T>(String keyword, EHHtmlParser<T> parser) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EApi,
      data: {
        'method': "tagsuggest",
        'text': keyword,
      },
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestSendComment<T>({
    required String galleryUrl,
    required String content,
    required EHHtmlParser<T> parser,
  }) async {
    Response response = await _postWithErrorHandler(
      galleryUrl,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'commenttext_new': content,
      },
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestUpdateComment<T>({
    required String galleryUrl,
    required String content,
    required int commentId,
    required EHHtmlParser<T> parser,
  }) async {
    Response response = await _postWithErrorHandler(
      galleryUrl,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'edit_comment': commentId,
        'commenttext_edit': content,
      },
    );
    return _parseResponse(response, parser);
  }

  static Future<T> requestLookup<T>({
    required String imagePath,
    required String imageName,
    required EHHtmlParser<T> parser,
  }) async {
    try {
      await _postWithErrorHandler(
        EHConsts.ELookup,
        data: FormData.fromMap({
          'sfile': MultipartFile.fromFileSync(
            imagePath,
            filename: imageName,
            contentType: MediaType.parse('application/octet-stream'),
          ),
          'f_sfile': "File Search",
          'fs_similar': 'on',
          'fs_exp': 'on',
        }),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 302) {
        rethrow;
      }

      return _parseResponse(e.response!, parser);
    }

    throw EHSiteException(message: 'Look up response error', type: EHSiteExceptionType.intelNelError);
  }

  static Future<T> requestUnlockArchive<T>({
    required String url,
    required bool isOriginal,
    CancelToken? cancelToken,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _postWithErrorHandler(
      url,
      data: FormData.fromMap({
        'dltype': isOriginal ? 'org' : 'res',
        'dlcheck': isOriginal ? 'Download Original Archive' : 'Download Resample Archive',
      }),
      cancelToken: cancelToken,
    );

    return _parseResponse(response, parser);
  }

  static Future<T> requestCancelUnlockArchive<T>({required String url, EHHtmlParser<T>? parser}) async {
    Response response = await _postWithErrorHandler(
      url,
      data: FormData.fromMap({'invalidate_sessions': 1}),
    );

    return _parseResponse(response, parser);
  }

  static Future<T> requestHHDownload<T>({
    required String url,
    required String resolution,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _postWithErrorHandler(
      url,
      data: FormData.fromMap({'hathdl_xres': resolution}),
    );

    return _parseResponse(response, parser);
  }

  static Future<T> requestExchangePage<T>({EHHtmlParser<T>? parser}) async {
    Response response = await _getWithErrorHandler(EHConsts.EExchange);

    return _parseResponse(response, parser);
  }

  static Future<T> requestResetImageLimit<T>({EHHtmlParser<T>? parser}) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EHome,
      data: FormData.fromMap({
        'reset_imagelimit': 'Reset Limit',
      }),
    );

    return _parseResponse(response, parser);
  }

  static Future<T> request<T>({
    required String url,
    CancelToken? cancelToken,
    Options? options,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _getWithErrorHandler(url, cancelToken: cancelToken, options: options);

    return _parseResponse(response, parser);
  }

  static Future<T> _parseResponse<T>(Response response, EHHtmlParser<T>? parser) async {
    if (parser == null) {
      return response as T;
    }
    return _isolate.isolate((list) => parser(list[0], list[1]), [response.headers, response.data]);
  }

  static Future<Response> _getWithErrorHandler<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    Response response;

    try {
      response = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _convertExceptionIfGalleryDeleted(e);
    }

    try {
      emitEHExceptionIfFailed(response);
    } on EHSiteException catch (_) {
      removeCacheByUrl(response.requestOptions.uri.toString());
      rethrow;
    }

    return response;
  }

  static Future<Response> _postWithErrorHandler<T>(
    String url, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    Response response;
    try {
      response = await _dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _convertExceptionIfGalleryDeleted(e);
    }

    emitEHExceptionIfFailed(response);

    return response;
  }

  static Exception _convertExceptionIfGalleryDeleted(DioException e) {
    if (e.response?.statusCode == 404 && NetworkSetting.allHostAndIPs.contains(e.requestOptions.uri.host)) {
      String? errMessage = EHSpiderParser.a404Page2GalleryDeletedHint(e.response!.headers, e.response!.data);
      if (!isEmptyOrNull(errMessage)) {
        return EHSiteException(
          type: EHSiteExceptionType.galleryDeleted,
          message: errMessage!,
          shouldPauseAllDownloadTasks: false,
        );
      }
    }

    return e;
  }

  static void emitEHExceptionIfFailed(Response response) {
    if (!NetworkSetting.allHostAndIPs.contains(response.requestOptions.uri.host)) {
      return;
    }

    if (response.data is String) {
      String data = response.data.toString();

      if (data.isEmpty) {
        throw EHSiteException(type: EHSiteExceptionType.blankBody, message: 'sadPanda'.tr);
      }

      if (data.startsWith('Your IP address')) {
        throw EHSiteException(type: EHSiteExceptionType.banned, message: response.data);
      }

      if (data.startsWith('You have exceeded your image')) {
        throw EHSiteException(type: EHSiteExceptionType.exceedLimit, message: 'exceedImageLimits'.tr);
      }
    }
  }
}
