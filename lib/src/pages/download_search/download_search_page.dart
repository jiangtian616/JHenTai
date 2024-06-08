import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/download_search/download_search_state.dart';

import 'download_search_logic.dart';

class DownloadSearchPage extends StatelessWidget {
  DownloadSearchPage({Key? key}) : super(key: key);

  final DownloadSearchLogic logic = Get.put(DownloadSearchLogic());
  final DownloadSearchState state = Get.find<DownloadSearchLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('search'.tr)),
      body: Column(
        children: [
          TextField(
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            focusNode: state.searchFocusNode,
            onTapOutside: (_) => state.searchFocusNode.unfocus(),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              prefixIcon: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(child: const Icon(Icons.search)),
              ),
              suffixIcon: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(child: const Icon(Icons.cancel)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 1,
              itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
            ),
          ),
        ],
      ),
    );
  }
}
