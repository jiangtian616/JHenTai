import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page_logic.dart';
import 'package:jhentai/src/pages/search/simple/simple_search_page_logic.dart';
import 'package:jhentai/src/pages/search/simple/simple_search_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_search_config_dialog.dart';

import '../../../config/global_config.dart';
import '../../../database/database.dart';
import '../../../model/gallery_tag.dart';
import '../../../widget/eh_tag.dart';
import '../../../widget/eh_wheel_speed_controller.dart';
import '../../base/base_page.dart';

class SimpleSearchPage extends BasePage {
  const SimpleSearchPage({Key? key}) : super(key: key);

  @override
  State<BasePage> createState() => _SimpleSearchPageFlutterState();
}

class _SimpleSearchPageFlutterState extends BasePageFlutterState {
  @override
  final SimpleSearchPageLogic logic = Get.put(SimpleSearchPageLogic(), permanent: true);
  @override
  final SimpleSearchPageState state = Get.find<SimpleSearchPageLogic>().state;

  final FocusNode searchFieldFocusNode = FocusNode();

  @override
  void initState() {
    if (Get.parameters['keyword'] != null) {
      state.searchConfig.keyword = Get.parameters['keyword'];
      logic.clearAndRefresh();
    }

    searchFieldFocusNode.onKeyEvent = (_, KeyEvent event) {
      if (event is! KeyDownEvent) {
        return KeyEventResult.ignored;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        Get.find<DesktopLayoutPageLogic>().state.leftColumnFocusScopeNode.nextFocus();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SimpleSearchPageLogic>(
      id: logic.pageId,
      builder: (_) => Scaffold(
        floatingActionButton: state.gallerys.isEmpty || state.bodyType == SearchPageBodyType.suggestionAndHistory
            ? null
            : FloatingActionButton(
                child: const Icon(FontAwesomeIcons.paperPlane, size: 20),
                onPressed: logic.handleTapJumpButton,
              ),
        body: Column(
          children: [
            GetBuilder<SimpleSearchPageLogic>(
              id: logic.searchFieldId,
              builder: (_) => Container(
                height: GlobalConfig.searchBarHeight,
                margin: const EdgeInsets.only(top: 8, bottom: 8, left: 2, right: 2),
                child: Row(
                  children: [
                    Expanded(child: _buildSearchField().marginSymmetric(horizontal: 16)),
                    ExcludeFocus(child: IconButton(icon: const Icon(Icons.attach_file), onPressed: logic.handleFileSearch)),
                    ExcludeFocus(
                      child: IconButton(
                        icon: Icon(state.bodyType == SearchPageBodyType.gallerys ? Icons.update_disabled : Icons.history, size: 24),
                        onPressed: logic.toggleBodyType,
                      ),
                    ),
                    ExcludeFocus(child: IconButton(icon: const Icon(Icons.filter_alt), onPressed: () => logic.handleTapFilterButton(EHSearchConfigDialogType.filter))),
                    ExcludeFocus(
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 24),
                        onPressed: logic.addQuickSearch,
                      ),
                    ),
                    ExcludeFocus(
                      child: IconButton(
                        icon: Icon(
                          FontAwesomeIcons.bars,
                          color: Get.theme.appBarTheme.actionsIconTheme?.color,
                          size: 20,
                        ),
                        onPressed: () => toNamed(Routes.quickSearch),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.bodyType == SearchPageBodyType.suggestionAndHistory)
              Expanded(child: _buildSuggestionAndHistoryBody(context))
            else if (state.hasSearched)
              Expanded(child: buildList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return CupertinoSearchTextField(
      focusNode: searchFieldFocusNode,
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
    );
  }

  Widget _buildSuggestionAndHistoryBody(BuildContext context) {
    List<String> history = logic.getSearchHistory();

    return EHWheelSpeedController(
      scrollController: state.suggestionBodyController,
      child: CustomScrollView(
        key: const PageStorageKey('suggestionBody'),
        controller: state.suggestionBodyController,
        slivers: [
          if (history.isNotEmpty) _buildHistorySearchTags(history),
          if (history.isNotEmpty) _buildHistoryDeleteButton(),
          _buildSuggestions(),
        ],
      ),
    );
  }

  Widget _buildHistorySearchTags(List<String> history) {
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

  Widget _buildHistoryDeleteButton() {
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

  Widget _buildSuggestions() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          state.suggestions
              .map((tagData) => FadeIn(
                    duration: const Duration(milliseconds: 500),
                    child: ListTile(
                      title: RichText(text: _highlightKeyword(context, '${tagData.namespace} : ${tagData.key}', false)),
                      subtitle: tagData.tagName == null
                          ? null
                          : RichText(text: _highlightKeyword(context, '${tagData.namespace.tr} : ${tagData.tagName}', true)),
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

  TextSpan _highlightKeyword(BuildContext context, String rawText, bool isSubTitle) {
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
