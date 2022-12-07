import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import '../../../../mixin/scroll_to_top_page_mixin.dart';
import '../../../../setting/style_setting.dart';
import '../../../layout/mobile_v2/notification/tap_menu_button_notification.dart';
import '../../download_base_page.dart';
import 'grid_base_page_logic.dart';
import 'grid_base_page_service_mixin.dart';
import 'grid_base_page_state.dart';

abstract class GridBasePage extends StatelessWidget with Scroll2TopPageMixin {
  const GridBasePage({Key? key}) : super(key: key);

  DownloadPageGalleryType get galleryType;

  @override
  GridBasePageLogic get logic;

  @override
  GridBasePageState get state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: buildBody(),
      floatingActionButton: buildFloatingActionButton(),
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
      actions: [
        IconButton(
          icon: const Icon(Icons.grid_view),
          onPressed: () => DownloadPageBodyTypeChangeNotification(bodyType: DownloadPageBodyType.list).dispatch(context),
        ),
      ],
    );
  }

  Widget buildBody() {
    return GetBuilder<GridBasePageServiceMixin>(
      global: false,
      init: logic.galleryService,
      id: logic.galleryService.galleryCountOrOrderChangedId,
      builder: (_) => GetBuilder<GridBasePageLogic>(
        global: false,
        init: logic,
        id: logic.bodyId,
        builder: (_) => NotificationListener<UserScrollNotification>(
          onNotification: logic.onUserScroll,
          child: EHWheelSpeedController(
            controller: state.scrollController,
            child: GridView.builder(
              key: PageStorageKey(state.currentGroup),
              controller: state.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: UIConfig.downloadPageGridViewCardWidth,
                mainAxisSpacing: 24,
                crossAxisSpacing: 12,
                childAspectRatio: UIConfig.downloadPageGridViewCardAspectRatio,
              ),
              itemCount: state.isAtRoot ? state.allRootGroups.length : state.currentGalleryObjects.length + 1,
              itemBuilder: (context, index) {
                if (state.isAtRoot) {
                  return groupBuilder(context, index);
                }

                if (index == 0) {
                  return ReturnWidget(onTap: () => logic.enterGroup(null));
                }

                return galleryBuilder(context, state.currentGalleryObjects, index - 1);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget groupBuilder(BuildContext context, int index);

  Widget galleryBuilder(BuildContext context, List galleryObjects, int index);
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
  final GalleryImage? cover;
  final VoidCallback onTapCover;
  final VoidCallback onTapTitle;
  final VoidCallback onLongPress;
  final VoidCallback onSecondTap;

  const GridGallery({
    Key? key,
    required this.title,
    this.cover,
    required this.onTapCover,
    required this.onTapTitle,
    required this.onLongPress,
    required this.onSecondTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      onSecondaryTap: onSecondTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTapCover,
              child: cover == null
                  ? UIConfig.loadingAnimation
                  : LayoutBuilder(
                      builder: (_, constraints) => EHImage(
                        galleryImage: cover!,
                        containerWidth: constraints.maxWidth,
                        containerHeight: constraints.maxHeight,
                        fit: BoxFit.cover,
                        forceFadeIn: true,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
            ),
          ),
          GestureDetector(
            onTap: onTapTitle,
            child: Center(
              child: Text(title.breakWord, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

class GridGroup extends StatelessWidget {
  final String groupName;
  final List<GalleryImage?> images;
  final VoidCallback onTap;
  final IconData? emptyIcon;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondTap;

  const GridGroup({
    Key? key,
    required this.groupName,
    required this.images,
    required this.onTap,
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
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(UIConfig.downloadPageGridViewGroupPadding),
              child: images.isEmpty
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
    if (images.length <= index) {
      return const SizedBox();
    }

    if (images[index] == null) {
      return UIConfig.loadingAnimation;
    }

    return EHImage.autoLayout(
      galleryImage: images[index]!,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
    );
  }
}
