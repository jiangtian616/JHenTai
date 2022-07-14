import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/service/quick_search_service.dart';

import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';
import '../simple/simple_search_page_logic.dart';

class QuickSearchPage extends StatelessWidget {
  QuickSearchPage({Key? key}) : super(key: key);

  final QuickSearchService quickSearchService = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('quickSearch'.tr)),
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
                  ).marginOnly(right: 24),
                  onTap: () {
                    SimpleSearchPageLogic simpleSearchPageLogic = Get.find<SimpleSearchPageLogic>();
                    simpleSearchPageLogic.state.searchConfig = entries.elementAt(index).value.copyWith();
                    String keyword = simpleSearchPageLogic.state.searchConfig.keyword ?? '';

                    if (isAtTop(Routes.simpleSearch)) {
                      simpleSearchPageLogic.clearAndRefresh();
                      return;
                    }
                    toNamed(Routes.simpleSearch, parameters: {'keyword': keyword});
                  },
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
