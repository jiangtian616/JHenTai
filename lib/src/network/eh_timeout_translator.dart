import 'package:dio/dio.dart';
import 'package:get/get.dart';

class EHTimeoutTranslator extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.connectionTimeout) {
      return handler.next(err.copyWith(message: 'connectionTimeoutHint'.tr));
    }
    if (err.type == DioExceptionType.receiveTimeout) {
      return handler.next(err.copyWith(message: 'receiveDataTimeoutHint'.tr));
    }
    handler.next(err);
  }
}
