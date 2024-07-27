import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import 'jh_service.dart';
import 'log.dart';
import '../widget/eh_search_config_dialog.dart';

QuickSearchService quickSearchService = QuickSearchService();

class QuickSearchService with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxMap<String, SearchConfig> quickSearchConfigs = RxMap.of(LinkedHashMap<String, SearchConfig>());

  @override
  ConfigEnum get configEnum => ConfigEnum.quickSearch;

  @override
  void applyConfig(String configString) {
    Map map = jsonDecode(configString);

    quickSearchConfigs.value = LinkedHashMap.from(map.map((key, value) => MapEntry(key, SearchConfig.fromJson(value))));
  }

  @override
  String toConfigString() {
    return jsonEncode(quickSearchConfigs);
  }

  @override
  Future<void> doInitBean() async {}

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
    await save();

    toast('saveSuccess'.tr);
  }

  Future<void> removeQuickSearch(String name) async {
    log.info('Remove quick search: $name');

    quickSearchConfigs.remove(name);
    await save();
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

    quickSearchConfigs.value = LinkedHashMap.fromEntries(entries);
    await save();
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

    quickSearchConfigs.value = LinkedHashMap.fromEntries(entries);
    await save();

    toast('updateSuccess'.tr);
  }
}
