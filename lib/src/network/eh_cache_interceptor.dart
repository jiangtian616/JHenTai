import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor/src/model/cache_strategy.dart';
import 'package:dio_cache_interceptor/src/util/response_extension.dart';
import 'package:dio_cache_interceptor_db_store/dio_cache_interceptor_db_store.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart';

import '../setting/network_setting.dart';
import '../setting/path_setting.dart';

/// copied from [DioCacheInterceptor]
class EHCacheInterceptor extends Interceptor {
  static const String _getMethodName = 'GET';
  static const String _postMethodName = 'POST';
  final CacheOptions _options;
  final CacheStore _store;

  static CacheOptions noCacheOption = CacheOptions(
    store: DbCacheStore(databasePath: join(PathSetting.getVisibleDir().path, 'cache')),
    policy: CachePolicy.noCache,
    hitCacheOnErrorExcept: [401, 403],
    priority: CachePriority.normal,
    cipher: null,
    keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    allowPostMethod: false,
  );

  static CacheOptions get cacheOption => noCacheOption.copyWith(
        maxStale: Nullable(NetworkSetting.pageCacheMaxAge.value),
        policy: CachePolicy.forceCache,
      );

  static CacheOptions get refreshCacheOption => noCacheOption.copyWith(
        maxStale: Nullable(NetworkSetting.pageCacheMaxAge.value),
        policy: CachePolicy.refreshForceCache,
      );

  EHCacheInterceptor({required CacheOptions options})
      : assert(options.store != null),
        _options = options,
        _store = options.store!;

