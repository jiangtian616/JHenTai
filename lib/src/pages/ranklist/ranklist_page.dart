import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_logic.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';

import '../layout/mobile_v2/notification/tap_menu_button_notification.dart';

class RanklistPage extends BasePage {
  const RanklistPage({
    Key? key,
    bool showMenuButton = false,
    bool showTitle = false,
  }) : super(
          key: key,
          showMenuButton: showMenuButton,
          showTitle: showTitle,
        );

  @override
  RanklistPageLogic get logic => Get.find<RanklistPageLogic>();

  @override
  RanklistPageState get state => Get.find<RanklistPageLogic>().state;

  @override
  AppBar? buildAppBar(BuildContext context) {
    return AppBar(
      title: GetBuilder<RanklistPageLogic>(
        id: 'appBarTitleId',
        builder: (_) => Text('${state.ranklistType.name.tr} ${'ranklist'.tr}'),
      ),
      centerTitle: true,
      elevation: 1,
      leading: showMenuButton
          ? IconButton(
              icon: const Icon(FontAwesomeIcons.bars, size: 20),
              onPressed: () => TapMenuButtonNotification().dispatch(context),
            )
          : null,
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
}
