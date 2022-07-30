import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_logic.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';

import '../../widget/eh_gallery_collection.dart';
import '../../widget/eh_wheel_speed_controller.dart';
import '../../widget/loading_state_indicator.dart';

class RanklistPage extends BasePage {
  const RanklistPage({Key? key}) : super(key: key);

  @override
  State<BasePage> createState() => _RanklistPageState();
}

class _RanklistPageState extends BasePageFlutterState {
  @override
  final RanklistPageLogic logic = Get.put<RanklistPageLogic>(RanklistPageLogic(), permanent: true);
  @override
  final RanklistPageState state = Get.find<RanklistPageLogic>().state;

  @override
  AppBar? buildAppBar() {
    return AppBar(
      title: GetBuilder<RanklistPageLogic>(
        id: 'appBarTitleId',
        builder: (_) => Text('${state.ranklistType.name.tr} ${'ranklist'.tr}'),
      ),
      centerTitle: true,
      elevation: 1,
      actions: [
        ...super.buildAppBarButtons(),
        GetBuilder<RanklistPageLogic>(
          id: 'appBarTitleId',
          builder: (_) => ExcludeFocus(
            child: PopupMenuButton(
              initialValue: state.ranklistType,
              padding: EdgeInsets.zero,
              onSelected: logic.handleChangeRanklist,
              tooltip: "",
              itemBuilder: (BuildContext context) => <PopupMenuEntry<RanklistType>>[
                PopupMenuItem<RanklistType>(
                  value: RanklistType.allTime,
                  child: Center(child: Text('allTime'.tr)),
                ),
                PopupMenuItem<RanklistType>(
                  value: RanklistType.year,
                  child: Center(child: Text('year'.tr)),
                ),
                PopupMenuItem<RanklistType>(
                  value: RanklistType.month,
                  child: Center(child: Text('month'.tr)),
                ),
                PopupMenuItem<RanklistType>(
                  value: RanklistType.day,
                  child: Center(child: Text('day'.tr)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildListBody(BuildContext context) {
    return GetBuilder<RanklistPageLogic>(
      id: logic.bodyId,
      global: false,
      init: logic,
      builder: (_) => state.gallerys.isEmpty && state.loadingState != LoadingState.idle
          ? buildCenterStatusIndicator()
          : EHWheelSpeedController(
              scrollController: state.scrollController,
              child: CustomScrollView(
                key: state.pageStorageKey,
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

  @override
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
