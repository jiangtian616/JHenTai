import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_page/horizontal_page_layout.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../config/ui_config.dart';
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
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ScrollConfiguration(
        behavior: GetPlatform.isDesktop ? UIConfig.behaviorWithScrollBar : UIConfig.behaviorWithoutScrollBar,
        child: EHKeyboardListener(
          focusNode: state.focusNode,
          handleEsc: backRoute,
          handleSpace: logic.toggleMenu,
          handlePageDown: logic.toNext,
          handlePageUp: logic.toPrev,
          handleArrowDown: logic.toNext,
          handleArrowUp: logic.toPrev,
          handleArrowRight: logic.toRight,
          handleArrowLeft: logic.toLeft,
          handleLCtrl: logic.toLeft,
          handleRCtrl: logic.toRight,
          handleEnd: backRoute,
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
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
    return Positioned(
      bottom: 0,
      right: 0,
      child: Obx(
        () {
          if (ReadSetting.showStatusInfo.isFalse) {
            return const SizedBox();
          }

          Widget child = DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
            child: Container(
              decoration: BoxDecoration(
                color: Get.theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.only(right: 32, bottom: 1, top: 3, left: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildPageNoInfo().marginOnly(right: 10),
                  _buildCurrentTime().marginOnly(right: 10),
                  if (!GetPlatform.isDesktop) _buildBatteryLevel(),
                ],
              ),
            ),
          );

          return GetBuilder<ReadPageLogic>(
            id: logic.rightBottomInfoId,
            builder: (_) => state.isMenuOpen ? child.fadeOut() : child.fadeIn(),
          );
        },
      ),
    );
  }

  Widget _buildPageNoInfo() {
    return GetBuilder<ReadPageLogic>(
      id: logic.pageNoId,
      builder: (_) => Text('${state.readPageInfo.currentIndex + 1}/${state.readPageInfo.pageCount}'),
    );
  }

  Widget _buildCurrentTime() {
    return GetBuilder<ReadPageLogic>(
      id: logic.currentTimeId,
      builder: (_) => Text(DateFormat('HH:mm').format(DateTime.now())),
    );
  }

  Widget _buildBatteryLevel() {
    return GetBuilder<ReadPageLogic>(
      id: logic.batteryId,
      builder: (_) => Text('${state.batteryLevel}%'),
    );
  }

  /// gesture for turn page and pop menu
  Widget buildGestureRegion() {
    return Row(
      children: [
        /// left region
        Expanded(
          flex: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: logic.toLeft,
            onDoubleTapDown: (TapDownDetails details) {
              if (ReadSetting.enableDoubleTapToScaleUp.isTrue) {
                logic.toggleScale(details.globalPosition);
              }
            },
            onDoubleTap: () {
              if (ReadSetting.enableDoubleTapToScaleUp.isFalse) {
                logic.toLeft();
              }
            },
          ),
        ),

        /// center region
        Expanded(
          flex: 4,
          child: Column(
            children: [
              /// top center
              Expanded(
                flex: 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTapDown: (TapDownDetails details) =>
                      ReadSetting.enableDoubleTapToScaleUp.isTrue ? logic.toggleScale(details.globalPosition) : logic.toggleMenu(),

                  /// just to invoke [onDoubleTapDown]
                  onDoubleTap: () {},
                ),
              ),

              /// center
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: logic.toggleMenu,
                  onDoubleTapDown: (TapDownDetails details) =>
                      ReadSetting.enableDoubleTapToScaleUp.isTrue ? logic.toggleScale(details.globalPosition) : logic.toggleMenu(),

                  /// just to invoke [onDoubleTapDown]
                  onDoubleTap: () {},
                ),
              ),

              /// bottom center
              Expanded(
                flex: 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTapDown: (TapDownDetails details) =>
                      ReadSetting.enableDoubleTapToScaleUp.isTrue ? logic.toggleScale(details.globalPosition) : logic.toggleMenu(),

                  /// just to invoke [onDoubleTapDown]
                  onDoubleTap: () {},
                ),
              ),
            ],
          ),
        ),

        /// right region: toRight
        Expanded(
          flex: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: logic.toRight,
            onDoubleTapDown: (TapDownDetails details) {
              if (ReadSetting.enableDoubleTapToScaleUp.isTrue) {
                logic.toggleScale(details.globalPosition);
              }
            },
            onDoubleTap: () {
              if (ReadSetting.enableDoubleTapToScaleUp.isFalse) {
                logic.toRight();
              }
            },
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
        height: state.isMenuOpen ? UIConfig.appBarHeight + context.mediaQuery.padding.top : 0,
        width: fullScreenWidth,
        child: AppBar(
          backgroundColor: UIConfig.readPageMenuColor,
          leading: BackButton(color: UIConfig.readPageButtonColor),
          actions: [
            if (GetPlatform.isDesktop)
              IconButton(
                icon: Icon(Icons.help, color: UIConfig.readPageButtonColor),
                onPressed: () => toast(
                  'PageDown、RCtrl、→、↓  :  ${'toNext'.tr}'
                  '\n'
                  'PageUp、LCtrl、 ←、↑  :  ${'toPrev'.tr}'
                  '\n'
                  'Esc、End  :  ${'back'.tr}'
                  '\n'
                  'Space  :  ${'toggleMenu'.tr}',
                  isShort: false,
                ),
              ),
            GetBuilder<ReadPageLogic>(
              id: logic.autoModeId,
              builder: (_) => IconButton(
                icon: const Icon(Icons.schedule),
                onPressed: logic.toggleAutoMode,
                color: state.autoMode ? Get.theme.colorScheme.primary : UIConfig.readPageButtonColor,
              ),
            ),
            IconButton(
              onPressed: () => toRoute(Routes.settingRead, id: fullScreen)?.then((_) => state.focusNode.requestFocus()),
              icon: Icon(Icons.settings, color: UIConfig.readPageButtonColor),
            ),
          ],
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
          bottom: state.isMenuOpen
              ? 0
              : ReadSetting.showThumbnails.isTrue
                  ? -(UIConfig.readPageBottomThumbnailsRegionHeight +
                      UIConfig.readPageBottomSliderHeight +
                      max(MediaQuery.of(context).viewPadding.bottom, UIConfig.readPageBottomSpacingHeight))
                  : -(UIConfig.readPageBottomSliderHeight + max(MediaQuery.of(context).viewPadding.bottom, UIConfig.readPageBottomSpacingHeight)),
          child: ColoredBox(
            color: UIConfig.readPageMenuColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ReadSetting.showThumbnails.isTrue) _buildThumbnails(),
                _buildSlider(),
                SizedBox(height: max(MediaQuery.of(context).viewPadding.bottom, UIConfig.readPageBottomSpacingHeight)),
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
      height: UIConfig.readPageBottomThumbnailsRegionHeight,
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
            width: UIConfig.readPageThumbnailWidth,
            height: UIConfig.readPageThumbnailHeight,
            child: GetBuilder<ReadPageLogic>(
                id: logic.thumbnailNoId,
                builder: (_) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => logic.jump2PageIndex(index),
                          child: state.readPageInfo.mode == ReadMode.online ? _buildThumbnailInOnlineMode(index) : _buildThumbnailInLocalMode(index),
                        ),
                      ),
                      GetBuilder<ReadPageLogic>(
                        builder: (_) => Text(
                          (index + 1).toString(),
                          style: TextStyle(fontSize: 9, color: state.readPageInfo.currentIndex == index ? Get.theme.colorScheme.primary : null),
                        ),
                      ).marginOnly(top: 4),
                    ],
                  );
                }),
          ),
          separatorBuilder: (_, __) => const VerticalDivider(width: 4),
        ),
      ),
    );
  }

  Widget _buildThumbnailInOnlineMode(int index) {
    return GetBuilder<ReadPageLogic>(
      id: '${logic.onlineImageId}::$index',
      builder: (_) {
        if (state.thumbnails[index] == null) {
          if (state.parseImageHrefsStates[index] == LoadingState.idle) {
            logic.beginToParseImageHref(index);
          }

          return Center(child: UIConfig.loadingAnimation);
        }

        return Center(
          child: EHThumbnail(thumbnail: state.thumbnails[index]!),
        );
      },
    );
  }

  Widget _buildThumbnailInLocalMode(int index) {
    return GetBuilder<GalleryDownloadService>(
      id: '$downloadImageId::${state.readPageInfo.gid}',
      builder: (_) {
        if (state.images[index]?.downloadStatus != DownloadStatus.downloaded) {
          return Center(child: UIConfig.loadingAnimation);
        }

        return EHImage.file(
          borderRadius: BorderRadius.circular(8),
          containerHeight: UIConfig.readPageThumbnailHeight,
          containerWidth: UIConfig.readPageThumbnailWidth,
          galleryImage: state.images[index]!,
        );
      },
    );
  }

  Widget _buildSlider() {
    return GetBuilder<ReadPageLogic>(
      id: logic.sliderId,
      builder: (_) => SizedBox(
        height: UIConfig.readPageBottomSliderHeight,
        width: fullScreenWidth,
        child: Row(
          children: [
            Text((state.readPageInfo.currentIndex + 1).toString()).marginOnly(left: 36, right: 4),
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
            Text(state.readPageInfo.pageCount.toString()).marginOnly(right: 36, left: 4),
          ],
        ),
      ),
    );
  }
}
