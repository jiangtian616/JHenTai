import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/utils/log.dart';

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

  EHCacheManager({required CacheOptions options})
      : assert(options.store != null),
        _options = options,
        _store = options.store!;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    CacheOptions cacheOptions = _getCacheOptions(options);

    if (_shouldSkipRequest(options, cacheOptions)) {
      handler.next(options);
      return;
    }

    CacheResponse? cacheResponse = await _getCacheStore(cacheOptions).get(CacheOptions.defaultCacheKeyBuilder(options));
    if (cacheResponse != null && cacheResponse.url == options.uri.toString()) {
      if (cacheResponse.expired()) {
        await _deleteCacheResponse(cacheResponse, cacheOptions);
        return handler.next(options);
      }

      Log.verbose('cache hit: ${options.uri.toString()}');
      cacheResponse = await _updateCacheResponse(cacheResponse, cacheOptions);
      return handler.resolve(cacheResponse.toResponse(options), true);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    CacheOptions cacheOptions = _getCacheOptions(response.requestOptions);

    if (_shouldSkipResponse(response, cacheOptions)) {
      return handler.next(response);
    }

    try {
      await _saveResponse(response, cacheOptions);
    } on Exception catch (e) {
      Log.error('save cache failed', e);
    }

    handler.next(response);
  }

  Future<void> removeCacheByUrl(String url) {
    String cacheKey = CacheOptions.defaultCacheKeyBuilder(RequestOptions(path: url));
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

    if (!allowedStatusCodes.contains(response?.statusCode)) {
      return true;
    }

    return false;
  }

  Future<void> _saveResponse(Response response, CacheOptions cacheOptions) async {
    CacheResponse cacheResponse = CacheResponse.fromResponse(response, cacheOptions);

    await _getCacheStore(cacheOptions).insertOrUpdate(cacheResponse);

    response.extra[CacheResponse.extraKey] = cacheResponse.cacheKey;
  }

  Future<CacheResponse> _updateCacheResponse(CacheResponse cacheResponse, CacheOptions cacheOptions) async {
    CacheResponse newCacheResponse = cacheResponse.copyWith(expireDate: DateTime.now().add(cacheOptions.expire));
    await _getCacheStore(cacheOptions).insertOrUpdate(newCacheResponse);
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

  static const _extraKey = '@cache_options@';

  static get noCacheOptions => CacheOptions(policy: CachePolicy.noCache, expire: NetworkSetting.pageCacheMaxAge.value);

  static get cacheOptions => CacheOptions(policy: CachePolicy.cache, expire: NetworkSetting.pageCacheMaxAge.value);

  const CacheOptions({this.policy = CachePolicy.cache, required this.expire, this.store});

  static CacheOptions? fromExtra(RequestOptions request) {
    return request.extra[_extraKey];
  }

  static String defaultCacheKeyBuilder(RequestOptions request) {
    return md5.convert(utf8.encode(request.uri.toString())).toString();
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
      url: response.requestOptions.uri.toString(),
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
    cleanExpired();
  }

  Future<void> cleanExpired() {
    return appDb.deleteCacheByDate(DateTime.now());
  }

  Future<void> cleanAll() {
    return appDb.deleteAllCache();
  }

  Future<void> delete(String key) {
    return appDb.deleteByCacheKey(key);
  }

  Future<void> deleteWithUrlPrefix(String urlPrefix) {
    return appDb.deleteCacheLikeUrl(urlPrefix + '%');
  }

  Future<CacheResponse?> get(String key) {
    Future<DioCacheData?> future = appDb.selectByCacheKey(key).getSingleOrNull();

    return future.then((value) {
      if (value == null) {
        return null;
      }
      return CacheResponse(url: value.url, cacheKey: value.cacheKey, content: value.content, headers: value.headers, expireDate: value.expireDate);
    });
  }

  Future<void> insertOrUpdate(CacheResponse response) {
    return appDb.insertOrUpdateCache(
      response.cacheKey,
      response.url,
      response.expireDate,
      response.content,
      response.headers,
    );
  }
}
