import 'package:flukit/flukit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/gallerys/base/page_logic_base.dart';
import 'package:jhentai/src/pages/gallerys/base/page_state_base.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_logic.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import '../../../config/global_config.dart';
import '../../../widget/eh_gallery_collection.dart';
import '../../../widget/loading_state_indicator.dart';

abstract class PageBase extends StatefulWidget {
  const PageBase({Key? key}) : super(key: key);

  @override
  State<PageBase> createState();
}

abstract class PageBaseState extends State<PageBase> {
  LogicBase get logic;

  StateBase get state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<LogicBase>(
        id: logic.bodyId,
        global: false,
        init: logic,
        builder: (logic) => state.gallerys.isEmpty && state.loadingState != LoadingState.idle
            ? _buildCenterStatusIndicator()
            : EHWheelSpeedController(
                scrollControllerGetter: () => state.scrollController,
                child: CustomScrollView(
                  key: PageStorageKey(runtimeType),
                  controller: state.scrollController,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  scrollBehavior: ScrollConfiguration.of(context),
                  slivers: <Widget>[
                    _buildPullDownIndicator(),
                    _buildGalleryCollection(),
                    _buildLoadMoreIndicator(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCenterStatusIndicator() {
    return Center(
      child: GetBuilder<LogicBase>(
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

  Widget _buildPullDownIndicator() {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: GlobalConfig.refreshTriggerPullDistance,
      onRefresh: () => logic.handlePullDown(),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<LogicBase>(
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

  Widget _buildGalleryCollection() {
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
