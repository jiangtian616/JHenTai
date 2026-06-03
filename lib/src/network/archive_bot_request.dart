import 'package:dio/dio.dart';
import 'package:get/get_rx/src/rx_workers/rx_workers.dart';
import 'package:jhentai/src/consts/archive_bot_consts.dart';
import 'package:jhentai/src/model/archive_bot_response/archive_bot_response.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';

import '../service/jh_service.dart';
import '../setting/network_setting.dart';

ArchiveBotRequest archiveBotRequest = ArchiveBotRequest();

class ArchiveBotRequest with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late final Dio _dio;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..addAll([ehRequest, archiveBotSetting]);

  @override
  Future<void> doInitBean() async {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: networkSetting.connectTimeout.value),
      receiveTimeout: Duration(milliseconds: networkSetting.receiveTimeout.value),
    ));

    ever(networkSetting.connectTimeout, (_) {
      setConnectTimeout(networkSetting.connectTimeout.value);
    });
    ever(networkSetting.receiveTimeout, (_) {
      setReceiveTimeout(networkSetting.receiveTimeout.value);
    });
  }

  @override
  Future<void> doAfterBeanReady() async {}

  void setConnectTimeout(int connectTimeout) {
    _dio.options.connectTimeout = Duration(milliseconds: connectTimeout);
  }

  void setReceiveTimeout(int receiveTimeout) {
    _dio.options.receiveTimeout = Duration(milliseconds: receiveTimeout);
  }

  ArchiveBotProtocol _mappingProtocol(ArchiveBotType botType) {
    switch (botType) {
      case ArchiveBotType.ehArBot:
        return EhArBotProtocol(_dio);
      case ArchiveBotType.archiveAtHome:
        return ArchiveAtHomeProtocol(_dio);
    }
  }

  Future<ArchiveBotResponse> requestBalance({
    required ArchiveBotType botType,
    required String apiAddress,
    required String apiKey,
  }) {
    return _mappingProtocol(botType).requestBalance(apiAddress: apiAddress, apiKey: apiKey);
  }

  Future<ArchiveBotResponse> requestCheckIn({
    required ArchiveBotType botType,
    required String apiAddress,
    required String apiKey,
  }) {
    return _mappingProtocol(botType).requestCheckIn(apiAddress: apiAddress, apiKey: apiKey);
  }

  Future<ArchiveBotResponse> requestResolve({
    required ArchiveBotType botType,
    required String apiAddress,
    required String apiKey,
    required int gid,
    required String token,
    bool reParse = true,
    CancelToken? cancelToken,
  }) {
    return _mappingProtocol(botType).requestResolve(
      apiAddress: apiAddress,
      apiKey: apiKey,
      gid: gid,
      token: token,
      reParse: reParse,
      cancelToken: cancelToken,
    );
  }
}

abstract class ArchiveBotProtocol {
  final Dio dio;

  const ArchiveBotProtocol(this.dio);

  Future<ArchiveBotResponse> requestBalance({
    required String apiAddress,
    required String apiKey,
  });

  Future<ArchiveBotResponse> requestCheckIn({
    required String apiAddress,
    required String apiKey,
  });

  Future<ArchiveBotResponse> requestResolve({
    required String apiAddress,
    required String apiKey,
    required int gid,
    required String token,
    bool reParse = true,
    CancelToken? cancelToken,
  });

  /// Converts the raw HTTP [response] to a normalized [ArchiveBotResponse].
  ArchiveBotResponse normalizeResponse(Response response);
}

/// Protocol implementation for the original EH-ArBot API.
///
/// - Auth: POST body field `apikey`
/// - Base URL: configurable
/// - Response format: `{ code, msg, data }`
class EhArBotProtocol extends ArchiveBotProtocol {
  const EhArBotProtocol(super.dio);

  @override
  ArchiveBotResponse normalizeResponse(Response response) {
    return ArchiveBotResponse.fromJson(response.data);
  }

  @override
  Future<ArchiveBotResponse> requestBalance({
    required String apiAddress,
    required String apiKey,
  }) async {
    Response response = await dio.post(
      '$apiAddress/balance',
      options: Options(contentType: Headers.jsonContentType),
      data: {'apikey': apiKey},
    );
    return normalizeResponse(response);
  }

  @override
  Future<ArchiveBotResponse> requestCheckIn({
    required String apiAddress,
    required String apiKey,
  }) async {
    Response response = await dio.post(
      '$apiAddress/checkin',
      options: Options(contentType: Headers.jsonContentType),
      data: {'apikey': apiKey},
    );
    return normalizeResponse(response);
  }

