import 'dart:collection';

import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../utils/log.dart';
import '../widget/eh_search_config_dialog.dart';

const quickSearchStorageKey = 'quickSearch';

class QuickSearchService extends GetxController {
  final StorageService _storageService = Get.find();

  LinkedHashMap<String, SearchConfig> quickSearchConfigs = LinkedHashMap();

  static void init() {
    Get.put(QuickSearchService());
    Log.debug('init QuickSearchService success', false);
  }

  @override
  void onInit() async {
    super.onInit();

    Map? map = _storageService.read(quickSearchStorageKey);
    if (map != null) {
      quickSearchConfigs = LinkedHashMap.from(map.map((key, value) => MapEntry(key, SearchConfig.fromJson(value))));
    }
  }

  void addQuickSearch(String name, SearchConfig searchConfig) {
    if (quickSearchConfigs.containsKey(name)) {
      toast('sameNameExists'.tr);
      return;
    }

    Log.info('Add quick search: $name');

    _storageService.write(quickSearchStorageKey, quickSearchConfigs);

    quickSearchConfigs[name] = searchConfig;
    update();

    toast('saveSuccess'.tr);
  }

  void removeQuickSearch(String name) {
    Log.info('Remove quick search: $name');

    quickSearchConfigs.remove(name);
    _storageService.write(quickSearchStorageKey, quickSearchConfigs);
    update();
  }

  void reOrderQuickSearch(int oldIndex, int newIndex) {
    Log.info('reOrder quick search, oldIndex:$oldIndex, newIndex:$newIndex');

    List<MapEntry<String, SearchConfig>> entries = quickSearchConfigs.entries.toList();

    if (newIndex != entries.length) {
      entries.insert(newIndex, entries[oldIndex]);
      entries.removeAt(newIndex > oldIndex ? oldIndex : oldIndex + 1);
    } else {
      entries.add(entries[oldIndex]);
      entries.removeAt(newIndex > oldIndex ? oldIndex : oldIndex + 1);
    }

    quickSearchConfigs = LinkedHashMap.fromEntries(entries);
    _storageService.write(quickSearchStorageKey, quickSearchConfigs);

    update();
  }

  void handleUpdateQuickSearch(MapEntry<String, SearchConfig> oldConfig) async {
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

    Log.info('Update quick search: ${oldConfig.key}');
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
    _storageService.write(quickSearchStorageKey, quickSearchConfigs);
    update();

    toast('updateSuccess'.tr);
  }
}
