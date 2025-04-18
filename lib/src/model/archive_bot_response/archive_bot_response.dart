import 'package:get/get.dart';
import 'package:jhentai/src/utils/archive_bot_response_parser.dart';

class ArchiveBotResponse {
  final int code;
  final String message;
  final Map<String, dynamic> data;

  const ArchiveBotResponse({required this.code, required this.message, required this.data});

  factory ArchiveBotResponse.fromJson(Map<String, dynamic> json) {
    return ArchiveBotResponse(
      code: json["code"],
      message: json["msg"],
      data: json["data"],
    );
  }

  bool get isSuccess => code == 0;

  String get errorMessage => ArchiveBotResponseCodeEnum.fromCode(code)?.name.tr ?? 'internalError'.tr;

  @override
  String toString() {
    return 'ArchiveBotResponse{code: $code, message: $message, data: $data}';
  }
}