  @override
  Future<ArchiveBotResponse> requestResolve({
    required String apiAddress,
    required String apiKey,
    required int gid,
    required String token,
    bool reParse = true,
    CancelToken? cancelToken,
  }) async {
    Response response = await dio.post(
      '$apiAddress/resolve',
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'apikey': apiKey,
        'gid': gid,
        'token': token,
        'force_resolve': reParse,
      },
      cancelToken: cancelToken,
    );
    return normalizeResponse(response);
  }
}

/// Protocol implementation for the Archive-at-Home API.
///
/// - Auth: HTTP header `Authorization: Bearer <apiKey>`
/// - Response format: direct business object on 200; `{ error: "..." }` on non-200
class ArchiveAtHomeProtocol extends ArchiveBotProtocol {
  const ArchiveAtHomeProtocol(super.dio);

  Options _authOptions(String apiKey, {Map<String, dynamic>? extraHeaders}) {
    return Options(
      contentType: Headers.jsonContentType,
      validateStatus: (status) => true,
      headers: {
        'Authorization': 'Bearer $apiKey',
        if (extraHeaders != null) ...extraHeaders,
      },
    );
  }

  @override
  ArchiveBotResponse normalizeResponse(Response response) {
    final dynamic body = response.data;
    final int statusCode = response.statusCode ?? -1;

    if (body is! Map) {
      return ArchiveBotResponse(
        code: ArchiveBotResponseCodeEnum.serverError.code,
        message: 'internalError',
        data: const {},
      );
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(body as Map);

    if (statusCode == 200) {
      final String? error = data['error']?.toString();
      if (error != null && error.isNotEmpty) {
        return ArchiveBotResponse(
          code: _inferErrorCode(error),
          message: error,
          data: const {},
        );
      }

      final bool? checkinSuccess = data['success'] is bool ? data['success'] as bool : null;
      if (checkinSuccess == false) {
        final String msg = data['message']?.toString() ?? 'checkInFailed';
        return ArchiveBotResponse(
          code: ArchiveBotResponseCodeEnum.checkedIn.code,
          message: msg,
          data: const {},
        );
      }

      return ArchiveBotResponse(
        code: 0,
        message: 'success',
        data: data,
      );
    }

    final String error = data['error']?.toString() ?? data['message']?.toString() ?? 'internalError';
    if (statusCode == 401) {
      return ArchiveBotResponse(
        code: ArchiveBotResponseCodeEnum.invalidApiKey.code,
        message: error,
        data: const {},
      );
    }

    return ArchiveBotResponse(
      code: _inferErrorCode(error),
      message: error,
      data: const {},
    );
  }

  int _inferErrorCode(String error) {
    final String lowerError = error.toLowerCase();

    if (lowerError.contains('invalid api key') ||
        lowerError.contains('authorization') ||
        lowerError.contains('unauthorized') ||
        lowerError.contains('bearer')) {
      return ArchiveBotResponseCodeEnum.invalidApiKey.code;
    }
    if (lowerError.contains('insufficient') || lowerError.contains('balance')) {
      return ArchiveBotResponseCodeEnum.insufficientGP.code;
    }
    if (lowerError.contains('parse') || lowerError.contains('gallery')) {
      return ArchiveBotResponseCodeEnum.parseFailed.code;
    }

    return ArchiveBotResponseCodeEnum.serverError.code;
  }

  @override
  Future<ArchiveBotResponse> requestBalance({
    required String apiAddress,
    required String apiKey,
  }) async {
    Response response = await dio.get(
      '$apiAddress/api/v1/me/balance',
      options: _authOptions(apiKey),
    );
    return normalizeResponse(response);
  }

  @override
  Future<ArchiveBotResponse> requestCheckIn({
    required String apiAddress,
    required String apiKey,
  }) async {
    Response response = await dio.post(
      '$apiAddress/api/v1/me/checkin',
      options: _authOptions(apiKey),
    );
    return normalizeResponse(response);
  }

  @override
  Future<ArchiveBotResponse> requestResolve({
    required String apiAddress,
    required String apiKey,
    required int gid,
    required String token,
    bool reParse = true,
    CancelToken? cancelToken,
  }) async {
    Response response = await dio.post(
      '$apiAddress/api/v1/parse',
      options: _authOptions(apiKey, extraHeaders: {'X-Client': ArchiveBotConsts.archiveAtHomeXClient}),
      data: {
        'gallery_id': gid.toString(),
        'gallery_key': token,
        'force': reParse,
      },
      cancelToken: cancelToken,
    );
    return normalizeResponse(response);
  }
}
