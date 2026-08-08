import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:jhentai/src/database/dao/dio_cache_dao.dart';
import 'package:jhentai/src/database/dao/smart_cache_stat_dao.dart';
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
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    CacheOptions cacheOptions = _getCacheOptions(options);

    options.extra[realUriExtraKey] = _computeCachedUrl(options, cacheOptions);

    if (_shouldSkipRequest(options, cacheOptions)) {
      handler.next(options);
      return;
    }

    // The caller (read_page_logic) already probed this exact request against
    // the cache explicitly and it missed; skip the redundant SQLite lookup.
    if (options.extra['alreadyProbed'] == true) {
      handler.next(options);
      return;
    }

    CacheResponse? cacheResponse = await _getCacheStore(cacheOptions).get(CacheOptions.defaultCacheKeyBuilder(options));
    if (cacheResponse != null && cacheResponse.url == options.uri.toString()) {
      if (cacheResponse.expired()) {
        await _deleteCacheResponse(cacheResponse, cacheOptions);
        return handler.next(options);
      }

      log.trace('cache hit: ${options.uri.toString()}');
      unawaited(SmartCacheStatDao.recordHit(
        cacheResponse.cacheKey,
        kind: 'page',
        url: cacheResponse.url,
        sizeBytes:
            cacheResponse.content.length + cacheResponse.headers.length,
      ));
      // Only extend the sliding expiry when the entry is close to expiring;
      // otherwise a hot page would turn every read into a DB write.
      if (cacheResponse.willExpireSoon(cacheOptions.expire)) {
        cacheResponse = await _updateCacheResponse(cacheResponse, cacheOptions);
      }
      // Decompress off the UI isolate; [CacheResponse.toResponse] itself stays
      // synchronous to keep the dio interceptor contract unchanged.
      final Uint8List decompressed = await compute(CacheResponse._decompress, cacheResponse.content);
      return handler.resolve(cacheResponse.toResponse(options, decompressedContent: decompressed), true);
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
      log.error('save cache failed', e);
    }

    handler.next(response);
  }

  Future<void> removeCacheByUrl(String url) {
    String cacheKey = CacheOptions.defaultCacheKeyBuilder(RequestOptions(extra: {EHCacheManager.realUriExtraKey: url}));
    return _store.delete(cacheKey).then((_) => SmartCacheStatDao.deleteByKey(cacheKey));
  }

  Future<void> removeCacheByUrlPrefix(String url) {
    return _store
        .deleteWithUrlPrefix(url)
        .then((_) => SmartCacheStatDao.deleteLikeUrl(url));
  }

  Future<void> removeAllCache() {
    return _store.cleanAll().then((_) => SmartCacheStatDao.deleteAll());
  }

  /// Whether a non-expired cache entry exists for the given request,
  /// mirroring the hit conditions used in [onRequest].
  Future<bool> hasCache({
    required String url,
    Map<String, dynamic>? queryParameters,
    CacheOptions? options,
  }) async {
    final CacheOptions cacheOptions = options ?? _options;
    final RequestOptions request = RequestOptions(
      path: url,
      queryParameters: queryParameters ?? const {},
    );
    request.extra[realUriExtraKey] = _computeCachedUrl(request, cacheOptions);

    final CacheResponse? cacheResponse = await _getCacheStore(cacheOptions)
        .get(CacheOptions.defaultCacheKeyBuilder(request));
    return cacheResponse != null &&
        cacheResponse.url == request.uri.toString() &&
        !cacheResponse.expired();
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

    if (!allowedStatusCodes.contains(response?.statusCode)) {
      return true;
    }

    return false;
  }

  Future<void> _saveResponse(Response response, CacheOptions cacheOptions) async {
    CacheResponse cacheResponse = await CacheResponse.fromResponseAsync(response, cacheOptions);

    await _getCacheStore(cacheOptions).upsertCache(cacheResponse);

    response.extra[CacheResponse.extraKey] = cacheResponse.cacheKey;
    unawaited(SmartCacheStatDao.recordWritten(
      cacheResponse.cacheKey,
      kind: 'page',
      url: cacheResponse.url,
      sizeBytes: cacheResponse.content.length + cacheResponse.headers.length,
    ));
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

  static get noCacheOptions => CacheOptions(policy: CachePolicy.noCache, expire: networkSetting.effectivePageCacheMaxAge);

  static get noCacheOptionsIgnoreParams => CacheOptions(policy: CachePolicy.noCache, expire: networkSetting.effectivePageCacheMaxAge, ignoreParams: true);

  static get cacheOptions => CacheOptions(policy: CachePolicy.cache, expire: networkSetting.effectivePageCacheMaxAge);

  static get cacheOptionsIgnoreParams => CacheOptions(policy: CachePolicy.cache, expire: networkSetting.effectivePageCacheMaxAge, ignoreParams: true);

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

  /// Like [fromResponse], but gzip-compresses the serialized content on a
  /// background isolate via [compute] so the UI isolate isn't blocked.
  static Future<CacheResponse> fromResponseAsync(Response response, CacheOptions options) async {
    final Uint8List serialized = _serializeContent(response.requestOptions.responseType, response.data);
    final Uint8List compressed = await compute(_compress, serialized);
    return CacheResponse(
      content: compressed,
      expireDate: DateTime.now().add(options.expire),
      headers: utf8.encode(jsonEncode(response.headers.map)),
      cacheKey: CacheOptions.defaultCacheKeyBuilder(response.requestOptions),
      url: response.requestOptions.extra[EHCacheManager.realUriExtraKey] ?? response.requestOptions.uri.toString(),
    );
  }

  Response toResponse(RequestOptions options, {Uint8List? decompressedContent}) {
    return Response(
      data: _deserializeContent(options.responseType, decompressedContent ?? _decompress(content)),
      extra: {extraKey: cacheKey},
      headers: _getHeaders(),
      statusCode: 304,
      requestOptions: options,
    );
  }

  bool expired() {
    return DateTime.now().isAfter(expireDate);
  }

  /// Whether the entry is close to expiring (within the last 10% of its TTL).
  /// Used to avoid rewriting the sliding expiry on every cache hit.
  bool willExpireSoon(Duration expire) {
    if (expire <= Duration.zero) {
      return false;
    }
    final Duration remaining = expireDate.difference(DateTime.now());
    return remaining.isNegative || remaining < expire * 0.1;
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

  /// Compress content with gzip for storage.
  static Uint8List _compress(Uint8List data) {
    return Uint8List.fromList(gzip.encode(data));
  }

  /// Decompress gzip content; falls back to raw data for backward compatibility
  /// with previously stored uncompressed entries.
  static Uint8List _decompress(Uint8List data) {
    try {
      return Uint8List.fromList(gzip.decode(data));
    } on FormatException {
      return data;
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
      ),
    );
  }
}
