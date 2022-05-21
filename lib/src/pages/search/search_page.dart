import 'package:animate_do/animate_do.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/pages/search/search_page_state.dart';

import '../../config/global_config.dart';
import '../../widget/eh_gallery_collection.dart';
import '../../widget/eh_sliver_header_delegate.dart';
import '../../widget/eh_tab_bar_config_dialog.dart';
import '../../widget/eh_tag.dart';
import '../../widget/loading_state_indicator.dart';
import 'search_page_logic.dart';

class SearchPagePage extends StatelessWidget {
  final String tag = UniqueKey().toString();

  late final SearchPageLogic logic;
  late final SearchPageState state;

  SearchPagePage({Key? key}) : super(key: key) {
    logic = Get.put(SearchPageLogic(tag), tag: tag);
    state = logic.state;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ExtendedNestedScrollView(
        onlyOneScrollInBody: true,
        floatHeaderSlivers: true,
        headerSliverBuilder: _headerBuilder,
        body: _buildBody(context),
      ),
    );
  }

  List<Widget> _headerBuilder(BuildContext context, bool innerBoxIsScrolled) {
    return [
      SliverOverlapAbsorber(
        handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(context),
        sliver: SliverPersistentHeader(
          pinned: true,
          floating: true,
          delegate: EHSliverHeaderDelegate(
            minHeight: context.mediaQueryPadding.top + GlobalConfig.searchBarHeight,
            maxHeight: context.mediaQueryPadding.top + GlobalConfig.appBarHeight + GlobalConfig.searchBarHeight,

            /// make sure the color changes with theme's change
            otherCondition: Get.theme.appBarTheme.backgroundColor,
            child: Column(
              children: [
                // use Expanded so the AppBar can shrink or expand when scrolling between [minExtent] and [maxExtent]
                Expanded(
                  child: GetBuilder<SearchPageLogic>(
                      id: appBarId,
                      tag: tag,
                      builder: (logic) {
                        return AppBar(
                          centerTitle: true,
                          title: Text('search'.tr),
                          actions: [
                            if (state.pageCount > 1)
                              IconButton(
                                icon: const Icon(FontAwesomeIcons.paperPlane, size: 17),
                                onPressed: logic.handleOpenJumpDialog,
                                alignment: const Alignment(0.5, -0.4),
                                padding: const EdgeInsets.only(top: 11, bottom: 11, left: 8, right: 8),
                              ),
                            IconButton(
                              icon: Icon(
                                state.showSuggestionAndHistory ? Icons.update_disabled : Icons.history,
                                size: 24,
                              ),
                              visualDensity: const VisualDensity(horizontal: -4),
                              onPressed: logic.toggleBodyType,
                            ),
                            IconButton(
                              icon: const Icon(Icons.filter_alt, size: 24),
                              onPressed: () => Get.dialog(
                                EHTabBarConfigDialog(
                                  type: EHTabBarConfigDialogType.filter,
                                  tabBarConfig: state.tabBarConfig,
                                ),
                              ),
                              visualDensity: const VisualDensity(horizontal: -4),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 24),
                              onPressed: () => Get.dialog(
                                EHTabBarConfigDialog(
                                  type: EHTabBarConfigDialogType.addTabBar,
                                  tabBarConfig: state.tabBarConfig,
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                          ],
                        );
                      }),
                ),
                Container(
                  height: GlobalConfig.searchBarHeight,
                  width: double.infinity,
                  color: Get.theme.backgroundColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: GetBuilder<SearchPageLogic>(
                            id: searchFieldId,
                            tag: tag,
                            builder: (logic) {
                              return CupertinoSearchTextField(
                                prefixInsets: const EdgeInsets.only(left: 18),
                                borderRadius: BorderRadius.zero,
                                backgroundColor: Get.theme.backgroundColor,
                                style: Theme.of(context).textTheme.subtitle1,
                                placeholder: 'search'.tr,
                                placeholderStyle: const TextStyle(height: 1.2, color: Colors.grey),
                                controller: TextEditingController.fromValue(
                                  TextEditingValue(
                                    text: state.tabBarConfig.searchConfig.keyword ?? '',

                                    /// make cursor stay at last letter
                                    selection: TextSelection.fromPosition(
                                      TextPosition(offset: state.tabBarConfig.searchConfig.keyword?.length ?? 0),
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  state.tabBarConfig.searchConfig.keyword = value;
                                  logic.waitAndSearchTags();
                                },
                                onSubmitted: (value) {
                                  /// indicate => keyword search
                                  state.redirectUrl = null;
                                  logic.searchMore();
                                },
                              );
                            }),
                      ),
                      IconButton(
                        onPressed: logic.handlePickImage,
                        icon: const Icon(Icons.attach_file),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildBody(BuildContext context) {
    return GetBuilder<SearchPageLogic>(
      id: bodyId,
      tag: tag,
      builder: (logic) =>
          state.showSuggestionAndHistory ? _buildSuggestionAndHistoryBody(context) : _buildGalleryBody(context),
    );
  }

  Widget _buildSuggestionAndHistoryBody(BuildContext context) {
    List<String> history = logic.getSearchHistory();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        Builder(
          builder: (context) => SliverOverlapInjector(
            handle: ExtendedNestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
        ),
        if (history.isNotEmpty)
          SliverPadding(
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
                            (keyword) => GestureDetector(
                              onTap: () {
                                state.tabBarConfig.searchConfig.keyword = keyword;
                                logic.searchMore();
                              },
                              child: EHTag(
                                tag: GalleryTag(tagData: TagData(namespace: '', key: keyword)),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (history.isNotEmpty)
          SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: logic.clearHistory,
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                )
              ],
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              state.suggestions
                  .map((tagData) => FadeIn(
                        duration: const Duration(milliseconds: 500),
                        child: ListTile(
                          title: RichText(
                            text: _highlightKeyword(context, '${tagData.namespace} : ${tagData.key}', false),
                          ),
                          subtitle: tagData.tagName == null
                              ? null
                              : RichText(
                                  text:
                                      _highlightKeyword(context, '${tagData.namespace.tr} : ${tagData.tagName}', true),
                                ),
                          leading: const Icon(Icons.search),
                          dense: true,
                          minLeadingWidth: 20,
                          visualDensity: const VisualDensity(vertical: -1),
                          onTap: () {
                            state.tabBarConfig.searchConfig.keyword = '${tagData.namespace}:${tagData.key}';
                            logic.searchMore();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _highlightKeyword(BuildContext context, String rawText, bool isSubTitle) {
    String keyword = state.tabBarConfig.searchConfig.keyword!;
    List<TextSpan> children = <TextSpan>[];

    List<int> matchIndexes = keyword.allMatches(rawText).map((match) => match.start).toList();

    int indexHandling = 0;
    for (int index in matchIndexes) {
      if (index > indexHandling) {
        children.add(
          TextSpan(
            text: rawText.substring(indexHandling, index),
            style: TextStyle(
                fontSize: isSubTitle ? 12 : 15,
                color: isSubTitle ? Colors.grey.shade400 : Theme.of(context).textTheme.subtitle1?.color),
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
          style: TextStyle(
              fontSize: isSubTitle ? 12 : 15,
              color: isSubTitle ? Colors.grey.shade400 : Theme.of(context).textTheme.subtitle1?.color),
        ),
      );
    }

    return TextSpan(children: children);
  }

  Widget _buildGalleryBody(BuildContext context) {
    return state.gallerys.isEmpty && state.loadingState != LoadingState.idle
        ? _buildCenterStatusIndicator()
        : CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: <Widget>[
              _buildPullDownIndicator(),
              _buildGalleryCollection(),
              _buildLoadMoreIndicator(),
            ],
          );
  }

  Widget _buildCenterStatusIndicator() {
    return Center(
      child: GetBuilder<SearchPageLogic>(
          id: loadingStateId,
          tag: tag,
          builder: (logic) {
            return LoadingStateIndicator(
              errorTapCallback: () => logic.searchMore(isRefresh: true),
              noDataTapCallback: () => logic.searchMore(isRefresh: true),
              loadingState: state.loadingState,
            );
          }),
    );
  }

  Widget _buildPullDownIndicator() {
    /// take responsibility of [SliverOverlapInjector]
    return SliverPadding(
      padding: EdgeInsets.only(top: Get.mediaQuery.padding.top + GlobalConfig.searchBarHeight),
      sliver: CupertinoSliverRefreshControl(
        refreshTriggerPullDistance: GlobalConfig.refreshTriggerPullDistance,
        onRefresh: logic.handlePullDown,
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<SearchPageLogic>(
            id: loadingStateId,
            tag: tag,
            builder: (logic) {
              return LoadingStateIndicator(
                loadingState: state.loadingState,
              );
            }),
      ),
    );
  }

  Widget _buildGalleryCollection() {
    return EHGalleryCollection(
      gallerys: state.gallerys,
      loadingState: state.loadingState,
      handleTapCard: logic.handleTapCard,
      handleLoadMore: () => logic.searchMore(isRefresh: false),

      /// insert items at bottom of FlutterListView with keepPosition on will cause a bounce
      keepPosition:
          state.tabBarConfig.searchConfig.pageAtMost == null && state.tabBarConfig.searchConfig.pageAtLeast == null,
    );
  }
}
