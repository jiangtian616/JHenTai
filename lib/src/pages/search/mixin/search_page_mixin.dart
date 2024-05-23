import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/gallery_image/gallery_image_page_logic.dart';
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
    return ScrollConfiguration(
      behavior: UIConfig.scrollBehaviourWithoutScrollBar,
      child: GetBuilder<L>(
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
              labelText: state.searchConfig.tags?.isEmpty ?? true ? null : state.searchConfig.computeTagKeywords(withTranslation: false, separator: ' / '),
              prefixIcon: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(child: const Icon(Icons.search), onTap: logic.handleClearAndRefresh),
              ),
              prefixIconConstraints: BoxConstraints(
                minHeight: StyleSetting.isInDesktopLayout ? UIConfig.desktopSearchBarHeight : UIConfig.mobileV2SearchBarHeight,
                minWidth: StyleSetting.isInDesktopLayout ? 32 : 52,
              ),
              suffixIcon: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(child: const Icon(Icons.cancel), onTap: logic.handleTapClearButton),
              ),
              suffixIconConstraints: BoxConstraints(
                minHeight: StyleSetting.isInDesktopLayout ? UIConfig.desktopSearchBarHeight : UIConfig.mobileV2SearchBarHeight,
                minWidth: StyleSetting.isInDesktopLayout ? 24 : 40,
              ),
            ),
            onTap: () {
              if (state.bodyType == SearchPageBodyType.gallerys) {
                state.hideSearchHistory = false;
                logic.toggleBodyType();
              }
            },
            onChanged: logic.onInputChanged,
            onSubmitted: (_) => logic.handleClearAndRefresh(),
          ),
        ),
      ),
    );
  }

  Widget buildOpenGalleryArea() {
    if (state.inputGalleryUrl == null && state.inputGalleryImagePageUrl == null) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        title: Text('openGallery'.tr),
        subtitle: Text(state.inputGalleryUrl?.url ?? state.inputGalleryImagePageUrl!.url, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: const Icon(Icons.open_in_new),
        onTap: () {
          state.searchFieldFocusNode.unfocus();

          if (state.inputGalleryUrl != null) {
            toRoute(Routes.details, arguments: DetailsPageArgument(galleryUrl: state.inputGalleryUrl!));
          } else if (state.inputGalleryImagePageUrl != null) {
            toRoute(Routes.imagePage, arguments: GalleryImagePageArgument(galleryImagePageUrl: state.inputGalleryImagePageUrl!));
          }
        },
      ),
    );
  }

  Widget buildSuggestionAndHistoryBody(BuildContext context) {
    return EHWheelSpeedController(
      controller: state.scrollController,
      child: CustomScrollView(
        key: const PageStorageKey('suggestionBody'),
        controller: state.scrollController,
        slivers: [
          if (logic.searchHistoryService.histories.isNotEmpty) buildSearchHistory(),
          if (logic.searchHistoryService.histories.isNotEmpty) buildButtons(context),
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
          child: state.hideSearchHistory ? const SizedBox() : buildHistoryChips(),
        ),
      ),
    );
  }

  Widget buildHistoryChips() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 7,
            children: logic.searchHistoryService.histories.map(buildHistoryChip).toList(),
          ),
        ),
      ],
    );
  }

  Widget buildHistoryChip(SearchHistory history) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (state.inDeleteSearchHistoryMode) {
            logic.handleDeleteSearchHistory(history);
          } else {
            newSearch(history.rawKeyword + ' ');
          }
        },
        onLongPress: state.inDeleteSearchHistoryMode
            ? null
            : () {
                state.searchConfig.keyword = (state.searchConfig.keyword ?? '').trimLeft() + ' ' + history.rawKeyword;
                logic.update([logic.searchFieldId]);
              },
        child: EHTag(
          tag: GalleryTag(
            tagData: TagData(
              namespace: '',
              key: state.enableSearchHistoryTranslation ? history.translatedKeyword ?? history.rawKeyword : history.rawKeyword,
            ),
          ),
          inDeleteMode: state.inDeleteSearchHistoryMode,
        ),
      ),
    );
  }

  Widget buildButtons(BuildContext context) {
    return SliverToBoxAdapter(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: UIConfig.searchPageAnimationDuration),
            child: state.hideSearchHistory || !logic.tagTranslationService.isReady
                ? null
                : IconButton(
                    onPressed: logic.toggleEnableSearchHistoryTranslation,
                    icon: Icon(Icons.translate, size: 20, color: UIConfig.primaryColor((context))),
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: UIConfig.searchPageAnimationDuration),
            child: GestureDetector(
              onLongPress: state.hideSearchHistory ? null : logic.handleClearAllSearchHistories,
              child: IconButton(
                key: ValueKey(state.hideSearchHistory),
                onPressed: state.hideSearchHistory ? logic.toggleHideSearchHistory : logic.toggleDeleteSearchHistoryMode,
                icon: state.hideSearchHistory
                    ? const Icon(Icons.visibility, size: 20)
                    : state.inDeleteSearchHistoryMode
                        ? const Icon(Icons.close, size: 20)
                        : Icon(Icons.delete, size: 20, color: UIConfig.alertColor(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSuggestions(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 16, bottom: 600),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          state.suggestions
              .map((tagData) => FadeIn(
                    duration: const Duration(milliseconds: 500),
                    child: ListTile(
                      title: RichText(
                          text: highlightKeyword(context, '${tagData.namespace} : ${tagData.key}', state.searchConfig.keyword?.split(' ').last ?? '', false)),
                      subtitle: tagData.tagName == null
                          ? null
                          : RichText(
                              text: highlightKeyword(
                                  context, '${tagData.namespace.tr} : ${tagData.tagName}', state.searchConfig.keyword?.split(' ').last ?? '', true),
                            ),
                      leading: Icon(Icons.search, color: UIConfig.searchPageSuggestionTitleColor(context)),
                      dense: true,
                      minLeadingWidth: 20,
                      visualDensity: const VisualDensity(vertical: -1),
                      onTap: () {
                        List<String> segments = state.searchConfig.keyword?.split(' ') ?? [''];
                        segments.removeLast();
                        segments.add('${tagData.namespace}:"${tagData.key}\$"');
                        state.searchConfig.keyword = segments.joinNewElement(' ', joinAtLast: true).join('');
                        state.searchFieldFocusNode.requestFocus();
                        logic.update([logic.searchFieldId]);
                      },
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
