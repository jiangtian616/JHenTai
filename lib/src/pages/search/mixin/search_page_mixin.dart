import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/search/mixin/search_page_logic_mixin.dart';
import 'package:jhentai/src/pages/search/mixin/search_page_state_mixin.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/search_util.dart';

import '../../../database/database.dart';
import '../../../model/gallery_tag.dart';
import '../../../model/search_history.dart';
import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';
import '../../../widget/eh_search_config_dialog.dart';
import '../../../widget/eh_tag.dart';
import '../../../widget/eh_wheel_speed_controller.dart';

mixin SearchPageMixin<L extends SearchPageLogicMixin, S extends SearchPageStateMixin> on BasePage<L, S> {
  @override
  L get logic;

  @override
  S get state;

  List<Widget> buildActionButtons({VisualDensity? visualDensity}) {
    return [
      IconButton(
        icon: const Icon(Icons.attach_file),
        onPressed: logic.handleFileSearch,
        visualDensity: visualDensity,
      ),
      IconButton(
        icon: const Icon(Icons.restore),
        onPressed: logic.handleTapJumpButton,
        visualDensity: visualDensity,
      ),
      IconButton(
        icon: Icon(state.bodyType == SearchPageBodyType.gallerys ? Icons.search : Icons.image_outlined),
        onPressed: logic.toggleBodyType,
        visualDensity: visualDensity,
      ),
      IconButton(
        icon: const Icon(Icons.filter_alt_outlined),
        onPressed: () => logic.handleTapFilterButton(EHSearchConfigDialogType.filter),
        visualDensity: visualDensity,
      ),
      IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => toRoute(Routes.quickSearch),
        visualDensity: visualDensity,
      ),
    ];
  }

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
            labelText:
                state.searchConfig.tags?.isEmpty ?? true ? null : state.searchConfig.computeTagKeywords(withTranslation: false, separator: ' / '),
            prefixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(child: const Icon(Icons.search), onTap: logic.handleClearAndRefresh),
            ),
            prefixIconConstraints: BoxConstraints(
              minHeight: StyleSetting.isInDesktopLayout ? UIConfig.desktopSearchBarHeight : UIConfig.mobileV2SearchBarHeight,
              minWidth: 52,
            ),
            suffixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(child: const Icon(Icons.cancel), onTap: logic.handleTapClearButton),
            ),
            suffixIconConstraints: BoxConstraints(
              minHeight: StyleSetting.isInDesktopLayout ? UIConfig.desktopSearchBarHeight : UIConfig.mobileV2SearchBarHeight,
              minWidth: 40,
            ),
          ),
          onTap: () {
            if (state.bodyType == SearchPageBodyType.gallerys) {
              state.hideSearchHistory = false;
              logic.toggleBodyType();
            }
          },
          onChanged: (value) {
            state.searchConfig.keyword = value;
            logic.waitAndSearchTags();
          },
          onSubmitted: (_) => logic.handleClearAndRefresh(),
        ),
      ),
    );
  }

  Widget buildSuggestionAndHistoryBody() {
    return SuggestionAndHistoryBody(
      currentKeyword: state.searchConfig.keyword?.split(' ').last ?? '',
      suggestions: state.suggestions,
      hideSearchHistory: state.hideSearchHistory,
      showTranslateButton: logic.tagTranslationService.isReady,
      enableSearchHistoryTranslation: state.enableSearchHistoryTranslation,
      histories: logic.searchHistoryService.histories,
      scrollController: state.scrollController,
      onTapChip: (String keyword) => newSearch(keyword + ' '),
      onLongPressChip: (String keyword) {
        state.searchConfig.keyword = (state.searchConfig.keyword ?? '').trimLeft() + ' ' + keyword;
        logic.update([logic.searchFieldId]);
      },
      onTapSuggestion: (TagData tagData) {
        List<String> segments = state.searchConfig.keyword?.split(' ') ?? [''];
        segments.removeLast();
        segments.add('${tagData.namespace}:"${tagData.key}\$"');
        state.searchConfig.keyword = segments.joinNewElement(' ', joinAtLast: true).join('');
        logic.update([logic.searchFieldId]);
      },
      toggleEnableSearchHistoryTranslation: logic.toggleEnableSearchHistoryTranslation,
      onTapClearSearchHistory: logic.handleTapClearSearchHistoryButton,
      toggleHideSearchHistory: logic.toggleHideSearchHistory,
    );
  }
}

class SuggestionAndHistoryBody extends StatelessWidget {
  final String currentKeyword;
  final bool hideSearchHistory;
  final bool showTranslateButton;
  final bool enableSearchHistoryTranslation;
  final List<SearchHistory> histories;
  final List<TagData> suggestions;
  final ScrollController scrollController;
  final ValueChanged<String> onTapChip;
  final ValueChanged<String> onLongPressChip;
  final ValueChanged<TagData> onTapSuggestion;
  final VoidCallback toggleEnableSearchHistoryTranslation;
  final VoidCallback onTapClearSearchHistory;
  final VoidCallback toggleHideSearchHistory;

