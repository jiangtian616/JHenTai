import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/get_utils/src/platform/platform.dart';
import 'package:http_proxy/http_proxy.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';
import 'package:jhentai/src/utils/check_util.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:system_network_proxy/system_network_proxy.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import '../setting/network_setting.dart';
import 'eh_cache_interceptor.dart';
import 'eh_cookie_manager.dart';

typedef EHHtmlParser<T> = T Function(Response response);

class EHRequest {
  static late final Dio _dio;
  static late final EHCookieManager cookieManager;

  static Future<void> init() async {
    _dio = Dio(BaseOptions(
      connectTimeout: NetworkSetting.connectTimeout.value,
      receiveTimeout: NetworkSetting.receiveTimeout.value,
    ));

    _initErrorHandler();

    _initDomainFronting();

    await _initProxy();

    _initCookies();

    _initCertificateForAndroidWithOldVersion();

    _dio.interceptors.add(Get.find<EHCacheInterceptor>());

    Log.debug('init EHRequest success');
  }

  /// error handler
  static void _initErrorHandler() {
    _dio.interceptors.add(
      InterceptorsWrapper(
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
                response: response,
                error: EHException(type: EHExceptionType.banned, msg: response.data),
              ),
            );
          }
          if (response.data.toString().startsWith('You have exceeded your image')) {
            return handler.reject(
              DioError(
                requestOptions: response.requestOptions,
                error: EHException(type: EHExceptionType.exceedLimit, msg: 'exceedImageLimits'.tr),
              ),
            );
          }
          handler.next(response);
        },
        onError: (e, ErrorInterceptorHandler handler) {
          if (e.response?.statusCode != 404) {
            handler.next(e);
            return;
          }
          if (!NetworkSetting.host2IPs.containsKey(e.requestOptions.uri.host) && !NetworkSetting.allIPs.contains(e.requestOptions.uri.host)) {
            handler.next(e);
            return;
          }

          e.error = EHSpiderParser.galleryDeletedPage2Hint(e.response!);
          handler.next(e);
        },
      ),
    );
  }

  /// domain fronting for dio and proxy
  static Future<void> _initDomainFronting() async {
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

  /// proxy
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
        configAddress =
            '${NetworkSetting.proxyUsername.value ?? ''}:${NetworkSetting.proxyPassword.value ?? ''}@${NetworkSetting.proxyAddress.value}';
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

  /// cookies
  static void _initCookies() {
    cookieManager = Get.find<EHCookieManager>();
    _dio.interceptors.add(cookieManager);
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

  static Future<T> requestLogin<T>(String userName, String passWord, EHHtmlParser<T> parser) async {
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
    return parser(response);
  }

  static Future<void> requestLogout() async {
    cookieManager.removeAllCookies();
    UserSetting.clear();
    if (!GetPlatform.isDesktop) {
      CookieManager().clearCookies();
    }
  }

  static Future<T> requestHomePage<T>({EHHtmlParser<T>? parser}) async {
    Response<String> response = await _dio.get(EHConsts.EHome);
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> requestForum<T>(int ipbMemberId, EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.get(
      EHConsts.EForums,
      queryParameters: {
        'showuser': ipbMemberId,
      },
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
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
    Response<String> response = await _dio.get(
      url ?? searchConfig!.toPath(),
      queryParameters: {
        if (prevGid != null) 'prev': prevGid,
        if (nextGid != null) 'next': nextGid,
        if (seek != null) 'seek': DateFormat('yyyy-MM-dd').format(seek),
        ...?searchConfig?.toQueryParameters(),
      },
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestDetailPage<T>({
    required String galleryUrl,
    int thumbnailsPageIndex = 0,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    required EHHtmlParser<T> parser,
  }) async {
    Response response = await _dio.get(
      galleryUrl,
      queryParameters: {
        'p': thumbnailsPageIndex,

        /// show all comments
        'hc': 1,
      },
      cancelToken: cancelToken,
      options: useCacheIfAvailable ? EHCacheInterceptor.cacheOption.toOptions() : EHCacheInterceptor.refreshCacheOption.toOptions(),
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestRanklistPage<T>({
    required RanklistType ranklistType,
    required int pageNo,
    required EHHtmlParser<T> parser,
  }) async {
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

    Response<String> response = await _dio.get('${EHConsts.ERanklist}?tl=$tl&p=$pageNo');
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestSubmitRating<T>(int gid, String token, int apiuid, String apikey, int rating, {EHHtmlParser<T>? parser}) async {
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
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> requestPopupPage<T>(int gid, String token, String act, EHHtmlParser<T> parser) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await _dio.get(
      EHConsts.EPopup,
      queryParameters: {
        'gid': gid,
        't': token,
        'act': act,
      },
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestFavoritePage<T>(EHHtmlParser<T> parser) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await _dio.get(EHConsts.EFavorite);

    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response.data);
  }

  /// favcat: the favorite tag index
  static Future<T> requestAddFavorite<T>(int gid, String token, int favcat, {EHHtmlParser<T>? parser}) async {
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
        'apply': 'Add to Favorites',
        'update': 1,
      },
    );
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> requestRemoveFavorite<T>(int gid, String token, {EHHtmlParser<T>? parser}) async {
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
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> requestImagePage<T>(
    String href, {
    CancelToken? cancelToken,
    bool useCacheIfAvailable = true,
    required EHHtmlParser<T> parser,
  }) async {
    Response<String> response = await _dio.get(
      href,
      cancelToken: cancelToken,
      options: useCacheIfAvailable ? EHCacheInterceptor.cacheOption.toOptions() : EHCacheInterceptor.refreshCacheOption.toOptions(),
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestTorrentPage<T>(int gid, String token, EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.get(
      EHConsts.ETorrent,
      queryParameters: {
        'gid': gid,
        't': token,
      },
      options: EHCacheInterceptor.cacheOption.toOptions(),
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestSettingPage<T>(EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.get(EHConsts.EUconfig);
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> createProfile<T>({EHHtmlParser<T>? parser}) async {
    Response<String> response = await _dio.post(
      EHConsts.EUconfig,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'profile_action': 'create',
        'profile_name': 'JHenTai',
        'profile_set': '616',
      },
    );
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> requestMyTagsPage<T>({int tagSetNo = 1, required EHHtmlParser<T> parser}) async {
    Response response = await _dio.get(
      EHConsts.EMyTags,
      queryParameters: {'tagset': tagSetNo},
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestStatPage<T>({
    required int gid,
    required String token,
    required EHHtmlParser<T> parser,
  }) async {
    Response<String> response = await _dio.get(
      '${EHConsts.EStat}?gid=$gid&t=$token',
      options: EHCacheInterceptor.cacheOption.toOptions(),
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
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
      response = await _dio.post(
        EHConsts.EMyTags,
        options: Options(contentType: Headers.formUrlEncodedContentType),
        data: data,
      );
    } on DioError catch (e) {
      if (e.response?.statusCode != 302) {
        rethrow;
      }
      response = e.response!;
    }

    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> requestDeleteTagSet<T>({
    required int tagSetId,
    EHHtmlParser<T>? parser,
  }) async {
    Response response;
    try {
      response = await _dio.post(
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
    } on DioError catch (e) {
      if (e.response?.statusCode != 302) {
        rethrow;
      }
      response = e.response!;
    }

    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
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
    Response response = await _dio.post(
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
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> download<T>({
    required String url,
    required String path,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    bool appendMode = false,
    bool caseInsensitiveHeader = true,
    int? receiveTimeout,
    String? range,
    bool deleteOnError = true,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _dio.download(
      url,
      path,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
      appendFile: appendMode,
      deleteOnError: deleteOnError,
      options: Options(
        caseInsensitiveHeader: caseInsensitiveHeader,
        receiveTimeout: receiveTimeout ?? DownloadSetting.timeout.value * 1000,
        extra: EHCacheInterceptor.noCacheOption.toExtra(),
        headers: range == null ? null : {'Range': range},
      ),
    );
    parser ??= noOpParser;
    return parser(response);
  }

  static Future<T> voteTag<T>(int gid, String token, int apiuid, String apikey, String namespace, String tagName, bool isVotingUp,
      {EHHtmlParser<T>? parser}) async {
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
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> voteComment<T>(int gid, String token, int apiuid, String apikey, int commentId, bool isVotingUp, {EHHtmlParser<T>? parser}) async {
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
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> requestTagSuggestion<T>(String keyword, EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.post(
      EHConsts.EApi,
      data: {
        'method': "tagsuggest",
        'text': keyword,
      },
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
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
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestUpdateComment<T>({
    required String galleryUrl,
    required String content,
    required int commentId,
    required EHHtmlParser<T> parser,
  }) async {
    Response<String> response = await _dio.post(
      galleryUrl,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'edit_comment': commentId,
        'commenttext_edit': content,
      },
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestLookup<T>({
    required String imagePath,
    required String imageName,
    required EHHtmlParser<T> parser,
  }) async {
    Response? response;
    try {
      await _dio.post(
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
    } on DioError catch (e) {
      if (e.response?.statusCode != 302) {
        rethrow;
      }

      CheckUtil.build(() => e.response != null, errorMsg: "Lookup response shouldn't be null!")
          .withUploadParam(e)
          .onFailed(() => toast('systemError'.tr))
          .check();

      response = e.response;
    }
    return callWithParamsUploadIfErrorOccurs(() => parser(response!), params: response);
  }

  static Future<T> requestUnlockArchive<T>({
    required String url,
    required bool isOriginal,
    CancelToken? cancelToken,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _dio.post(
      url,
      data: FormData.fromMap({
        'dltype': isOriginal ? 'org' : 'res',
        'dlcheck': isOriginal ? 'Download Original Archive' : 'Download Resample Archive',
      }),
      cancelToken: cancelToken,
    );

    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> requestCancelUnlockArchive<T>({required String url, EHHtmlParser<T>? parser}) async {
    Response response = await _dio.post(
      url,
      data: FormData.fromMap({'invalidate_sessions': 1}),
    );

    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> requestHHDownload<T>({
    required String url,
    required String resolution,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _dio.post(
      url,
      data: FormData.fromMap({'hathdl_xres': resolution}),
    );

    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }

  static Future<T> request<T>({
    required String url,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    EHHtmlParser<T>? parser,
  }) async {
    Response? response = await _dio.get(
      url,
      options: useCacheIfAvailable ? EHCacheInterceptor.cacheOption.toOptions() : EHCacheInterceptor.refreshCacheOption.toOptions(),
      cancelToken: cancelToken,
    );
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }
}
