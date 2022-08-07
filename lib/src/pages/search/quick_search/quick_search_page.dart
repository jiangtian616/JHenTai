import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/utils/search_util.dart';

class QuickSearchPage extends StatelessWidget {
  final bool automaticallyImplyLeading;

  QuickSearchPage({Key? key, this.automaticallyImplyLeading = true}) : super(key: key);

  final QuickSearchService quickSearchService = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('quickSearch'.tr),
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 24),
            onPressed: () => handleAddQuickSearch(),
          ),
        ],
      ),
      body: GetBuilder<QuickSearchService>(
        builder: (_) {
          Iterable<MapEntry<String, SearchConfig>> entries = quickSearchService.quickSearchConfigs.entries;

          return ReorderableListView.builder(
            itemCount: quickSearchService.quickSearchConfigs.length,
            onReorder: quickSearchService.reOrderQuickSearch,
            itemBuilder: (_, int index) => Column(
              key: Key(entries.elementAt(index).key),
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  title: Text(
                    entries.elementAt(index).key,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete, size: 24, color: Colors.red.shade400),
                        onPressed: () => quickSearchService.removeQuickSearch(entries.elementAt(index).key),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, size: 24),
                        onPressed: () => quickSearchService.handleUpdateQuickSearch(entries.elementAt(index)),
                      ),
                    ],
                  ).marginOnly(right: GetPlatform.isDesktop ? 24 : 0),
                  onTap: () => newSearchWithConfig(entries.elementAt(index).value),
                ),
                const Divider(thickness: 0.7, height: 2),
              ],
            ),
          );
        },
      ),
    );
  }
}
