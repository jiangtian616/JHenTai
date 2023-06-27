import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_double_column/horizontal_double_column_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_page/horizontal_page_layout.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:jhentai/src/pages/read/widget/eh_scrollable_positioned_list.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/widget/eh_mouse_button_listener.dart';

import '../../config/ui_config.dart';
import '../../routes/routes.dart';
import '../../service/gallery_download_service.dart';
import '../../setting/read_setting.dart';
import '../../utils/route_util.dart';
import '../../utils/screen_size_util.dart';
import '../../utils/toast_util.dart';
import '../../widget/eh_image.dart';
import '../../widget/eh_keyboard_listener.dart';
import '../../widget/eh_read_page_stack.dart';
import '../../widget/eh_thumbnail.dart';
import '../../widget/eh_wheel_speed_controller_for_read_page.dart';
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
      child: EHMouseButtonListener(
        onFifthButtonTapDown: (_) => backRoute(),
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
          handleA: logic.toLeft,
          handleD: logic.toRight,
          handleM: logic.handleM,
          handleEnd: backRoute,
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.copyWith(
                  color: UIConfig.readPageForeGroundColor,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
            child: Stack(
              children: [
                EHReadPageStack(
                  children: [
                    buildGestureRegion(),
                    buildLayout(),
                  ],
                ),
                buildRightBottomInfo(context),
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
      logic.resetImageSize();

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
                  color: UIConfig.readPageForeGroundColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
            child: Container(
              decoration: BoxDecoration(
                color: UIConfig.readPageRightBottomRegionColor,
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
        Expanded(flex: 1, child: GestureDetector(onTap: logic.toLeft, behavior: HitTestBehavior.opaque)),

        /// center region
        Expanded(flex: 3, child: GestureDetector(onTap: logic.toggleMenu, behavior: HitTestBehavior.opaque)),

        /// right region: toRight
        Expanded(flex: 1, child: GestureDetector(onTap: logic.toRight, behavior: HitTestBehavior.opaque)),
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
          leading: const BackButton(color: UIConfig.readPageButtonColor),
          actions: [
            if (GetPlatform.isDesktop)
              ElevatedButton(
                child: const Icon(Icons.help, color: UIConfig.readPageButtonColor),
                onPressed: () => toast(
                  'PageDown、→、↓ 、D :  ${'toNext'.tr}'
                  '\n'
                  'PageUp、←、↑、A  :  ${'toPrev'.tr}'
                  '\n'
                  'Esc、End  :  ${'back'.tr}'
                  '\n'
                  'Space  :  ${'toggleMenu'.tr}'
                  '\n'
                  'M  :  ${'displayFirstPageAlone'.tr}',
                  isShort: false,
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: const EdgeInsets.all(0),
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(56, 56),
                ),
              ),
            if (GetPlatform.isDesktop &&
                state.readPageInfo.gid != null &&
                (state.readPageInfo.mode == ReadMode.downloaded || state.readPageInfo.mode == ReadMode.archive) &&
                state.readPageInfo.useSuperResolution)
              TextButton(
                child: GetBuilder<SuperResolutionService>(
                  id: '${SuperResolutionService.superResolutionId}::${state.readPageInfo.gid}',
                  builder: (_) => Text(
                    'AI' + logic.getSuperResolutionProgress(),
                    style: TextStyle(
                      fontSize: 18,
                      color: state.useSuperResolution ? UIConfig.readPageActiveButtonColor(context) : UIConfig.readPageButtonColor,
                    ),
                  ),
                ),
                onPressed: logic.handleTapSuperResolutionButton,
                style: TextButton.styleFrom(
                  minimumSize: const Size(56, 56),
                ),
              ),
            Obx(() {
              if (ReadSetting.enableDoubleColumn.isFalse || logic.layoutLogic is! HorizontalDoubleColumnLayoutLogic) {
                return const SizedBox();
              }
              return ElevatedButton(
                child: Icon(
                  Icons.looks_one,
                  color: (logic.layoutLogic as HorizontalDoubleColumnLayoutLogic).state.displayFirstPageAlone
                      ? UIConfig.readPageActiveButtonColor(context)
                      : UIConfig.readPageButtonColor,
                ),
                onPressed: (logic.layoutLogic as HorizontalDoubleColumnLayoutLogic).toggleDisplayFirstPageAlone,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: const EdgeInsets.all(0),
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(56, 56),
                ),
              );
            }),
            GetBuilder<ReadPageLogic>(
              id: logic.autoModeId,
              builder: (_) => ElevatedButton(
                child: Icon(Icons.schedule, color: state.autoMode ? UIConfig.readPageActiveButtonColor(context) : UIConfig.readPageButtonColor),
                onPressed: logic.toggleAutoMode,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: const EdgeInsets.all(0),
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(56, 56),
                ),
              ),
            ),
            ElevatedButton(
              child: const Icon(Icons.settings, color: UIConfig.readPageButtonColor),
              onPressed: () {
                logic.restoreImmersiveMode();
                toRoute(Routes.settingRead, id: fullScreen)?.then((_) {
                  logic.toggleCurrentImmersiveMode();
                  state.focusNode.requestFocus();
                });
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.all(0),
                surfaceTintColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(56, 56),
              ),
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
                if (ReadSetting.showThumbnails.isTrue) _buildThumbnails(context),
                _buildSlider(),
                SizedBox(height: max(MediaQuery.of(context).viewPadding.bottom, UIConfig.readPageBottomSpacingHeight)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnails(BuildContext context) {
    return Container(
      width: fullScreenWidth,
      height: UIConfig.readPageBottomThumbnailsRegionHeight,
      padding: const EdgeInsets.only(top: 10),
      child: Obx(
        () => EHWheelSpeedControllerForReadPage(
          scrollController: state.thumbnailsScrollController,
          child: EHScrollablePositionedList.separated(
            scrollDirection: Axis.horizontal,
            reverse: ReadSetting.readDirection.value == ReadDirection.right2left,
            physics: const ClampingScrollPhysics(),
            minCacheExtent: 1 * fullScreenWidth,
            initialScrollIndex: state.readPageInfo.initialIndex,
            itemCount: state.readPageInfo.pageCount,
            itemScrollController: state.thumbnailsScrollController,
            itemPositionsListener: state.thumbnailPositionsListener,
            itemBuilder: (_, index) => GetBuilder<ReadPageLogic>(
              id: logic.thumbnailNoId,
              builder: (_) => SizedBox(
                width: UIConfig.readPageThumbnailWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => logic.jump2PageIndex(index),
                        child: state.readPageInfo.mode == ReadMode.online
                            ? _buildThumbnailInOnlineMode(context, index)
                            : _buildThumbnailInLocalMode(context, index),
                      ),
                    ),
                    GetBuilder<ReadPageLogic>(
                      builder: (_) => Center(
                        child: Container(
                          width: 24,
                          decoration: BoxDecoration(
                            color: state.readPageInfo.currentIndex == index
                                ? UIConfig.readPageBottomCurrentImageHighlightBackgroundColor(context)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (index + 1).toString(),
                            style: TextStyle(
                              fontSize: 9,
                              color: state.readPageInfo.currentIndex == index
                                  ? UIConfig.readPageBottomCurrentImageHighlightForegroundColor(context)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ).marginOnly(top: 4),
                  ],
                ),
              ),
            ),
            separatorBuilder: (_, __) => const SizedBox(width: 6),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailInOnlineMode(BuildContext context, int index) {
    return GetBuilder<ReadPageLogic>(
      id: '${logic.onlineImageId}::$index',
      builder: (_) {
        if (state.thumbnails[index] == null) {
          if (state.parseImageHrefsStates[index] == LoadingState.idle) {
            logic.beginToParseImageHref(index);
          }

          return Center(child: UIConfig.loadingAnimation(context));
        }

        return LayoutBuilder(
          builder: (_, constraints) => EHThumbnail(
            thumbnail: state.thumbnails[index]!,
            containerHeight: constraints.maxHeight,
            containerWidth: constraints.maxWidth,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _buildThumbnailInLocalMode(BuildContext context, int index) {
    return GetBuilder<GalleryDownloadService>(
      id: '${Get.find<GalleryDownloadService>().downloadImageId}::${state.readPageInfo.gid}::$index',
      builder: (_) {
        if (state.images[index]?.downloadStatus != DownloadStatus.downloaded) {
          return Center(child: UIConfig.loadingAnimation(context));
        }
        return LayoutBuilder(
          builder: (_, constraints) => EHImage(
            galleryImage: state.images[index]!,
            containerHeight: constraints.maxHeight,
            containerWidth: constraints.maxWidth,
            borderRadius: BorderRadius.circular(8),
            maxBytes: 1024 * 50,
          ),
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
              child: ExcludeFocus(
                child: Material(
                  color: Colors.transparent,
                  child: RotatedBox(
                    quarterTurns: ReadSetting.readDirection.value == ReadDirection.right2left ? 2 : 0,
                    child: Slider(
                      min: 1,
                      max: state.readPageInfo.pageCount.toDouble(),
                      value: state.readPageInfo.currentIndex + 1.0,
                      thumbColor: UIConfig.readPageForeGroundColor,
                      onChanged: logic.handleSlide,
                      onChangeEnd: logic.handleSlideEnd,
                    ),
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
