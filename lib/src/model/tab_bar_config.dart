import 'package:jhentai/src/model/search_config.dart';

class TabBarConfig {
  String name;

  SearchConfig? searchConfig;

  TabBarConfig({
    required this.name,
    this.searchConfig,
  });

  TabBarConfig copyWith({
    String? name,
    SearchConfig? searchConfig,
  }) {
    return TabBarConfig(
      name: name ?? this.name,
      searchConfig: searchConfig ?? this.searchConfig,
    );
  }
}
