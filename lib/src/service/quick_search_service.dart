import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import 'jh_service.dart';
import 'log.dart';
import '../widget/eh_search_config_dialog.dart';

QuickSearchService quickSearchService = QuickSearchService();

class QuickSearchService extends GetxController with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  LinkedHashMap<String, SearchConfig> quickSearchConfigs = LinkedHashMap();

  @override
  ConfigEnum get configEnum => ConfigEnum.quickSearch;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    quickSearchConfigs = LinkedHashMap.from(map.map((key, value) => MapEntry(key, SearchConfig.fromJson(value))));
  }

  @override
  String toConfigString() {
    return jsonEncode(quickSearchConfigs);
  }

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  void doAfterBeanReady() {}

  Future<void> addQuickSearch(String name, SearchConfig searchConfig) async {
    if (quickSearchConfigs.containsKey(name)) {
      toast('sameNameExists'.tr, isShort: false);
      return;
    }

    Map<String, dynamic> queryParameters = searchConfig.toQueryParameters();
    for (MapEntry<String, SearchConfig> entry in quickSearchConfigs.entries) {
      if (mapEquals(entry.value.toQueryParameters(), queryParameters)) {
        toast('${'sameConfigExists'.tr}: ${entry.key}', isShort: false);
        return;
      }
    }

    log.info('Add quick search: $name');

    quickSearchConfigs[name] = searchConfig;
    await saveBeanConfig();
    updateSafely();
    
    toast('saveSuccess'.tr);
  }

  Future<void> removeQuickSearch(String name) async {
    log.info('Remove quick search: $name');

    quickSearchConfigs.remove(name);
    await saveBeanConfig();
    update();
  }

  Future<void> reOrderQuickSearch(int oldIndex, int newIndex) async {
    log.info('reOrder quick search, oldIndex:$oldIndex, newIndex:$newIndex');

    List<MapEntry<String, SearchConfig>> entries = quickSearchConfigs.entries.toList();

    if (newIndex != entries.length) {
      entries.insert(newIndex, entries[oldIndex]);
      entries.removeAt(newIndex > oldIndex ? oldIndex : oldIndex + 1);
    } else {
      entries.add(entries[oldIndex]);
      entries.removeAt(newIndex > oldIndex ? oldIndex : oldIndex + 1);
    }

    quickSearchConfigs = LinkedHashMap.fromEntries(entries);
    await saveBeanConfig();
    updateSafely();
  }

  Future<void> handleUpdateQuickSearch(MapEntry<String, SearchConfig> oldConfig) async {
    Map<String, dynamic>? result = await Get.dialog(
      EHSearchConfigDialog(
        type: EHSearchConfigDialogType.update,
        quickSearchName: oldConfig.key,
        searchConfig: oldConfig.value,
      ),
    );

    if (result == null) {
      return;
    }

    log.info('Update quick search: ${oldConfig.key}');
    String quickSearchName = result['quickSearchName'];
    SearchConfig searchConfig = result['searchConfig'];

    if (oldConfig.key != quickSearchName && quickSearchConfigs.containsKey(quickSearchName)) {
      toast('sameNameExists'.tr);
      return;
    }

    /// keep order
    List<MapEntry<String, SearchConfig>> entries = quickSearchConfigs.entries.toList();
    int index = entries.indexWhere((e) => e.key == oldConfig.key);

    entries.removeAt(index);
    if (index == entries.length) {
      entries.add(MapEntry(quickSearchName, searchConfig));
    } else {
      entries.insert(index, MapEntry(quickSearchName, searchConfig));
    }

    quickSearchConfigs = LinkedHashMap.fromEntries(entries);
    await saveBeanConfig();
    updateSafely();
    
    toast('updateSuccess'.tr);
  }
}
