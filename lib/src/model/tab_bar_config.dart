import 'package:jhentai/src/model/search_config.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class TabBarConfig {
  String name;
  SearchConfig searchConfig;
  bool isDeleteAble;
  bool isEditable;

  TabBarConfig({
    required this.name,
    required this.searchConfig,
    this.isDeleteAble = true,
    this.isEditable = true,
  });

  factory TabBarConfig.fromJson(Map<String, dynamic> json) {
    return TabBarConfig(
      name: json["name"],
      searchConfig: SearchConfig.fromJson(json["searchConfig"]),
      isDeleteAble: json['isDeleteAble'],
      isEditable: json['isEditable'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "searchConfig": searchConfig.toJson(),
      'isDeleteAble': isDeleteAble,
      'isEditable': isEditable,
    };
  }

  @override
  String toString() {
    return 'TabBarConfig{name: $name, searchConfig: $searchConfig, isDeleteAble: $isDeleteAble, isEditable: $isEditable}';
  }
}
