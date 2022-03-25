import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/model/tab_bar_config.dart';
import 'package:json_annotation/json_annotation.dart';

import '../service/storage_service.dart';
import '../utils/log.dart';

@JsonSerializable()
class TabBarSetting {
  static RxList<TabBarConfig> configs = <TabBarConfig>[
    TabBarConfig(name: 'gallery'.tr, searchConfig: SearchConfig()),
    TabBarConfig(name: 'popular'.tr, searchConfig: SearchConfig()),
    TabBarConfig(name: 'favorite'.tr, searchConfig: SearchConfig()),
    TabBarConfig(name: 'ranklist'.tr, searchConfig: SearchConfig()),
    TabBarConfig(name: 'history'.tr, searchConfig: SearchConfig()),
  ].obs;

  static bool addTab(String name, [SearchConfig? searchConfig]) {
    if (name.isEmpty) {
      return false;
    }

    if (configs.firstWhereOrNull((config) => config.name == name) != null) {
      return false;
    }

    configs.add(TabBarConfig(name: name, searchConfig: searchConfig ?? SearchConfig()));
    _save();
    return true;
  }

  static bool removeTab(String name) {
    if (configs.length == 1) {
      return false;
    }

    /// removeAt will call ever twice (a bug)! so i can only use removeWhere.
    configs.removeWhere((config) => config.name == name);
    _save();
    return true;
  }

  static void updateTab(String name, TabBarConfig tabBarConfig) {
    int updateIndex = configs.indexWhere((config) => config.name == name);
    configs[updateIndex] = tabBarConfig;
    _save();
  }

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('tabBarSetting');
    if (map != null) {
      _initFromMap(map);
      Log.info('init TabBarSetting success', false);
    }
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('tabBarSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'settings': jsonEncode(configs),
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    List entryList = jsonDecode(map['settings']);
    configs.value = entryList
        .map((entry) => TabBarConfig(
              name: entry['name'],
              searchConfig: SearchConfig.fromJson(entry['searchConfig']),
            ))
        .toList();
  }
}
