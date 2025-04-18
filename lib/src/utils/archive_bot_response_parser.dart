import 'package:collection/collection.dart';
import 'package:dio/dio.dart';

import '../model/archive_bot_response/archive_bot_response.dart';

class ArchiveBotResponseParser {
  static ArchiveBotResponse commonParse(Headers headers, dynamic data) {
    return ArchiveBotResponse.fromJson(data);
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
