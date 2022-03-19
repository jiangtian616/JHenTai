import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'eh_cookie_manager.dart';

class EHRequest {
  static late final Dio dio;
  static late final PersistCookieJar _cookieJar;

  static Future<void> init() async {
    dio = Dio(BaseOptions(
      connectTimeout: 3000,
      receiveTimeout: 5000,
    ));

    _cookieJar = PersistCookieJar(storage: FileStorage(PathSetting.appSupportDir.path + "/.cookies/"));
    await _cookieJar.forceInit();

    await storeEhCookiesForAllUri([
      /// never warn about offensive gallery
      Cookie("nw", "1"),
    ]);

    /// cookies
    dio.interceptors.add(EHCookieManager(_cookieJar));

    /// domain fronting
    dio.interceptors.add(InterceptorsWrapper(
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
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        return EHConsts.host2Ip.containsValue(host);
      };
    };

    /// error handler
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        if ((response.data.toString()).isEmpty) {
          return handler.reject(
            DioError(
              requestOptions: response.requestOptions,
              error: EHException(type: EHExceptionType.blankBody, msg: "IP限制"),
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

    Log.info('EHRequest init success', false);
  }

  static Future<void> storeEhCookiesForAllUri(List<Cookie> cookies) async {
    Future.wait(EHConsts.host2Ip.keys.map((host) => _storeCookies('https://' + host, cookies)));
    Future.wait(EHConsts.host2Ip.values.map((ip) => _storeCookies('https://' + ip, cookies)));
  }

  static Future<void> removeAllCookies() async {
    await _cookieJar.deleteAll();
  }

  /// return null if login success, otherwise return error message
  static Future<String?> login(String userName, String passWord) async {
    await logout();

    Response<String> response = await dio.post(
      EHConsts.EHForums,
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

    return _parseErrorMsg(response.data!);
  }

  /// just remove cookies
  static Future<void> logout() async {
    _cookieJar.deleteAll();
    UserSetting.clear();
  }

  /// return null if cookie is wrong
  static Future<List<String?>?> getUserInfoByCookieAndMemberId(int ipbMemberId) async {
    Response<String> response = await dio.get(
      EHConsts.EHForums,
      queryParameters: {
        'showuser': ipbMemberId,
      },
    );
    return EHSpiderParser.parseUserInfo(response.data!);
  }

  static Future<List<dynamic>> getHomeGallerysListAndPageCountByPageNo(int pageNo, SearchConfig? searchConfig) async {
    Response<String> response = await dio.get(
      EHConsts.EHHome,
      queryParameters: {
        'page': pageNo,
      },
    );
    return EHSpiderParser.parseHomeGallerysList(response.data!);
  }

  static Future<Map<String, dynamic>> getGalleryDetailsAndApikey(
      {required String galleryUrl, int thumbnailsPageNo = 0}) async {
    Response<String> response = await dio.get(
      galleryUrl,
      queryParameters: {'p': thumbnailsPageNo},
    );
    return EHSpiderParser.parseGalleryDetails(response.data!);
  }

  /// only parse Thumbnails
  static Future<List<GalleryThumbnail>> getGalleryDetailsThumbnailByPageNo(
      {required String galleryUrl, int thumbnailsPageNo = 0}) async {
    Response<String> response = await dio.get(
      galleryUrl,
      queryParameters: {'p': thumbnailsPageNo},
    );
    return EHSpiderParser.parseGalleryDetailsThumbnails(response.data!);
  }

  static Future<String> submitRating(int gid, String token, int apiuid, String apikey, int rating) async {
    Response<String> response = await dio.post(
      EHConsts.EHApi,
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

  static Future<T> getPopupPage<T>(int gid, String token, String act, T Function(String html) parser) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await dio.get(
      EHConsts.EHPopup,
      queryParameters: {
        'gid': gid,
        't': token,
        'act': act,
      },
    );
    return parser.call(response.data!);
  }

  static Future<LinkedHashMap<String, int>> getFavoriteTags() async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await dio.get(
      EHConsts.EHFavorite,
    );
    return EHSpiderParser.parseFavoriteTags(response.data!);
  }

  /// favcat: the favorite tag index
  static Future<bool> addFavorite(int gid, String token, int favcat) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await dio.post(
      EHConsts.EHPopup,
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
    return response.statusCode == 200;
  }

  static Future<bool> removeFavorite(int gid, String token) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response<String> response = await dio.post(
      EHConsts.EHPopup,
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
    return response.statusCode == 200;
  }

  static Future<GalleryImage> getGalleryImage(String href) async {
    Response<String> response = await dio.post(href);
    return EHSpiderParser.parseGalleryImage(response.data!);
  }

  static Future<bool> downloadGalleryImage({
    required String url,
    required String path,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    await dio.download(
      url,
      path,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.stream, receiveTimeout: 8000),
    );
    return true;
  }

  static String _parseErrorMsg(String html) {
    if (html.contains('The captcha was not entered correctly')) {
      return 'needCaptcha'.tr;
    }
    return 'userNameOrPasswordMismatch'.tr;
  }

  static Future<void> _storeCookies(String uri, List<Cookie> cookies) async {
    await _cookieJar.saveFromResponse(Uri.parse(uri), cookies);
  }
}