  const SuggestionAndHistoryBody({
    Key? key,
    required this.currentKeyword,
    required this.hideSearchHistory,
    required this.showTranslateButton,
    required this.enableSearchHistoryTranslation,
    required this.histories,
    required this.suggestions,
    required this.scrollController,
    required this.onTapChip,
    required this.onLongPressChip,
    required this.onTapSuggestion,
    required this.toggleEnableSearchHistoryTranslation,
    required this.onTapClearSearchHistory,
    required this.toggleHideSearchHistory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EHWheelSpeedController(
      controller: scrollController,
      child: CustomScrollView(
        key: const PageStorageKey('suggestionBody'),
        controller: scrollController,
        slivers: [
          if (histories.isNotEmpty) buildSearchHistory(),
          if (histories.isNotEmpty) buildButtons(context),
          buildSuggestions(context),
        ],
      ),
    );
  }

  Widget buildSearchHistory() {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
      sliver: SliverToBoxAdapter(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: UIConfig.searchPageAnimationDuration),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child)),
          child: hideSearchHistory
              ? const SizedBox()
              : HistoryChips(
                  histories: histories,
                  onTapChip: onTapChip,
                  onLongPressChip: onLongPressChip,
                  enableSearchHistoryTranslation: enableSearchHistoryTranslation,
                ),
        ),
      ),
    );
  }

  Widget buildButtons(
    BuildContext context,
  ) {
    return SliverToBoxAdapter(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: toggleEnableSearchHistoryTranslation,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: UIConfig.searchPageAnimationDuration),
              child: hideSearchHistory || !showTranslateButton ? null : Icon(Icons.translate, size: 20, color: UIConfig.primaryColor((context))),
            ),
          ),
          IconButton(
            onPressed: hideSearchHistory ? toggleHideSearchHistory : onTapClearSearchHistory,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: UIConfig.searchPageAnimationDuration),
              child: hideSearchHistory ? const Icon(Icons.visibility, size: 20) : Icon(Icons.delete, size: 20, color: UIConfig.alertColor(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSuggestions(
    BuildContext context,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 16, bottom: 600),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          suggestions
              .map((tagData) => FadeIn(
                    duration: const Duration(milliseconds: 500),
                    child: ListTile(
                      title: RichText(text: highlightKeyword(context, '${tagData.namespace} : ${tagData.key}', currentKeyword, false)),
                      subtitle: tagData.tagName == null
                          ? null
                          : RichText(
                              text: highlightKeyword(context, '${tagData.namespace.tr} : ${tagData.tagName}', currentKeyword, true),
                            ),
                      leading: Icon(Icons.search, color: UIConfig.searchPageSuggestionTitleColor(context)),
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
  TextSpan highlightKeyword(BuildContext context, String rawText, String currentKeyword, bool isSubTitle) {
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
              color: isSubTitle ? UIConfig.searchPageSuggestionSubTitleColor(context) : UIConfig.searchPageSuggestionTitleColor(context),
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
            color: isSubTitle ? UIConfig.searchPageSuggestionSubTitleColor(context) : UIConfig.searchPageSuggestionTitleColor(context),
          ),
        ),
      );
    }

    return TextSpan(children: children);
  }
}

class HistoryChips extends StatelessWidget {
  final List<SearchHistory> histories;
  final ValueChanged<String> onTapChip;
  final ValueChanged<String> onLongPressChip;
  final bool enableSearchHistoryTranslation;

  const HistoryChips({
    Key? key,
    required this.histories,
    required this.onTapChip,
    required this.onLongPressChip,
    required this.enableSearchHistoryTranslation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 7,
            children: histories
                .map(
                  (history) => HistoryChip(
                    history: history,
                    onTapChip: onTapChip,
                    onLongPressChip: onLongPressChip,
                    enableSearchHistoryTranslation: enableSearchHistoryTranslation,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class HistoryChip extends StatelessWidget {
  final SearchHistory history;
  final ValueChanged<String> onTapChip;
  final ValueChanged<String> onLongPressChip;
  final bool enableSearchHistoryTranslation;

  const HistoryChip({
    Key? key,
    required this.history,
    required this.onTapChip,
    required this.onLongPressChip,
    required this.enableSearchHistoryTranslation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onTapChip(history.rawKeyword),
        onLongPress: () => onLongPressChip(history.rawKeyword),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: UIConfig.searchPageAnimationDuration),
          child: EHTag(
            tag: GalleryTag(
              tagData: TagData(
                namespace: '',
                key: enableSearchHistoryTranslation ? history.translatedKeyword ?? history.rawKeyword : history.rawKeyword,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
