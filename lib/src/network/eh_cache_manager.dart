import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:jhentai/src/database/dao/dio_cache_dao.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/service/log.dart';

import '../database/database.dart';

class EHCacheManager extends Interceptor {
  final CacheOptions _options;
  final SqliteCacheStore _store;

  static const allowedStatusCodes = [
    // OK
    200,
    // Non-Authoritative Information
    203,
    // Moved Permanently
    301,
    // No-Content
    304,
    // Found
    302,
    // Temporary Redirect
    307
  ];

  static const String realUriExtraKey = 'realUri';

  EHCacheManager({required CacheOptions options})
      : assert(options.store != null),
        _options = options,
        _store = options.store!;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final CacheOptions cacheOptions = _getCacheOptions(options);
      options.extra[realUriExtraKey] = _computeCachedUrl(options, cacheOptions);

      if (_shouldSkipRequest(options, cacheOptions)) {
        handler.next(options);
        return;
      }

      final String cacheKey = CacheOptions.defaultCacheKeyBuilder(options);
      _getCacheStore(cacheOptions).get(cacheKey).then((CacheResponse? cacheResponse) {
        if (cacheResponse != null && cacheResponse.url == options.uri.toString()) {
          if (cacheResponse.expired()) {
            _deleteCacheResponse(cacheResponse, cacheOptions).then((_) {
              handler.next(options);
            }).catchError((e) {
              log.error('delete expired cache failed', e);
              handler.next(options);
            });
            return;
          }

          log.trace('cache hit: ${options.uri.toString()}');
          _updateCacheResponse(cacheResponse, cacheOptions).then((updatedCache) {
            handler.resolve(updatedCache.toResponse(options), true);
          }).catchError((e) {
            log.error('update cache failed', e);
            handler.next(options);
          });
          return;
        }
        handler.next(options);
      }).catchError((e) {
        log.error('get cache failed', e);
        handler.next(options);
      });
    } catch (e) {
      log.error('cache interceptor onRequest sync error', e);
      handler.next(options);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      final CacheOptions cacheOptions = _getCacheOptions(response.requestOptions);

      if (_shouldSkipResponse(response, cacheOptions)) {
        handler.next(response);
        return;
      }

      _saveResponse(response, cacheOptions).then((_) {
        handler.next(response);
      }).catchError((e) {
        log.error('save cache failed', e);
        handler.next(response);
      });
    } catch (e) {
      log.error('cache interceptor onResponse sync error', e);
      handler.next(response);
    }
  }

  Future<void> removeCacheByUrl(String url) {
    String cacheKey = CacheOptions.defaultCacheKeyBuilder(RequestOptions(extra: {EHCacheManager.realUriExtraKey: url}));
    return _store.delete(cacheKey);
  }

  Future<void> removeCacheByUrlPrefix(String url) {
    return _store.deleteWithUrlPrefix(url);
  }

  Future<void> removeAllCache() {
    return _store.cleanAll();
  }

  CacheOptions _getCacheOptions(RequestOptions request) {
    return CacheOptions.fromExtra(request) ?? _options;
  }

  SqliteCacheStore _getCacheStore(CacheOptions options) {
    return options.store ?? _store;
  }

  String _computeCachedUrl(RequestOptions options, CacheOptions cacheOptions) {
    String cachedUrl = options.uri.toString();
    if (cacheOptions.ignoreParams) {
      Uri raw = Uri.parse(cachedUrl);
      Uri replaced = Uri(
        scheme: raw.scheme,
        userInfo: raw.userInfo,
        host: raw.host,
        port: raw.port,
        path: raw.path,
        query: null,
        fragment: raw.fragment.isEmpty ? null : raw.fragment,
      );
      cachedUrl = replaced.toString();
    }

    return cachedUrl;
  }
  
  bool _shouldSkipRequest(RequestOptions requestOptions, CacheOptions cacheOptions) {
    if (requestOptions.method.toUpperCase() == 'POST') {
      return true;
    }

    if (cacheOptions.policy != CachePolicy.cache) {
      return true;
    }

    return false;
  }

  bool _shouldSkipResponse(Response response, CacheOptions cacheOptions) {
    if (response.extra[CacheResponse.extraKey] != null) {
      return true;
    }

    if (response.requestOptions.method.toUpperCase() == 'POST') {
      return true;
    }

    if (cacheOptions.policy == CachePolicy.disable) {
      return true;
    }

    if (!allowedStatusCodes.contains(response.statusCode)) {
      return true;
    }

    return false;
  }

  Future<void> _saveResponse(Response response, CacheOptions cacheOptions) async {
    CacheResponse cacheResponse = CacheResponse.fromResponse(response, cacheOptions);

    await _getCacheStore(cacheOptions).upsertCache(cacheResponse);

    response.extra[CacheResponse.extraKey] = cacheResponse.cacheKey;
  }

  Future<CacheResponse> _updateCacheResponse(CacheResponse cacheResponse, CacheOptions cacheOptions) async {
    CacheResponse newCacheResponse = cacheResponse.copyWith(expireDate: DateTime.now().add(cacheOptions.expire));
    await _getCacheStore(cacheOptions).upsertCache(newCacheResponse);
    return newCacheResponse;
  }

  Future<void> _deleteCacheResponse(CacheResponse cacheResponse, CacheOptions cacheOptions) async {
    await _getCacheStore(cacheOptions).delete(cacheResponse.cacheKey);
  }
}

enum CachePolicy {
  /// not use and not save cache
  disable,

  /// not use but save cache
  noCache,

