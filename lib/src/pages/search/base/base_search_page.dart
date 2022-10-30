import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_logic.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_state.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../../../database/database.dart';
import '../../../model/gallery_tag.dart';
import '../../../widget/eh_tag.dart';
import '../../../widget/eh_wheel_speed_controller.dart';

mixin BaseSearchPageMixin<L extends BaseSearchPageLogicMixin, S extends BaseSearchPageStateMixin> on BasePage<L, S> {
  @override
  L get logic;

  @override
  S get state;

  Widget buildSearchField() {
    return GetBuilder<L>(
      global: false,
      init: logic,
      id: logic.searchFieldId,
      builder: (_) => SizedBox(
        height: StyleSetting.isInDesktopLayout ? UIConfig.desktopSearchBarHeight : UIConfig.mobileV2SearchBarHeight,
        child: TextField(
          focusNode: state.searchFieldFocusNode,
          textInputAction: TextInputAction.search,
          controller: TextEditingController.fromValue(
            TextEditingValue(
              text: state.searchConfig.keyword ?? '',

              /// make cursor stay at last letter
              selection: TextSelection.fromPosition(TextPosition(offset: state.searchConfig.keyword?.length ?? 0)),
            ),
          ),
          style: const TextStyle(fontSize: 15),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'search'.tr,
            contentPadding: EdgeInsets.zero,
            labelStyle: const TextStyle(fontSize: 15),
            floatingLabelStyle: const TextStyle(fontSize: 10),
            labelText: state.searchConfig.tags?.isEmpty ?? true ? null : state.searchConfig.toTagKeywords(withTranslation: false, separator: ' / '),
            prefixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(child: const Icon(Icons.search), onTap: logic.clearAndRefresh),
            ),
            prefixIconConstraints: BoxConstraints(
              minHeight: StyleSetting.isInDesktopLayout ? UIConfig.desktopSearchBarHeight : UIConfig.mobileV2SearchBarHeight,
              minWidth: 48,
            ),
            suffixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(child: const Icon(Icons.cancel), onTap: logic.handleTapClearButton),
            ),
            suffixIconConstraints: BoxConstraints(
              minHeight: StyleSetting.isInDesktopLayout ? UIConfig.desktopSearchBarHeight : UIConfig.mobileV2SearchBarHeight,
              minWidth: 48,
            ),
          ),
          onTap: () {
            if (state.bodyType == SearchPageBodyType.gallerys) {
              logic.toggleBodyType();
            }
          },
          onChanged: (value) {
            state.searchConfig.keyword = value;
            logic.waitAndSearchTags();
          },
          onSubmitted: (_) => logic.clearAndRefresh(),
        ),
      ),
    );
  }

  Widget buildSuggestionAndHistoryBody() {
    return SuggestionAndHistoryBody(
      currentKeyword: state.searchConfig.keyword?.split(' ').last ?? '',
      suggestions: state.suggestions,
      history: logic.getSearchHistory(),
      scrollController: state.scrollController,
      onTapChip: (String keyword) {
        state.searchConfig.keyword = keyword + ' ';
        state.searchConfig.tags?.clear();
        logic.clearAndRefresh();
      },
      onTapSuggestion: (TagData tagData) {
        List<String> segments = state.searchConfig.keyword?.split(' ') ?? [''];
        segments.removeLast();
        segments.add('${tagData.namespace}:"${tagData.key}\$"');
        state.searchConfig.keyword = segments.joinNewElement(' ', joinAtLast: true).join('');
        logic.update([logic.searchFieldId]);
      },
      onDeleteHistory: logic.clearHistory,
    );
  }
}

class SuggestionAndHistoryBody extends StatelessWidget {
  final String currentKeyword;
  final List<String> history;
  final List<TagData> suggestions;
  final ScrollController scrollController;
  final ValueChanged<String> onTapChip;
  final ValueChanged<TagData> onTapSuggestion;
  final VoidCallback onDeleteHistory;

