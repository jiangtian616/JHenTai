import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import '../../config/global_config.dart';
import '../../widget/eh_gallery_collection.dart';
import '../../widget/loading_state_indicator.dart';
import 'base_page_logic.dart';
import 'base_page_state.dart';

abstract class BasePage extends StatefulWidget {
  const BasePage({Key? key}) : super(key: key);

  @override
  State<BasePage> createState();
}

abstract class BasePageFlutterState extends State<BasePage> {
  BasePageLogic get logic;

  BasePageState get state;

  bool get showFilterButton => false;

  bool get showJumpButton => true;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BasePageLogic>(
      id: logic.pageId,
      global: false,
      init: logic,
      builder: (_) => Scaffold(
        appBar: !showFilterButton && !showJumpButton
            ? null
            : AppBar(
                elevation: 1,
                actions: [
                  if (showJumpButton && state.gallerys.isNotEmpty)
                    IconButton(
                      icon: const Icon(FontAwesomeIcons.paperPlane, size: 20),
                      onPressed: logic.handleTapJumpButton,
                    ),
                  if (showFilterButton)
                    IconButton(
                      icon: const Icon(Icons.filter_alt_outlined, size: 28),
                      padding: const EdgeInsets.only(left: 8, right: 18, top: 8, bottom: 8),
                      onPressed: logic.handleTapFilterButton,
                    ),
                ],
              ),
        body: buildList(context),
      ),
    );
  }

  Widget buildList(BuildContext context) {
    return GetBuilder<BasePageLogic>(
      id: logic.bodyId,
      global: false,
      init: logic,
      builder: (_) => state.gallerys.isEmpty && state.loadingState != LoadingState.idle
          ? buildCenterStatusIndicator()
          : EHWheelSpeedController(
              scrollController: state.scrollController,
              child: CustomScrollView(
                key: PageStorageKey(runtimeType),
                controller: state.scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                scrollBehavior: ScrollConfiguration.of(context),
                slivers: <Widget>[
                  buildPullDownIndicator(),
                  buildGalleryCollection(),
                  buildLoadMoreIndicator(),
                ],
              ),
            ),
    );
  }

  Widget buildCenterStatusIndicator() {
    return Center(
      child: GetBuilder<BasePageLogic>(
          id: logic.loadingStateId,
          global: false,
          init: logic,
          builder: (logic) {
            return LoadingStateIndicator(
              loadingState: state.loadingState,
              errorTapCallback: () => logic.loadMore(),
              noDataTapCallback: () => logic.loadMore(),
            );
          }),
    );
  }

  Widget buildPullDownIndicator() {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: GlobalConfig.refreshTriggerPullDistance,
      onRefresh: () => logic.handlePullDown(),
    );
  }

  Widget buildLoadMoreIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<BasePageLogic>(
          id: logic.loadingStateId,
          global: false,
          init: logic,
          builder: (logic) {
            return LoadingStateIndicator(
              errorTapCallback: () => logic.loadMore(),
              loadingState: state.loadingState,
            );
          },
        ),
      ),
    );
  }

  Widget buildGalleryCollection() {
    return EHGalleryCollection(
      key: state.galleryCollectionKey,
      gallerys: state.gallerys,
      loadingState: state.loadingState,
      handleTapCard: logic.handleTapCard,
      handleLoadMore: () => logic.loadMore(),

      /// insert items at bottom of FlutterListView with keepPosition on will cause a bounce
      keepPosition: state.prevPageIndexToLoad != null,
    );
  }
}