  /// use and save cache
  cache,
}

class CacheOptions {
  final CachePolicy policy;

  final Duration expire;

  final SqliteCacheStore? store;

  final bool ignoreParams;

  static const _extraKey = '@cache_options@';

  static get noCacheOptions => CacheOptions(policy: CachePolicy.noCache, expire: networkSetting.pageCacheMaxAge.value);

  static get noCacheOptionsIgnoreParams => CacheOptions(policy: CachePolicy.noCache, expire: networkSetting.pageCacheMaxAge.value, ignoreParams: true);

  static get cacheOptions => CacheOptions(policy: CachePolicy.cache, expire: networkSetting.pageCacheMaxAge.value);

  static get cacheOptionsIgnoreParams => CacheOptions(policy: CachePolicy.cache, expire: networkSetting.pageCacheMaxAge.value, ignoreParams: true);

  const CacheOptions({this.policy = CachePolicy.cache, required this.expire, this.store, this.ignoreParams = false});

  static CacheOptions? fromExtra(RequestOptions request) {
    return request.extra[_extraKey];
  }

  static String defaultCacheKeyBuilder(RequestOptions request) {
    return md5.convert(utf8.encode(request.extra[EHCacheManager.realUriExtraKey])).toString();
  }

  Map<String, dynamic> toExtra() {
    return {_extraKey: this};
  }

  Options toOptions() {
    return Options(extra: toExtra());
  }

  CacheOptions copyWith({CachePolicy? policy, Duration? expire, SqliteCacheStore? store}) {
    return CacheOptions(policy: policy ?? this.policy, expire: expire ?? this.expire, store: store ?? this.store);
  }
}

class CacheResponse {
  final String url;

  final String cacheKey;

  final Uint8List content;

  final Uint8List headers;

  final DateTime expireDate;

  static const extraKey = '@cache_key@';

  CacheResponse({required this.url, required this.cacheKey, required this.content, required this.headers, required this.expireDate});

  static CacheResponse fromResponse(Response response, CacheOptions options) {
    return CacheResponse(
      content: _serializeContent(response.requestOptions.responseType, response.data),
      expireDate: DateTime.now().add(options.expire),
      headers: utf8.encode(jsonEncode(response.headers.map)),
      cacheKey: CacheOptions.defaultCacheKeyBuilder(response.requestOptions),
      url: response.requestOptions.extra[EHCacheManager.realUriExtraKey] ?? response.requestOptions.uri.toString(),
    );
  }

  Response toResponse(RequestOptions options) {
    return Response(
      data: _deserializeContent(options.responseType, content),
      extra: {extraKey: cacheKey},
      headers: _getHeaders(),
      statusCode: 304,
      requestOptions: options,
    );
  }

  bool expired() {
    return DateTime.now().isAfter(expireDate);
  }

  Headers _getHeaders() {
    Headers h = Headers();
    jsonDecode(utf8.decode(headers)).forEach((key, value) => h.set(key, value));
    return h;
  }

  static Uint8List _serializeContent(ResponseType type, dynamic content) {
    if (content == null) {
      return Uint8List(0);
    }

    switch (type) {
      case ResponseType.bytes:
        return content;
      case ResponseType.plain:
        return utf8.encode(content);
      case ResponseType.json:
        return utf8.encode(jsonEncode(content));
      default:
        throw UnsupportedError('Response type not supported : $type.');
    }
  }

  static dynamic _deserializeContent(ResponseType type, List<int>? content) {
    switch (type) {
      case ResponseType.bytes:
        return content;
      case ResponseType.plain:
        return (content != null) ? utf8.decode(content) : null;
      case ResponseType.json:
        return (content != null) ? jsonDecode(utf8.decode(content)) : null;
      default:
        throw UnsupportedError('Response type not supported : $type.');
    }
  }

  CacheResponse copyWith({String? url, String? cacheKey, Uint8List? content, Uint8List? headers, DateTime? expireDate}) {
    return CacheResponse(
      url: url ?? this.url,
      cacheKey: cacheKey ?? this.cacheKey,
      content: content ?? this.content,
      headers: headers ?? this.headers,
      expireDate: expireDate ?? this.expireDate,
    );
  }
}

class SqliteCacheStore {
  final AppDb appDb;

  SqliteCacheStore({required this.appDb}) {
    try {
      cleanExpired();
    } catch (e) {
      log.error('cleanExpired failed', e);
    }
  }

  Future<void> cleanExpired() {
    return DioCacheDao.deleteCacheByDate(DateTime.now());
  }

  Future<void> cleanAll() {
    return DioCacheDao.deleteAllCache();
  }

  Future<void> delete(String key) {
    return DioCacheDao.deleteByCacheKey(key);
  }

  Future<void> deleteWithUrlPrefix(String urlPrefix) {
    return DioCacheDao.deleteCacheLikeUrl(urlPrefix + '%');
  }

  Future<CacheResponse?> get(String key) {
    Future<DioCacheData?> future = DioCacheDao.selectByCacheKey(key);

    return future.then((value) {
      if (value == null) {
        return null;
      }
      return CacheResponse(url: value.url, cacheKey: value.cacheKey, content: value.content, headers: value.headers, expireDate: value.expireDate);
    });
  }

  Future<void> upsertCache(CacheResponse response) {
    return DioCacheDao.upsertCache(
      DioCacheData(
        url: response.url,
        cacheKey: response.cacheKey,
        content: response.content,
        headers: response.headers,
        expireDate: response.expireDate,
        size: response.content.length,
      ),
    );
  }
}
