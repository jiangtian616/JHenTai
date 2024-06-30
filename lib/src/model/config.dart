import 'package:jhentai/src/enum/config_type_enum.dart';

class CloudConfig {
  final int id;

  final String shareCode;

  final String identificationCode;

  final CloudConfigTypeEnum type;

  final String version;

  final String config;

  final DateTime ctime;

  const CloudConfig({
    required this.id,
    required this.shareCode,
    required this.identificationCode,
    required this.type,
    required this.version,
    required this.config,
    required this.ctime,
  });

  factory CloudConfig.fromJson(Map<String, dynamic> json) {
    return CloudConfig(
      id: json["id"],
      shareCode: json["shareCode"],
      identificationCode: json["identificationCode"],
      type: CloudConfigTypeEnum.fromCode(json["type"]),
      version: json["version"],
      config: json["config"],
      ctime: DateTime.fromMillisecondsSinceEpoch(json["ctime"], isUtc: true).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": this.id,
      "shareCode": this.shareCode,
      "identificationCode": this.identificationCode,
      "type": this.type.code,
      "version": this.version,
      "config": this.config,
      "ctime": this.ctime.toUtc().millisecondsSinceEpoch,
    };
  }
}
