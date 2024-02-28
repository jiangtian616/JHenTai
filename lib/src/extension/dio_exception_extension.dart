import 'package:dio/dio.dart';

extension DioExceptionExtension on DioException {
  String? get errorMsg {
    return message ?? error?.toString();
  }
}
