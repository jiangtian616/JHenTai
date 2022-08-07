import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_logic.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_state.dart';

import '../../../database/database.dart';
import '../../../model/gallery_tag.dart';
import '../../../widget/eh_tag.dart';
import '../../../widget/eh_wheel_speed_controller.dart';

mixin BaseSearchPage on BasePage {
  @override
  BaseSearchPageLogic get logic;

  @override
  BaseSearchPageState get state;

  Widget buildSearchField(BuildContext context) {
    return GetBuilder<BaseSearchPageLogic>(
      global: false,
      init: logic,
      id: logic.searchFieldId,
      builder: (_) => CupertinoSearchTextField(
        prefixInsets: const EdgeInsets.only(left: 18),
        borderRadius: BorderRadius.circular(24),
        backgroundColor: Get.theme.backgroundColor,
        style: Theme.of(context).textTheme.subtitle1,
        placeholder: 'search'.tr,
        placeholderStyle: const TextStyle(height: 1.2, color: Colors.grey),
        controller: TextEditingController.fromValue(
          TextEditingValue(
            text: state.searchConfig.keyword ?? '',

            /// make cursor stay at last letter
            selection: TextSelection.fromPosition(TextPosition(offset: state.searchConfig.keyword?.length ?? 0)),
          ),
        ),
        onChanged: (value) {
          state.searchConfig.keyword = value;
          logic.waitAndSearchTags();
        },
        onSubmitted: (_) => logic.clearAndRefresh(),
      ),
    );
  }

  Widget buildSuggestionAndHistoryBody(BuildContext context) {
    List<String> history = logic.getSearchHistory();

    return EHWheelSpeedController(
      scrollController: state.suggestionBodyController,
      child: CustomScrollView(
        key: const PageStorageKey('suggestionBody'),
        controller: state.suggestionBodyController,
        slivers: [
          if (history.isNotEmpty) buildHistorySearchTags(history),
          if (history.isNotEmpty) buildHistoryDeleteButton(),
          buildSuggestions(context),
        ],
      ),
    );
  }

  Widget buildHistorySearchTags(List<String> history) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
      sliver: SliverToBoxAdapter(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 7,
                children: history
                    .map(
                      (keyword) => InkWell(
                        canRequestFocus: false,
                        onTap: () {
                          state.searchConfig.keyword = keyword;
                          logic.clearAndRefresh();
                        },
                        child: EHTag(tag: GalleryTag(tagData: TagData(namespace: '', key: keyword))),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHistoryDeleteButton() {
    return SliverToBoxAdapter(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ExcludeFocus(
            child: IconButton(
              onPressed: logic.clearHistory,
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            ),
          )
        ],
      ),
    );
  }

  Widget buildSuggestions(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          state.suggestions
              .map((tagData) => FadeIn(
                    duration: const Duration(milliseconds: 500),
                    child: ListTile(
                      title: RichText(text: highlightKeyword(context, '${tagData.namespace} : ${tagData.key}', false)),
                      subtitle: tagData.tagName == null
                          ? null
                          : RichText(text: highlightKeyword(context, '${tagData.namespace.tr} : ${tagData.tagName}', true)),
                      leading: const Icon(Icons.search),
                      dense: true,
                      minLeadingWidth: 20,
                      visualDensity: const VisualDensity(vertical: -1),
                      onTap: () {
                        state.searchConfig.keyword = '${tagData.namespace}:${tagData.key}';
                        logic.clearAndRefresh();
                      },
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  TextSpan highlightKeyword(BuildContext context, String rawText, bool isSubTitle) {
    String keyword = state.searchConfig.keyword!;
    List<TextSpan> children = <TextSpan>[];

    List<int> matchIndexes = keyword.allMatches(rawText).map((match) => match.start).toList();

    int indexHandling = 0;
    for (int index in matchIndexes) {
      if (index > indexHandling) {
        children.add(
          TextSpan(
            text: rawText.substring(indexHandling, index),
            style: TextStyle(fontSize: isSubTitle ? 12 : 15, color: isSubTitle ? Colors.grey.shade400 : Theme.of(context).textTheme.subtitle1?.color),
          ),
        );
      }
      children.add(
        TextSpan(
          text: keyword,
          style: TextStyle(fontSize: isSubTitle ? 12 : 15, color: Get.theme.primaryColorLight),
        ),
      );
      indexHandling = index + keyword.length;
    }
    if (rawText.length > indexHandling) {
      children.add(
        TextSpan(
          text: rawText.substring(indexHandling, rawText.length),
          style: TextStyle(fontSize: isSubTitle ? 12 : 15, color: isSubTitle ? Colors.grey.shade400 : Theme.of(context).textTheme.subtitle1?.color),
        ),
      );
    }

    return TextSpan(children: children);
  }
}
