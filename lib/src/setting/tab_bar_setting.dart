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
    TabBarConfig(
      name: 'popular'.tr,
      searchConfig: SearchConfig(searchType: SearchType.popular),
      isDeleteAble: false,
      isEditable: false,
    ),
    TabBarConfig(name: 'favorite'.tr, searchConfig: SearchConfig(searchType: SearchType.favorite)),
    TabBarConfig(name: 'watched'.tr, searchConfig: SearchConfig(searchType: SearchType.watched)),
    TabBarConfig(
      name: 'history'.tr,
      searchConfig: SearchConfig(searchType: SearchType.history),
      isDeleteAble: false,
      isEditable: false,
    ),
  ].obs;

  static void addTab(TabBarConfig tabBarConfig) {
    Log.verbose('addTab:$tabBarConfig');
    configs.add(tabBarConfig);
    _save();
  }

  static void removeTab(int index) {
    if (configs.length == 1) {
      return;
    }
    Log.verbose('removeTab:$index');
    configs.removeAt(index);
    _save();
  }

  static void updateTab(int index, TabBarConfig tabBarConfig) {
    Log.verbose('updateTab:$index');
    configs[index] = tabBarConfig;
    _save();
  }

  static void reOrderTab(int oldIndex, int newIndex) {
    Log.verbose('reOrderTab:$oldIndex-$newIndex');
    if (newIndex != configs.length - 1) {
      configs.insert(newIndex, configs.removeAt(oldIndex));
    } else {
      configs.add(configs.removeAt(oldIndex));
    }
    _save();
  }

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('tabBarSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init TabBarSetting success', false);
    } else {
      Log.verbose('init TabBarSetting success: default', false);
    }
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('tabBarSetting', _toMap());
  }

  static Future<void> reset() async {
    configs.value = <TabBarConfig>[
      TabBarConfig(name: 'gallery'.tr, searchConfig: SearchConfig()),
      TabBarConfig(
        name: 'popular'.tr,
        searchConfig: SearchConfig(searchType: SearchType.popular),
        isDeleteAble: false,
        isEditable: false,
      ),
      TabBarConfig(name: 'favorite'.tr, searchConfig: SearchConfig(searchType: SearchType.favorite)),
      TabBarConfig(name: 'watched'.tr, searchConfig: SearchConfig(searchType: SearchType.watched)),
      TabBarConfig(
        name: 'history'.tr,
        searchConfig: SearchConfig(searchType: SearchType.history),
        isDeleteAble: false,
        isEditable: false,
      ),
    ];
    await Get.find<StorageService>().remove('tabBarSetting');
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
              isDeleteAble: entry['isDeleteAble'],
              isEditable: entry['isEditable'],
            ))
        .toList();
  }
}
