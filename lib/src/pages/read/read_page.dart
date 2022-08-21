import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_double_column/horizontal_double_column_layout_state.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_page/horizontal_page_layout.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../config/global_config.dart';
import '../../model/gallery_image.dart';
import '../../routes/routes.dart';
import '../../service/gallery_download_service.dart';
import '../../setting/read_setting.dart';
import '../../utils/route_util.dart';
import '../../utils/screen_size_util.dart';
import '../../utils/toast_util.dart';
import '../../widget/eh_image.dart';
import '../../widget/eh_keyboard_listener.dart';
import '../../widget/eh_thumbnail.dart';
import '../../widget/loading_state_indicator.dart';
import '../home_page.dart';
import 'layout/horizontal_double_column/horizontal_double_column_layout.dart';
import 'layout/vertical_list/vertical_list_layout.dart';

class ReadPage extends StatelessWidget {
  final ReadPageLogic logic = Get.put<ReadPageLogic>(ReadPageLogic());
  final ReadPageState state = Get.find<ReadPageLogic>().state;

  ReadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.unknown,
          },
          scrollbars: GetPlatform.isDesktop ? true : false,
        ),
        child: EHKeyboardListener(
          focusNode: state.focusNode,
          handleEsc: backRoute,
          handleSpace: logic.toggleMenu,
          handlePageDown: logic.toNext,
          handlePageUp: logic.toPrev,
          handleArrowDown: logic.toNext,
          handleArrowUp: logic.toPrev,
          handleArrowRight: () => ReadSetting.readDirection.value == ReadDirection.right2left ? logic.toPrev() : logic.toNext(),
          handleArrowLeft: () => ReadSetting.readDirection.value == ReadDirection.right2left ? logic.toNext() : logic.toPrev(),
          handleLCtrl: logic.toNext,
          handleEnd: backRoute,
          child: Stack(
            children: [
              buildLayout(),
              buildRightBottomInfo(context),
              buildGestureRegion(),
              buildTopMenu(context),
              buildBottomMenu(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Main region to display images
  Widget buildLayout() {
    return Obx(() {
      if (ReadSetting.readDirection.value == ReadDirection.top2bottom) {
        return VerticalListLayout();
      }

      if (ReadSetting.enableContinuousHorizontalScroll.isTrue) {
        return HorizontalListLayout();
      }
      if (ReadSetting.enableDoubleColumn.isTrue) {
        return HorizontalDoubleColumnLayout();
      }

      return HorizontalPageLayout();
    });
  }

  /// right-bottom info
  Widget buildRightBottomInfo(BuildContext context) {
    return Obx(
      () {
        if (ReadSetting.showStatusInfo.isFalse) {
          return const SizedBox();
        }

        return GetBuilder<ReadPageLogic>(
          id: logic.rightBottomInfoId,
          builder: (_) => state.isMenuOpen
              ? const SizedBox()
              : Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPageNoInfo().marginOnly(right: 8),
                        _buildCurrentTime().marginOnly(right: 8),
                        if (!GetPlatform.isDesktop) _buildBatteryLevel(),
                      ],
                    ).paddingOnly(right: 32, top: 3, bottom: 1, left: 6),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPageNoInfo() {
    return GetBuilder<ReadPageLogic>(
      id: logic.pageNoId,
      builder: (_) => Text(
        '${state.readPageInfo.currentIndex + 1}/${state.readPageInfo.pageCount}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildCurrentTime() {
    return GetBuilder<ReadPageLogic>(
      id: logic.currentTimeId,
      builder: (_) => Text(
        DateFormat('HH:mm').format(DateTime.now()),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildBatteryLevel() {
    return GetBuilder<ReadPageLogic>(
      id: logic.batteryId,
      builder: (_) => Text(
        '${state.batteryLevel}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  /// gesture for turn page and pop menu
  Widget buildGestureRegion() {
    return Row(
      children: [
        /// left region: toLeft
        Expanded(
          flex: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: logic.toLeft,
            onDoubleTap: logic.toLeft,
          ),
        ),

        /// center region: toggle menu
        Expanded(
          flex: 4,
          child: Column(
            children: [
              const Expanded(flex: 1, child: SizedBox()),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: logic.toggleMenu,
                  onDoubleTap: logic.toggleMenu,
                ),
              ),
              const Expanded(flex: 1, child: SizedBox()),
            ],
          ),
        ),

        /// right region: toRight
        Expanded(
          flex: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: logic.toRight,
            onDoubleTap: logic.toRight,
          ),
        ),
      ],
    );
  }

  /// top menu
  Widget buildTopMenu(BuildContext context) {
    return GetBuilder<ReadPageLogic>(
      id: logic.topMenuId,
      builder: (_) => AnimatedPositioned(
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        height: state.isMenuOpen ? GlobalConfig.appBarHeight + context.mediaQuery.padding.top : 0,
        child: SizedBox(
          height: GlobalConfig.appBarHeight + context.mediaQuery.padding.top,
          width: fullScreenWidth,
          child: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            actionsIconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: Colors.black.withOpacity(0.8),
            actions: [
              if (GetPlatform.isDesktop)
                IconButton(
                  onPressed: () => toast(
                    'PageDown、LCtrl、→、↓  :  ${'toNext'.tr}'
                    '\n'
                    'PageUp、 ←、↑  :  ${'toPrev'.tr}'
                    '\n'
                    'Esc、End  :  ${'back'.tr}'
                    '\n'
                    'Space  :  ${'toggleMenu'.tr}',
                    isShort: false,
                  ),
                  icon: const Icon(Icons.help),
                ),
              GetBuilder<ReadPageLogic>(
                id: logic.autoModeId,
                builder: (logic) {
                  return IconButton(
                    onPressed: logic.toggleAutoMode,
                    icon: const Icon(Icons.schedule),
                    color: state.autoMode ? Colors.blue : null,
                  );
                },
              ),
              IconButton(
                onPressed: () => toRoute(Routes.settingRead, id: fullScreen)?.then((_) => state.focusNode.requestFocus()),
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// bottom menu
  Widget buildBottomMenu(BuildContext context) {
    return GetBuilder<ReadPageLogic>(
      id: logic.bottomMenuId,
      builder: (_) => Obx(
        () => AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          bottom: 0,
          height: !state.isMenuOpen
              ? 0
              : ReadSetting.showThumbnails.isTrue
                  ? GlobalConfig.bottomMenuHeight
                  : GlobalConfig.bottomMenuHeightWithoutThumbnails,
          child: ColoredBox(
            color: Colors.black.withOpacity(0.8),
            child: Column(
              children: [
                if (ReadSetting.showThumbnails.isTrue) _buildThumbnails().marginOnly(top: 12),
                _buildSlider().marginOnly(top: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnails() {
    return SizedBox(
      width: fullScreenWidth,
      height: 120,
      child: Obx(
        () => ScrollablePositionedList.separated(
          scrollDirection: Axis.horizontal,
          reverse: ReadSetting.readDirection.value == ReadDirection.right2left,
          physics: const ClampingScrollPhysics(),
          minCacheExtent: 1 * fullScreenWidth,
          initialScrollIndex: state.readPageInfo.initialIndex,
          itemCount: state.readPageInfo.pageCount,
          itemScrollController: state.thumbnailsScrollController,
          itemPositionsListener: state.thumbnailPositionsListener,
          itemBuilder: (_, index) => SizedBox(
            width: 80,
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => logic.jump2PageIndex(index),
                    child: state.readPageInfo.mode == ReadMode.online ? _buildThumbnailInOnlineMode(index) : _buildThumbnailInLocalMode(index),
                  ),
                ),
                GetBuilder<ReadPageLogic>(
                  id: logic.thumbnailsId,
                  builder: (logic) {
                    return Text(
                      (index + 1).toString(),
                      style: state.readPageTextStyle.copyWith(
                        fontSize: 9,
                        color: state.readPageInfo.currentIndex == index ? Get.theme.primaryColorLight : null,
                      ),
                    );
                  },
                ).marginOnly(top: 4),
              ],
            ),
          ),
          separatorBuilder: (_, __) => const Divider(indent: 4),
        ),
      ),
    );
  }

  Widget _buildThumbnailInOnlineMode(int index) {
    return GetBuilder<ReadPageLogic>(
      id: '${logic.onlineImageId}::$index',
      builder: (_) {
        if (state.thumbnails[index] == null) {
          if (state.parseImageHrefsState == LoadingState.idle) {
            logic.beginToParseImageHref(index);
          }
          return const Center(child: CupertinoActivityIndicator());
        }

        return Center(child: EHThumbnail(galleryThumbnail: state.thumbnails[index]!));
      },
    );
  }

  Widget _buildThumbnailInLocalMode(int index) {
    return GetBuilder<GalleryDownloadService>(
      id: '$downloadImageId::${state.readPageInfo.gid}',
      builder: (_) {
        if (state.images[index]?.downloadStatus != DownloadStatus.downloaded) {
          return const Center();
        }

        return EHImage.file(
          galleryImage: state.images[index]!,
          adaptive: true,
          fit: BoxFit.contain,
        );
      },
    );
  }

  Widget _buildSlider() {
    return GetBuilder<ReadPageLogic>(
      id: logic.sliderId,
      builder: (_) => SizedBox(
        width: fullScreenWidth,
        child: Row(
          children: [
            Text(
              (state.readPageInfo.currentIndex + 1).toString(),
              style: state.readPageTextStyle,
            ).marginSymmetric(horizontal: 16),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: RotatedBox(
                  quarterTurns: ReadSetting.readDirection.value == ReadDirection.right2left ? 2 : 0,
                  child: Slider(
                    min: 1,
                    max: state.readPageInfo.pageCount.toDouble(),
                    value: state.readPageInfo.currentIndex + 1.0,
                    thumbColor: Colors.white,
                    onChanged: logic.handleSlide,
                    onChangeEnd: logic.handleSlideEnd,
                  ),
                ),
              ),
            ),
            Text(
              state.readPageInfo.pageCount.toString(),
              style: state.readPageTextStyle,
            ).marginSymmetric(horizontal: 16),
          ],
        ),
      ),
    );
  }
}
