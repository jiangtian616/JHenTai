import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/tab_view/widget/gallery_card.dart';

import '../../config/global_config.dart';
import '../../model/gallery.dart';
import '../../widget/eh_sliver_header_delegate.dart';
import '../../widget/eh_tab_bar_config_dialog.dart';
import '../../widget/loading_state_indicator.dart';
import 'search_page_logic.dart';

class SearchPagePage extends StatelessWidget {
  final logic = Get.put(SearchPageLogic(), tag: SearchPageLogic.currentStackDepth.toString());
  final state = SearchPageLogic.currentSearchPageLogic.state;

  SearchPagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ExtendedNestedScrollView(
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
                  child: AppBar(
                    centerTitle: true,
                    title: Text('search'.tr),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.filter_alt, size: 28),
                        onPressed: () => Get.dialog(
                          EHTabBarConfigDialog(
                            type: EHTabBarConfigDialogType.filter,
                            tabBarConfig: state.tabBarConfig,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 26),
                        onPressed: () => Get.dialog(
                          EHTabBarConfigDialog(
                            type: EHTabBarConfigDialogType.addTabBar,
                            tabBarConfig: state.tabBarConfig,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: GlobalConfig.searchBarHeight,
                  width: double.infinity,
                  child: CupertinoSearchTextField(
                    prefixInsets: const EdgeInsets.only(left: 18),
                    borderRadius: BorderRadius.zero,
                    backgroundColor: Get.theme.backgroundColor,
                    placeholder: 'search'.tr,
                    placeholderStyle: const TextStyle(height: 1.2, color: Colors.grey),
                    controller: TextEditingController(text: state.tabBarConfig.searchConfig.keyword),
                    onChanged: (value) => state.tabBarConfig.searchConfig.keyword = value,
                    onSubmitted: (value) => logic.search(),
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
      tag: SearchPageLogic.currentStackDepth.toString(),
      builder: (logic) {
        return state.gallerys.isEmpty && state.loadingState != LoadingState.idle
            ? Center(
                child: GetBuilder<SearchPageLogic>(
                    id: loadingStateId,
                    builder: (logic) {
                      return LoadingStateIndicator(
                        errorTapCallback: () => logic.search(isRefresh: true),
                        noDataTapCallback: () => logic.search(isRefresh: true),
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
                      onRefresh: () => logic.search(isRefresh: true),
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
      },
    );
  }

  SliverList _buildGalleryList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (index == state.gallerys.length - 1 && state.loadingState == LoadingState.idle) {
            SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
              logic.search(isRefresh: false);
            });
          }

          Gallery gallery = state.gallerys[index];
          return GalleryCard(gallery: gallery, handleTapCard: (gallery) => logic.handleTapCard(gallery));
        },
        childCount: state.gallerys.length,
      ),
    );
  }
}