  static Future<void> init() async {
    Get.put<EHCacheInterceptor>(EHCacheInterceptor(options: noCacheOption));
    Log.debug('init EHCacheInterceptor success');
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add time when the request has been sent
    // for further expiry calculation.
    options.extra[CacheResponse.requestSentDate] = DateTime.now();

    final cacheOptions = _getCacheOptions(options);

    if (_shouldSkip(options, options: cacheOptions)) {
      handler.next(options);
      return;
    }

    // Early ends if policy does not require cache lookup.
    final policy = cacheOptions.policy;
    if (policy != CachePolicy.request && policy != CachePolicy.forceCache) {
      handler.next(options);
      return;
    }

    final strategy = await CacheStrategyFactory(
      request: options,
      cacheResponse: await _loadResponse(options),
      cacheOptions: cacheOptions,
    ).compute();

    var cacheResponse = strategy.cacheResponse;
    if (cacheResponse != null) {
      // Cache hit
      Log.verbose('hit cache: ${cacheResponse.url}', false);
      // Update cached response if needed
      cacheResponse = await _updateCacheResponse(cacheResponse, cacheOptions);

      handler.resolve(
        cacheResponse.toResponse(options, fromNetwork: false),
        true,
      );
      return;
    }

    // Requests with conditional request if available
    // or requests with given options
    handler.next(strategy.request ?? options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final cacheOptions = _getCacheOptions(response.requestOptions);

    if (_shouldSkip(
      response.requestOptions,
      response: response,
      options: cacheOptions,
    )) {
      handler.next(response);
      return;
    }

    if (cacheOptions.policy == CachePolicy.noCache) {
      // Delete previous potential cached response
      await _getCacheStore(cacheOptions).delete(
        cacheOptions.keyBuilder(response.requestOptions),
      );
    }

    await _saveResponse(
      response,
      cacheOptions,
      statusCode: response.statusCode,
    );

    handler.next(response);
  }

  @override
  void onError(
    DioError err,
    ErrorInterceptorHandler handler,
  ) async {
    final cacheOptions = _getCacheOptions(err.requestOptions);

    if (_shouldSkip(err.requestOptions, options: cacheOptions, error: err)) {
      handler.next(err);
      return;
    }

    if (_isCacheCheckAllowed(err.response, cacheOptions)) {
      // Retrieve response from cache
      final existing = await _loadResponse(err.requestOptions);
      // Transform CacheResponse to Response object
      final cacheResponse = existing?.toResponse(err.requestOptions);

      if (err.response != null && cacheResponse != null) {
        // Update cache response with response header values
        await _saveResponse(
          cacheResponse..updateCacheHeaders(err.response),
          cacheOptions,
          statusCode: err.response?.statusCode,
        );
      }

      // Resolve with found cached response
      if (cacheResponse != null) {
        handler.resolve(cacheResponse);
        return;
      }
    }

    handler.next(err);
  }

  Future<void> removeGalleryDetailPageCache(String galleryUrl) {
    return Future.wait(
      [
        removeCacheByUrl('$galleryUrl?p=0&hc=0'),
        removeCacheByUrl('$galleryUrl?p=0&hc=1'),
      ],
    );
  }

  Future<void> removeCacheByUrl(String url) async {
    RequestOptions request = RequestOptions(path: url);
    CacheOptions cacheOptions = _getCacheOptions(request);
    CacheStore cacheStore = _getCacheStore(cacheOptions);
    await cacheStore.delete(cacheOptions.keyBuilder(request));

    for (MapEntry entry in NetworkSetting.currentHost2IP.entries) {
      url = url.replaceFirst(entry.key, entry.value);
    }
    request = RequestOptions(path: url);
    cacheOptions = _getCacheOptions(request);
    cacheStore = _getCacheStore(cacheOptions);
    await cacheStore.delete(cacheOptions.keyBuilder(request));
  }

  Future<void> removeAllCache() async {
    await _store.clean();
  }

  /// Gets cache options from given [request]
  /// or defaults to interceptor options.
  CacheOptions _getCacheOptions(RequestOptions request) {
    return CacheOptions.fromExtra(request) ?? _options;
  }

  /// Gets cache store from given [options]
  /// or defaults to interceptor store.
  CacheStore _getCacheStore(CacheOptions options) {
    return options.store ?? _store;
  }

  /// Check if the callback should not be proceed against HTTP method
  /// or cancel error type.
  bool _shouldSkip(
    RequestOptions? request, {
    required CacheOptions options,
    Response? response,
    DioError? error,
  }) {
    if (error?.type == DioErrorType.cancel) {
      return true;
    }

    if (response?.extra[CacheResponse.cacheKey] != null) {
      return true;
    }

    final rqMethod = request?.method.toUpperCase();
    var result = (rqMethod != _getMethodName);
    result &= (!options.allowPostMethod || rqMethod != _postMethodName);

    return result;
  }

  /// Reads cached response from cache store.
  Future<CacheResponse?> _loadResponse(RequestOptions request) async {
    final options = _getCacheOptions(request);
    final cacheKey = options.keyBuilder(request);
    final cacheStore = _getCacheStore(options);
    final response = await _getCacheStore(options).get(cacheKey);

    if (response != null) {
      if (response.isStaled()) {
        await cacheStore.delete(cacheKey);
        return null;
      }

      response.content = await CacheCipher.decryptContent(
        options,
        response.content,
      );
      response.headers = await CacheCipher.decryptContent(
        options,
        response.headers,
      );
    }

    return response;
  }

  /// Writes cached response to cache store if strategy allows it.
  Future<void> _saveResponse(
    Response response,
    CacheOptions cacheOptions, {
    int? statusCode,
  }) async {
    final strategy = await CacheStrategyFactory(
      request: response.requestOptions,
      response: response,
      cacheOptions: cacheOptions,
    ).compute();

    final cacheResp = strategy.cacheResponse;
    if (cacheResp != null) {
      // Store response to cache store
      await _getCacheStore(cacheOptions).set(cacheResp);

      // Update extra fields with cache info
      response.extra[CacheResponse.cacheKey] = cacheResp.key;
      response.extra[CacheResponse.fromNetwork] = CacheStrategyFactory.allowedStatusCodes.contains(statusCode);
    }
  }

  /// Checks if we can try to resolve cached response
  /// against given [err] and [cacheOptions].
  bool _isCacheCheckAllowed(Response? errResponse, CacheOptions cacheOptions) {
    // Determine if we can return cached response
    if (errResponse?.statusCode == 304) {
      return true;
    } else {
      final hcoeExcept = cacheOptions.hitCacheOnErrorExcept;
      if (hcoeExcept == null) return false;

      if (errResponse == null) {
        // Offline or any other connection error
        return true;
      } else if (!hcoeExcept.contains(errResponse.statusCode)) {
        // Status code is allowed to try cache look up.
        return true;
      }
    }

    return false;
  }

  /// Updates cached response if input has maxStale
  /// This allows to push off deletion of the entry.
  Future<CacheResponse> _updateCacheResponse(
    CacheResponse cacheResponse,
    CacheOptions cacheOptions,
  ) async {
    // Add or update maxStale
    final maxStaleUpdate = cacheOptions.maxStale;
    if (maxStaleUpdate != null) {
      cacheResponse = cacheResponse.copyWith(
        newMaxStale: DateTime.now().toUtc().add(maxStaleUpdate),
      );

      // Store response to cache store
      await _getCacheStore(cacheOptions).set(cacheResponse);
    }

    return cacheResponse;
  }
}
