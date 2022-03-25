import 'package:jhentai/src/model/search_config.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class TabBarConfig {
  String name;
  SearchConfig searchConfig;

  TabBarConfig({
    required this.name,
    required this.searchConfig,
  });

  factory TabBarConfig.fromJson(Map<String, dynamic> json) {
    return TabBarConfig(
      name: json["name"],
      searchConfig: SearchConfig.fromJson(json["searchConfig"]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": this.name,
      "searchConfig": this.searchConfig.toJson(),
    };
  }

}
