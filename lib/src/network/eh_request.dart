import 'dart:async';
import 'dart:io';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/eh_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'eh_cache_interceptor.dart';
import 'eh_cookie_manager.dart';

typedef EHHtmlParser<T> = T Function(Response response);

class EHRequest {
  static late final Dio _dio;
  static late final EHCookieManager cookieManager;

  static get cacheOption => EHCacheInterceptor.defaultCacheOption.copyWith(
        maxStale: Nullable(AdvancedSetting.pageCacheMaxAge.value),
      );

  static Future<void> init() async {
    _dio = Dio(BaseOptions(
      connectTimeout: 5000,
      receiveTimeout: 6000,
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
          if (!EHConsts.host2Ip.containsKey(e.requestOptions.uri.host) &&
              !EHConsts.host2Ip.containsValue(e.requestOptions.uri.host)) {
            handler.next(e);
            return;
          }
          e.error = 'invisibleHints'.tr;
          handler.next(e);
        },
      ),
    );

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
    cookieManager = Get.find<EHCookieManager>();
    _dio.interceptors.add(cookieManager);

    /// cache
    _dio.interceptors.add(EHCacheInterceptor(options: cacheOption));

    Log.verbose('init EHRequest success', false);
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
    CookieManager().clearCookies();
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
    int thumbnailsPageNo = 0,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    required EHHtmlParser<T> parser,
  }) async {
    Response response = await _dio.get(
      EHSetting.site.value == 'EH' ? galleryUrl : galleryUrl.replaceFirst(EHConsts.EHIndex, EHConsts.EXIndex),
      queryParameters: {'p': thumbnailsPageNo},
      cancelToken: cancelToken,
      options: useCacheIfAvailable
          ? cacheOption.copyWith(policy: CachePolicy.forceCache).toOptions()
          : cacheOption.copyWith(policy: CachePolicy.refreshForceCache).toOptions(),
    );
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestRankPage<T>(EHHtmlParser<T> parser) async {
    Response<String> response = await _dio.get(EHConsts.ERanklist);
    return callWithParamsUploadIfErrorOccurs(() => parser(response), params: response);
  }

  static Future<T> requestSubmitRating<T>(int gid, String token, int apiuid, String apikey, int rating,
      {EHHtmlParser<T>? parser}) async {
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
        'apply': 'Apply Changes',
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
      options: useCacheIfAvailable
          ? cacheOption.copyWith(policy: CachePolicy.forceCache).toOptions()
          : cacheOption.copyWith(policy: CachePolicy.refreshForceCache).toOptions(),
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
      options: cacheOption.copyWith(policy: CachePolicy.forceCache).toOptions(),
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
    Response<String> response = await _dio.get('${EHConsts.EStat}?gid=$gid&t=$token');
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
    int? receiveTimeout,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _dio.download(
      url,
      path,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
      options: Options(
        receiveTimeout: receiveTimeout ?? DownloadSetting.timeout.value * 1000,
        extra: cacheOption.copyWith(policy: CachePolicy.forceCache).toExtra(),
      ),
    );
    parser ??= noOpParser;
    return parser(response);
  }

  static Future<T> voteTag<T>(
      int gid, String token, int apiuid, String apikey, String namespace, String tagName, bool isVotingUp,
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

  static Future<T> voteComment<T>(int gid, String token, int apiuid, String apikey, int commentId, bool isVotingUp,
      {EHHtmlParser<T>? parser}) async {
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
      response = e.response;
    }
    return callWithParamsUploadIfErrorOccurs(() => parser(response!), params: response);
  }

  static Future<T> requestUnlockArchive<T>({
    required String url,
    required int gid,
    required String token,
    required String or,
    required bool isOriginal,
    CancelToken? cancelToken,
    EHHtmlParser<T>? parser,
  }) async {
    Response response = await _dio.post(
      url,
      queryParameters: {
        'gid': gid,
        'token': token,
        'or': or,
      },
      data: FormData.fromMap({
        'dltype': isOriginal ? 'org' : 'res',
        'dlcheck': isOriginal ? 'Download Original Archive' : 'Download Resample Archive',
      }),
      cancelToken: cancelToken,
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
      options: useCacheIfAvailable
          ? cacheOption.copyWith(policy: CachePolicy.forceCache).toOptions()
          : cacheOption.copyWith(policy: CachePolicy.refreshForceCache).toOptions(),
      cancelToken: cancelToken,
    );
    parser ??= noOpParser;
    return callWithParamsUploadIfErrorOccurs(() => parser!(response), params: response);
  }
}
