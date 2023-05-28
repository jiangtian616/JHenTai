import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/notification/tap_menu_button_notification.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import '../../config/ui_config.dart';
import '../../mixin/scroll_to_top_logic_mixin.dart';
import '../../mixin/scroll_to_top_page_mixin.dart';
import '../../mixin/scroll_to_top_state_mixin.dart';
import '../../widget/eh_gallery_collection.dart';
import '../../widget/loading_state_indicator.dart';
import 'base_page_logic.dart';
import 'base_page_state.dart';

abstract class BasePage<L extends BasePageLogic, S extends BasePageState> extends StatelessWidget with Scroll2TopPageMixin {
  /// For mobile layout v2
  final bool showMenuButton;
  final bool showJumpButton;
  final bool showFilterButton;
  final bool showScroll2TopButton;
  final bool showTitle;
  final String? name;

  const BasePage({
    Key? key,
    this.showMenuButton = false,
    this.showJumpButton = false,
    this.showFilterButton = false,
    this.showScroll2TopButton = false,
    this.showTitle = false,
    this.name,
  }) : super(key: key);

  L get logic;

  S get state;

  @override
  Scroll2TopLogicMixin get scroll2TopLogic => logic;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<L>(
      global: false,
      init: logic,
      builder: (_) => Scaffold(
        backgroundColor: UIConfig.backGroundColor(context),
        appBar: showFilterButton || showJumpButton || showMenuButton || showTitle ? buildAppBar(context) : null,
        body: SafeArea(child: buildBody(context)),
        floatingActionButton: showScroll2TopButton ? buildFloatingActionButton() : null,
      ),
    );
  }

  AppBar? buildAppBar(BuildContext context) {
    return AppBar(
      leading: showMenuButton ? buildAppBarMenuButton(context) : null,
      title: showTitle ? Text(name!) : null,
      centerTitle: true,
      actions: buildAppBarActions(),
    );
  }

  Widget buildAppBarMenuButton(BuildContext context) {
    return IconButton(
      icon: const Icon(FontAwesomeIcons.bars, size: 20),
      onPressed: () => TapMenuButtonNotification().dispatch(context),
    );
  }

  List<Widget> buildAppBarActions() {
    return [
      if (showJumpButton && state.gallerys.isNotEmpty)
        IconButton(icon: const Icon(FontAwesomeIcons.paperPlane, size: 20), onPressed: logic.handleTapJumpButton),
      if (showFilterButton) IconButton(icon: const Icon(Icons.filter_alt_outlined, size: 28), onPressed: logic.handleTapFilterButton),
    ];
  }

  Widget buildBody(BuildContext context) {
    return buildListBody(context);
  }

  Widget buildListBody(BuildContext context) {
    return GetBuilder<L>(
      id: logic.bodyId,
      global: false,
      init: logic,
      builder: (_) => state.gallerys.isEmpty && state.loadingState != LoadingState.idle
          ? buildCenterStatusIndicator()
          : NotificationListener<UserScrollNotification>(
              onNotification: logic.onUserScroll,
              child: EHWheelSpeedController(
                controller: state.scrollController,
                child: CustomScrollView(
                  key: state.pageStorageKey,
                  controller: state.scrollController,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  scrollBehavior: ScrollConfiguration.of(context),
                  slivers: <Widget>[
                    buildPullDownIndicator(),
                    buildGalleryCollection(context),
                    buildLoadMoreIndicator(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget buildCenterStatusIndicator() {
    return Center(
      child: GetBuilder<L>(
        id: logic.loadingStateId,
        global: false,
        init: logic,
        builder: (_) => LoadingStateIndicator(
          loadingState: state.loadingState,
          errorTapCallback: () {
            Log.info('CenterStatusIndicator errorTapCallback => loadMore');
            logic.loadMore();
          },
          noDataTapCallback: () {
            Log.info('CenterStatusIndicator noDataTapCallback => loadMore');
            logic.loadMore();
          },
        ),
      ),
    );
  }

  Widget buildPullDownIndicator() {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: UIConfig.refreshTriggerPullDistance,
      onRefresh: logic.handlePullDown,
    );
  }

  Widget buildLoadMoreIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<L>(
          id: logic.loadingStateId,
          global: false,
          init: logic,
          builder: (_) => LoadingStateIndicator(
            loadingState: state.loadingState,
            errorTapCallback: () {
              Log.info('LoadMoreIndicator errorTapCallback => loadMore');
              logic.loadMore();
            },
          ),
        ),
      ),
    );
  }

  Widget buildGalleryCollection(BuildContext context) {
    return Obx(
      () => EHGalleryCollection(
        key: state.galleryCollectionKey,
        context: context,
        gallerys: state.gallerys,
        listMode: StyleSetting.pageListMode[state.route] ?? StyleSetting.listMode.value,
        loadingState: state.loadingState,
        handleTapCard: logic.handleTapGalleryCard,
        handleLongPressCard: (gallery) => logic.handleLongPressCard(context, gallery),
        handleSecondaryTapCard: (gallery) => logic.handleSecondaryTapCard(context, gallery),
        handleLoadMore: logic.loadMore,
      ),
    );
  }
}
