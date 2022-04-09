import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/tab_view/ranklist/ranklist_view_logic.dart';
import 'package:jhentai/src/pages/home/tab_view/ranklist/ranklist_view_state.dart';
import 'package:jhentai/src/widget/eh_gallery_collection.dart';

import '../../../../config/global_config.dart';
import '../../../../widget/loading_state_indicator.dart';

class RanklistView extends StatefulWidget {
  const RanklistView({Key? key}) : super(key: key);

  @override
  _RanklistViewState createState() => _RanklistViewState();
}

class _RanklistViewState extends State<RanklistView> {
  final RanklistViewLogic logic = Get.put<RanklistViewLogic>(RanklistViewLogic());
  final RanklistViewState state = Get.find<RanklistViewLogic>().state;

  @override
  void initState() {
    logic.getRanklist();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GetBuilder<RanklistViewLogic>(
          id: 'appBarTitleId',
          builder: (logic) {
            return Text('${state.ranklistType.name.tr} ${'ranklist'.tr}');
          },
        ),
        centerTitle: true,
        elevation: 1,
        actions: [
          GetBuilder<RanklistViewLogic>(
              id: 'appBarTitleId',
              builder: (logic) {
                return PopupMenuButton(
                  initialValue: state.ranklistType,
                  padding: EdgeInsets.zero,
                  onSelected: logic.handleChangeRanklist,
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
                );
              }),
        ],
      ),
      body: GetBuilder<RanklistViewLogic>(
        id: bodyId,
        builder: (logic) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return state.ranklistGallery[state.ranklistType]!.isEmpty &&
            state.getRanklistLoadingState[state.ranklistType] != LoadingState.idle
        ? _buildCenterStatusIndicator()
        : CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            key: PageStorageKey(state.ranklistType.name),
            slivers: <Widget>[
              _buildRefreshIndicator(),
              _buildGalleryCollection(),
              _buildLoadMoreIndicator(),
            ],
          );
  }

  Widget _buildCenterStatusIndicator() {
    return Center(
      child: GetBuilder<RanklistViewLogic>(
          id: loadingStateId,
          builder: (logic) {
            return LoadingStateIndicator(
              errorTapCallback: () => logic.handleRefresh(),
              noDataTapCallback: () => logic.handleRefresh(),
              loadingState: state.getRanklistLoadingState[state.ranklistType]!,
            );
          }),
    );
  }

  Widget _buildRefreshIndicator() {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: GlobalConfig.refreshTriggerPullDistance,
      onRefresh: () => logic.handleRefresh(),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      sliver: SliverToBoxAdapter(
        child: GetBuilder<RanklistViewLogic>(
            id: loadingStateId,
            builder: (logic) {
              return LoadingStateIndicator(
                loadingState: state.getRanklistLoadingState[state.ranklistType]!,
              );
            }),
      ),
    );
  }

  Widget _buildGalleryCollection() {
    return EHGalleryCollection(
      gallerys: state.ranklistGallery[state.ranklistType]!,
      loadingState: state.getRanklistLoadingState[state.ranklistType]!,
      handleTapCard: logic.handleTapCard,
    );
  }
}
