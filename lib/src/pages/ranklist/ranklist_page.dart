import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_logic.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';


class RanklistPage extends BasePage {
  const RanklistPage({
    Key? key,
    bool showMenuButton = false,
    bool showTitle = false,
    bool showScroll2TopButton = true,
  }) : super(
          key: key,
          showMenuButton: showMenuButton,
          showTitle: showTitle,
          showJumpButton: true,
          showScroll2TopButton: showScroll2TopButton,
        );

  @override
  RanklistPageLogic get logic => Get.put<RanklistPageLogic>(RanklistPageLogic(), permanent: true);

  @override
  RanklistPageState get state => Get.find<RanklistPageLogic>().state;

  @override
  AppBar? buildAppBar(BuildContext context) {
    return AppBar(
      title: Text('${state.ranklistType.name.tr} ${'ranklist'.tr}'),
      centerTitle: true,
      leading: showMenuButton ? super.buildAppBarMenuButton(context) : null,
      actions: [
        ...super.buildAppBarActions(),
        PopupMenuButton(
          tooltip: '',
          initialValue: state.ranklistType,
          onSelected: logic.handleChangeRanklist,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<RanklistType>>[
            PopupMenuItem<RanklistType>(value: RanklistType.allTime, child: Center(child: Text('allTime'.tr))),
            PopupMenuItem<RanklistType>(value: RanklistType.year, child: Center(child: Text('year'.tr))),
            PopupMenuItem<RanklistType>(value: RanklistType.month, child: Center(child: Text('month'.tr))),
            PopupMenuItem<RanklistType>(value: RanklistType.day, child: Center(child: Text('day'.tr))),
          ],
        ),
      ],
    );
  }
}
