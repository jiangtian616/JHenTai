import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/network_setting.dart';

class EHTimeoutTranslator extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.connectionTimeout) {
      return handler.next(err.copyWith(message: '${'connectionTimeoutHint'.tr} (${NetworkSetting.connectTimeout}ms)'));
    }
    if (err.type == DioExceptionType.receiveTimeout) {
      return handler.next(err.copyWith(message: '${'receiveDataTimeoutHint'.tr} (${NetworkSetting.receiveTimeout}ms)'));
    }
    handler.next(err);
  }
}
