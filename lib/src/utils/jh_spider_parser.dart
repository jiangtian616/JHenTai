import 'package:dio/dio.dart';

import '../model/config.dart';
import '../model/response/jh_response.dart';

class JHResponseParser {
  static bool api2Success(Headers headers, dynamic data) {
    JHResponse response = JHResponse.fromJson(data);
    return response.code == 0;
  }

  static List<CloudConfig> listConfigApi2Configs(Headers headers, dynamic data) {
    JHResponse response = JHResponse.fromJson(data);
    List<dynamic> list = response.data['configs'];
    return list.map<CloudConfig>((e) => CloudConfig.fromJson(e)).toList();
  }
}
