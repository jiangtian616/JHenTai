import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/pages/home/tab_view/widget/gallery_card.dart';

import '../../config/global_config.dart';
import '../../model/gallery.dart';
import '../../setting/style_setting.dart';
import '../../widget/eh_sliver_header_delegate.dart';
import '../../widget/eh_tab_bar_config_dialog.dart';
import '../../widget/eh_tag.dart';
import '../../widget/loading_state_indicator.dart';
import 'search_page_logic.dart';

class SearchPagePage extends StatelessWidget {
  final logic = Get.put(SearchPageLogic());
  final state = Get.find<SearchPageLogic>().state;

  SearchPagePage({Key? key}) : super(key: key);

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
                      builder: (logic) {
                        return AppBar(
                          centerTitle: true,
                          title: Text('search'.tr),
                          actions: [
                            IconButton(
                              icon: Icon(
                                state.showSuggestionAndHistory ? Icons.update_disabled : Icons.history,
                                size: 24,
                              ),
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
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 24),
                              onPressed: () => Get.dialog(
                                EHTabBarConfigDialog(
                                  type: EHTabBarConfigDialogType.addTabBar,
                                  tabBarConfig: state.tabBarConfig,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                ),
                SizedBox(
                  height: GlobalConfig.searchBarHeight,
                  width: double.infinity,
                  child: GetBuilder<SearchPageLogic>(
                      id: searchField,
                      builder: (logic) {
                        return CupertinoSearchTextField(
                          prefixInsets: const EdgeInsets.only(left: 18),
                          borderRadius: BorderRadius.zero,
                          backgroundColor: Get.theme.backgroundColor,
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
                          onSubmitted: (value) => logic.searchMore(),
                        );
                      }),
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
                          .map((keyword) => GestureDetector(
                                onTap: () {
                                  state.tabBarConfig.searchConfig.keyword = keyword;
                                  logic.searchMore();
                                },
                                child: EHTag(tagData: TagData(namespace: '', key: keyword)),
                              ))
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
                  .map((tagData) => ListTile(
                        title: RichText(
                          text: _highlightKeyword(context, '${tagData.namespace} : ${tagData.key}', false),
                        ),
                        subtitle: tagData.tagName == null
                            ? null
                            : RichText(
                                text: _highlightKeyword(context, '${tagData.namespace.tr} : ${tagData.tagName}', true),
                              ),
                        leading: const Icon(Icons.search),
                        dense: true,
                        minLeadingWidth: 20,
                        visualDensity: const VisualDensity(vertical: -1),
                        onTap: () {
                          state.tabBarConfig.searchConfig.keyword = '${tagData.namespace}:${tagData.key}';
                          logic.searchMore();
                        },
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
        ? Center(
            child: GetBuilder<SearchPageLogic>(
                id: loadingStateId,
                builder: (logic) {
                  return LoadingStateIndicator(
                    errorTapCallback: () => logic.searchMore(isRefresh: true),
                    noDataTapCallback: () => logic.searchMore(isRefresh: true),
                    loadingState: state.loadingState,
                  );
                }),
          )
        : CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.only(top: context.mediaQueryPadding.top + GlobalConfig.searchBarHeight),
                sliver: CupertinoSliverRefreshControl(
                  refreshTriggerPullDistance: GlobalConfig.refreshTriggerPullDistance,
                  onRefresh: () => logic.searchMore(isRefresh: true),
                ),
              ),
              _buildGalleryList(),
              SliverPadding(
                padding: EdgeInsets.only(top: 8, bottom: context.mediaQuery.padding.bottom),
                sliver: SliverToBoxAdapter(
                  child: GetBuilder<SearchPageLogic>(
                      id: loadingStateId,
                      builder: (logic) {
                        return LoadingStateIndicator(
                          loadingState: state.loadingState,
                        );
                      }),
                ),
              ),
            ],
          );
  }

  SliverList _buildGalleryList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (index == state.gallerys.length - 1 && state.loadingState == LoadingState.idle) {
            SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
              logic.searchMore(isRefresh: false);
            });
          }

          Gallery gallery = state.gallerys[index];
          return Obx(() {
            return GalleryCard(
              gallery: gallery,
              handleTapCard: (gallery) => logic.handleTapCard(gallery),
              withTags: StyleSetting.listMode.value == ListMode.listWithTags,
            ).marginOnly(top: 5, bottom: 5, left: 10, right: 10);
          });
        },
        childCount: state.gallerys.length,
      ),
    );
  }
}
