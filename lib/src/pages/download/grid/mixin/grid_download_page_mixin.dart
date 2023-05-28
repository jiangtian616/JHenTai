import 'package:flutter/material.dart';
import 'package:flutter_draggable_gridview/flutter_draggable_gridview.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';

import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_page_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../setting/style_setting.dart';
import '../../../layout/mobile_v2/notification/tap_menu_button_notification.dart';
import '../../download_base_page.dart';
import 'grid_download_page_logic_mixin.dart';
import 'grid_download_page_service_mixin.dart';
import 'grid_download_page_state_mixin.dart';

mixin GridBasePage on StatelessWidget implements Scroll2TopPageMixin {
  DownloadPageGalleryType get galleryType;

  GridBasePageLogic get logic;

  GridBasePageState get state;

  @override
  Scroll2TopLogicMixin get scroll2TopLogic => logic;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: buildBody(context),
      floatingActionButton: buildFloatingActionButton(),
      bottomNavigationBar: buildGridBottomAppBar(context),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      leading: StyleSetting.isInV2Layout
          ? IconButton(icon: const Icon(FontAwesomeIcons.bars, size: 20), onPressed: () => TapMenuButtonNotification().dispatch(context))
          : null,
      titleSpacing: 0,
      title: DownloadPageSegmentControl(galleryType: galleryType),
      actions: buildAppBarActions(context),
    );
  }

  Widget buildBody(BuildContext context) {
    return GetBuilder<GridBasePageServiceMixin>(
      global: false,
      init: logic.galleryService,
      id: logic.galleryService.galleryCountChangedId,
      builder: (_) => GetBuilder<GridBasePageLogic>(
        global: false,
        init: logic,
        id: logic.bodyId,
        builder: (_) => NotificationListener<UserScrollNotification>(
          onNotification: logic.onUserScroll,
          child: EHWheelSpeedController(
            controller: state.scrollController,
            child: Obx(
              () => DraggableGridViewBuilder(
                key: PageStorageKey(state.currentGroup),
                controller: state.scrollController,
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 24),
                children: getChildren(context),
                dragFeedback: (List<DraggableGridItem> list, int index) {
                  return SizedBox(
                    width: 150,
                    height: 200,
                    child: Center(child: DefaultTextStyle(style: DefaultTextStyle.of(context).style, child: list[index].child)),
                  );
                },
                dragPlaceHolder: (_, __) {
                  return PlaceHolderWidget(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: UIConfig.downloadPageGridViewCardDragBorderColor(context), width: 1.2),
                      ),
                    ),
                  );
                },
                dragCompletion: (_, int beforeIndex, int afterIndex) async {
                  if (state.isAtRoot) {
                    await logic.saveGroupOrderAfterDrag(beforeIndex, afterIndex);
                  } else {
                    await logic.saveGalleryOrderAfterDrag(beforeIndex - 1, afterIndex - 1);
                  }
                },
                gridDelegate: state.isAtRoot
                    ? StyleSetting.crossAxisCountInGridDownloadPageForGroup.value == null
                        ? const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: UIConfig.downloadPageGridViewCardWidth,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 12,
                            childAspectRatio: UIConfig.downloadPageGridViewCardAspectRatio,
                          )
                        : SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: StyleSetting.crossAxisCountInGridDownloadPageForGroup.value!,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 12,
                            childAspectRatio: UIConfig.downloadPageGridViewCardAspectRatio,
                          )
                    : StyleSetting.crossAxisCountInGridDownloadPageForGallery.value == null
                        ? const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: UIConfig.downloadPageGridViewCardWidth,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 12,
                            childAspectRatio: UIConfig.downloadPageGridViewCardAspectRatio,
                          )
                        : SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: StyleSetting.crossAxisCountInGridDownloadPageForGallery.value!,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 12,
                            childAspectRatio: UIConfig.downloadPageGridViewCardAspectRatio,
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> buildAppBarActions(BuildContext context) {
    return [
      GetBuilder<GridBasePageLogic>(
        global: false,
        init: logic,
        id: logic.editButtonId,
        builder: (_) => IconButton(
          icon: const Icon(Icons.sort),
          selectedIcon: const Icon(Icons.save),
          onPressed: logic.toggleEditMode,
          isSelected: state.inEditMode,
        ),
      ),
      PopupMenuButton(
        itemBuilder: (context) {
          return [
            PopupMenuItem(
              value: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const Icon(Icons.view_list), const SizedBox(width: 12), Text('switch2ListMode'.tr)],
              ),
            ),
            PopupMenuItem(
              value: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const Icon(Icons.play_arrow), const SizedBox(width: 12), Text('resumeAllTasks'.tr)],
              ),
            ),
            PopupMenuItem(
              value: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const Icon(Icons.pause), const SizedBox(width: 12), Text('pauseAllTasks'.tr)],
              ),
            ),
          ];
        },
        onSelected: (value) {
          if (value == 0) {
            DownloadPageBodyTypeChangeNotification(bodyType: DownloadPageBodyType.list).dispatch(context);
          }
          if (value == 2) {
            logic.handleResumeAllTasks();
          }
          if (value == 3) {
            logic.handlePauseAllTasks();
          }
        },
      ),
    ];
  }

  Widget? buildGridBottomAppBar(BuildContext context) {
    return null;
  }

  List<DraggableGridItem> getChildren(BuildContext context) {
    if (state.isAtRoot) {
      return state.allRootGroups
          .map((groupName) => DraggableGridItem(
                child: groupBuilder(context, groupName, state.inEditMode),
                isDraggable: state.inEditMode,
              ))
          .toList();
    }

    DraggableGridItem returnWidget = DraggableGridItem(
      child: ReturnWidget(
        onTap: () {
          state.inEditMode = false;
          logic.backGroup();
        },
      ),
    );

    List<DraggableGridItem> galleryWidgets = state.currentGalleryObjects
        .map((gallery) => DraggableGridItem(
              child: galleryBuilder(context, gallery, state.inEditMode),
              isDraggable: state.inEditMode,
            ))
        .toList();

    return [returnWidget, ...galleryWidgets];
  }

  GridGroup groupBuilder(BuildContext context, String groupName, bool inEditMode);

  GridGallery galleryBuilder(BuildContext context, covariant Object gallery, bool inEditMode);

  Widget buildGroupInnerImage(GalleryImage image) {
    return EHImage.autoLayout(
      galleryImage: image,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
      maxBytes: 2 * 1024 * 1024,
    );
  }

  Widget buildGalleryImage(GalleryImage image) {
    return EHImage.autoLayout(
      galleryImage: image,
      fit: BoxFit.cover,
      forceFadeIn: true,
      borderRadius: BorderRadius.circular(12),
      maxBytes: 2 * 1024 * 1024,
    );
  }
}