  const SuggestionAndHistoryBody({
    Key? key,
    required this.currentKeyword,
    required this.history,
    required this.suggestions,
    required this.scrollController,
    required this.onTapChip,
    required this.onTapSuggestion,
    required this.onDeleteHistory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EHWheelSpeedController(
      controller: scrollController,
      child: CustomScrollView(
        key: const PageStorageKey('suggestionBody'),
        controller: scrollController,
        slivers: [
          if (history.isNotEmpty) buildHistorySearchTags(),
          if (history.isNotEmpty) buildHistoryDeleteButton(),
          buildSuggestions(),
        ],
      ),
    );
  }

  Widget buildHistorySearchTags() {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
      sliver: SliverToBoxAdapter(
        child: HistoryChips(history: history, onTapChip: onTapChip),
      ),
    );
  }

  Widget buildHistoryDeleteButton() {
    return SliverToBoxAdapter(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ExcludeFocus(
            child: IconButton(onPressed: onDeleteHistory, icon: const Icon(Icons.delete, size: 20, color: Colors.red)),
          )
        ],
      ),
    );
  }

  Widget buildSuggestions() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 16, bottom: 600),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          suggestions
              .map((tagData) => FadeIn(
                    duration: const Duration(milliseconds: 500),
                    child: ListTile(
                      title: RichText(text: highlightKeyword('${tagData.namespace} : ${tagData.key}', currentKeyword, false)),
                      subtitle: tagData.tagName == null
                          ? null
                          : RichText(
                              text: highlightKeyword('${tagData.namespace.tr} : ${tagData.tagName}', currentKeyword, true),
                            ),
                      leading: Icon(Icons.search, color: UIConfig.searchPageSuggestionTitleColor),
                      dense: true,
                      minLeadingWidth: 20,
                      visualDensity: const VisualDensity(vertical: -1),
                      onTap: () => onTapSuggestion(tagData),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  /// highlight keyword in rawText
  TextSpan highlightKeyword(String rawText, String currentKeyword, bool isSubTitle) {
    List<TextSpan> children = <TextSpan>[];

    List<int> matchIndexes = currentKeyword.allMatches(rawText).map((match) => match.start).toList();

    int indexHandling = 0;
    for (int index in matchIndexes) {
      if (index > indexHandling) {
        children.add(
          TextSpan(
            text: rawText.substring(indexHandling, index),
            style: TextStyle(
              fontSize: isSubTitle ? UIConfig.searchPageSuggestionSubTitleTextSize : UIConfig.searchPageSuggestionTitleTextSize,
              color: isSubTitle ? UIConfig.searchPageSuggestionSubTitleColor : UIConfig.searchPageSuggestionTitleColor,
            ),
          ),
        );
      }

      children.add(
        TextSpan(
          text: currentKeyword,
          style: TextStyle(
            fontSize: isSubTitle ? UIConfig.searchPageSuggestionSubTitleTextSize : UIConfig.searchPageSuggestionTitleTextSize,
            color: UIConfig.searchPageSuggestionHighlightColor,
          ),
        ),
      );

      indexHandling = index + currentKeyword.length;
    }

    if (rawText.length > indexHandling) {
      children.add(
        TextSpan(
          text: rawText.substring(indexHandling, rawText.length),
          style: TextStyle(
            fontSize: isSubTitle ? UIConfig.searchPageSuggestionSubTitleTextSize : UIConfig.searchPageSuggestionTitleTextSize,
            color: isSubTitle ? UIConfig.searchPageSuggestionSubTitleColor : UIConfig.searchPageSuggestionTitleColor,
          ),
        ),
      );
    }

    return TextSpan(children: children);
  }
}

class HistoryChips extends StatelessWidget {
  final List<String> history;
  final ValueChanged<String> onTapChip;

  const HistoryChips({Key? key, required this.history, required this.onTapChip}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 7,
            children: history
                .map(
                  (keyword) => MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => onTapChip(keyword),
                      child: EHTag(tag: GalleryTag(tagData: TagData(namespace: '', key: keyword))),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
