import 'dart:async';
import 'dart:io';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart' show ExtendedNetworkImageProvider;
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/get_utils/src/platform/platform.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';
import 'package:jhentai/src/utils/check_util.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/toast_util.dart';
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

    /// error handler
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

    /// domain fronting for dio
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

    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      /// certificate for domain fronting
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        return NetworkSetting.allIPs.contains(host);
      };

      /// https://stackoverflow.com/questions/72913239/flutter-network-proxy-is-ineffective-on-windows
      if (GetPlatform.isDesktop) {
        client.findProxy = (_) => 'PROXY ${NetworkSetting.proxyAddress.value}; DIRECT';
      }
    };

    /// domain fronting for ExtendedNetworkImage
    HttpClient client = ExtendedNetworkImageProvider.httpClient as HttpClient;
    client.badCertificateCallback = (_, __, ___) => true;
    if (GetPlatform.isDesktop) {
      client.findProxy = (_) => 'PROXY ${NetworkSetting.proxyAddress.value}; DIRECT';
    }

    /// cookies
    cookieManager = Get.find<EHCookieManager>();
    _dio.interceptors.add(cookieManager);

    /// cache
    _dio.interceptors.add(Get.find<EHCacheInterceptor>());

    Log.debug('init EHRequest success', false);
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
    required int pageNo,
    SearchConfig? searchConfig,
    required EHHtmlParser<T> parser,
  }) async {
    Response<String> response = await _dio.get(
      url ?? searchConfig!.toPath(),
      queryParameters: {
        'page': pageNo,
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
      queryParameters: {'p': thumbnailsPageIndex},
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

    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
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