class ReturnWidget extends StatelessWidget {
  final VoidCallback onTap;

  const ReturnWidget({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Icon(Icons.keyboard_return),
    );
  }
}

class GridGallery extends StatelessWidget {
  final String title;
  final Widget widget;
  final bool isOriginal;
  final int? gid;
  final SuperResolutionType? superResolutionType;
  final VoidCallback? onTapWidget;
  final VoidCallback? onTapTitle;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondTap;
  final VoidCallback? onTertiaryTap;

  const GridGallery({
    Key? key,
    required this.title,
    required this.widget,
    required this.isOriginal,
    this.gid,
    this.superResolutionType,
    this.onTapWidget,
    this.onTapTitle,
    this.onLongPress,
    this.onSecondTap,
    this.onTertiaryTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapWidget,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondTap,
      onTertiaryTapDown: (_) => onTertiaryTap?.call(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              children: [widget, buildChips(context)],
            ),
          ),
          GestureDetector(
            onTap: onTapTitle,
            child: Center(child: Text(title.breakWord, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ),
        ],
      ),
    );
  }

  Positioned buildChips(BuildContext context) {
    return Positioned(
      bottom: 4,
      right: 4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (gid != null && superResolutionType != null)
            GetBuilder<SuperResolutionService>(
              id: '${SuperResolutionService.superResolutionId}::$gid',
              builder: (_) {
                SuperResolutionInfo? superResolutionInfo = Get.find<SuperResolutionService>().get(gid!, superResolutionType!);
                return superResolutionInfo == null
                    ? const SizedBox()
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: UIConfig.backGroundColor(context),
                          borderRadius: superResolutionInfo.status == SuperResolutionStatus.success ? null : BorderRadius.circular(4),
                          border: Border.all(color: UIConfig.onBackGroundColor(context)),
                          shape: superResolutionInfo.status == SuperResolutionStatus.success ? BoxShape.circle : BoxShape.rectangle,
                        ),
                        child: Text(
                          superResolutionInfo.status == SuperResolutionStatus.paused
                              ? 'AI'
                              : superResolutionInfo.status == SuperResolutionStatus.success
                                  ? 'AI'
                                  : 'AI(${superResolutionInfo.imageStatuses.fold<int>(0, (previousValue, element) => previousValue + (element == SuperResolutionStatus.success ? 1 : 0))}/${superResolutionInfo.imageStatuses.length})',
                          style: TextStyle(
                            fontSize: 9,
                            color: UIConfig.onBackGroundColor(context),
                            decoration: superResolutionInfo.status == SuperResolutionStatus.paused ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      );
              },
            ),
          if (isOriginal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: UIConfig.backGroundColor(context),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: UIConfig.onBackGroundColor(context)),
              ),
              child: Text('original'.tr, style: TextStyle(fontSize: 9, color: UIConfig.onBackGroundColor(context))),
            ),
        ],
      ),
    );
  }
}

class GridGroup extends StatelessWidget {
  static const int maxWidgetCount = 4;

  final String groupName;
  final List<Widget> widgets;
  final VoidCallback? onTap;
  final IconData? emptyIcon;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondTap;

  const GridGroup({
    Key? key,
    required this.groupName,
    required this.widgets,
    this.onTap,
    this.emptyIcon,
    this.onLongPress,
    this.onSecondTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onSecondaryTap: onSecondTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: UIConfig.downloadPageGridViewGroupBackGroundColor(context), borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(UIConfig.downloadPageGridViewGroupPadding),
              child: widgets.isEmpty
                  ? Center(child: Icon(emptyIcon ?? Icons.folder, size: 32))
                  : Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildInnerImage(0)),
                              Expanded(child: _buildInnerImage(1).marginOnly(left: UIConfig.downloadPageGridViewGroupPadding)),
                            ],
                          ),
                        ),
                        const SizedBox(height: UIConfig.downloadPageGridViewGroupPadding),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildInnerImage(2)),
                              Expanded(child: _buildInnerImage(3).marginOnly(left: UIConfig.downloadPageGridViewGroupPadding)),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildInnerImage(int index) {
    if (widgets.length <= index) {
      return const SizedBox();
    }
    return widgets[index];
  }
}
