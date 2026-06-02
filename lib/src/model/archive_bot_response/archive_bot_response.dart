import 'package:get/get.dart';

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

enum ArchiveBotResponseCodeEnum {
  invalidParam(1),
  invalidApiKey(2),
  banned(3),
  fetchGalleryInfoFailed(4),
  insufficientGP(5),
  parseFailed(6),
  checkedIn(7),
  serverError(99),
  ;

  final int code;

  const ArchiveBotResponseCodeEnum(this.code);

  static ArchiveBotResponseCodeEnum? fromCode(int code) {
    return ArchiveBotResponseCodeEnum.values.firstWhereOrNull((e) => e.code == code);
  }
}
