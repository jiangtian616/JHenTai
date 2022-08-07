import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/config/global_config.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_thumbnail.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../service/gallery_download_service.dart';
import '../../../utils/route_util.dart';
import '../../../utils/screen_size_util.dart';
import '../../../widget/eh_image.dart';
import '../../../widget/eh_keyboard_listener.dart';
import '../../../widget/loading_state_indicator.dart';
import '../../home_page.dart';
import '../read_page_logic.dart';

class ReadViewHelper extends StatelessWidget {
  final logic = Get.find<ReadPageLogic>();
  final state = Get.find<ReadPageLogic>().state;
  final Widget child;

  ReadViewHelper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
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
            child,
            _buildInfo(context),
            _buildGestureRegion(),
            _buildTopMenu(context),
            _buildBottomMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Obx(() {
      if (ReadSetting.showStatusInfo.isFalse) {
        return const SizedBox();
      }
      return GetBuilder<ReadPageLogic>(
        id: bottomMenuId,
        builder: (logic) {
          return state.isMenuOpen
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
                        GetBuilder<ReadPageLogic>(
                          id: pageNoId,
                          builder: (logic) {
                            return Text(
                              '${state.readIndexRecord + 1}/${state.pageCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            );
                          },
                        ).marginOnly(right: 8),
                        GetBuilder<ReadPageLogic>(
                          id: currentTimeId,
                          builder: (logic) {
                            return Text(
                              DateFormat('HH:mm').format(DateTime.now()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            );
                          },
                        ).marginOnly(right: 8),
                        if (!GetPlatform.isDesktop)
                          GetBuilder<ReadPageLogic>(
                            id: batteryId,
                            builder: (logic) {
                              return Text(
                                '${state.batteryLevel}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                              );
                            },
                          ),
                      ],
                    ).paddingOnly(right: 32, top: 3, bottom: 1, left: 6),
                  ),
                );
        },
      );
    });
  }

  /// turn page and pop menu gesture
  Widget _buildGestureRegion() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: logic.toPrev,
            onDoubleTap: logic.toPrev,
          ),
        ),
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
        Expanded(
          flex: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: logic.toNext,
            onDoubleTap: logic.toNext,
          ),
        ),
      ],
    );
  }

  Widget _buildTopMenu(BuildContext context) {
    return GetBuilder<ReadPageLogic>(
      id: topMenuId,
      builder: (logic) {
        return AnimatedPositioned(
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
                  id: autoModeId,
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
        );
      },
    );
  }

  Widget _buildBottomMenu(BuildContext context) {
    return GetBuilder<ReadPageLogic>(
      id: bottomMenuId,
      builder: (logic) {
        return Obx(() {
          return AnimatedPositioned(
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
          );
        });
      },
    );
  }

  Widget _buildThumbnails() {
    return SizedBox(
      width: fullScreenWidth,
      height: 120,
      child: ScrollablePositionedList.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        minCacheExtent: 1 * fullScreenWidth,
        initialScrollIndex: state.initialIndex,
        itemCount: state.pageCount,
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
                  onTap: () => logic.jump2Page(index),
                  child: state.mode == 'online' ? _buildThumbnailInOnlineMode(index) : _buildThumbnailInLocalMode(index),
                ),
              ),
              GetBuilder<ReadPageLogic>(
                id: thumbnailsId,
                builder: (logic) {
                  return Text(
                    (index + 1).toString(),
                    style: state.readPageTextStyle().copyWith(
                          fontSize: 9,
                          color: logic.getCurrentIndex() == index ? Get.theme.primaryColorLight : null,
                        ),
                  );
                },
              ).marginOnly(top: 4),
            ],
          ),
        ),
        separatorBuilder: (BuildContext context, int index) => const Divider(indent: 4),
      ),
    );
  }

  Widget _buildThumbnailInOnlineMode(int index) {
    return GetBuilder<ReadPageLogic>(
      id: '$itemId::$index',
      builder: (logic) {
        if (state.thumbnails[index] == null) {
          if (state.parseImageHrefsState == LoadingState.idle) {
            logic.beginToParseImageHref(index);
          }
          return const Center();
        }

        return Center(
          child: EHThumbnail(galleryThumbnail: state.thumbnails[index]!),
        );
      },
    );
  }

  Widget _buildThumbnailInLocalMode(int index) {
    return GetBuilder<GalleryDownloadService>(
      id: '$imageId::${state.gid}',
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
      id: sliderId,
      builder: (logic) {
        return SizedBox(
          width: fullScreenWidth,
          child: Row(
            children: [
              Text(
                (state.readIndexRecord + 1).toString(),
                style: state.readPageTextStyle(),
              ).marginSymmetric(horizontal: 16),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: Slider(
                    min: 1,
                    max: state.pageCount.toDouble(),
                    value: state.readIndexRecord + 1.0,
                    thumbColor: Colors.white,
                    onChanged: logic.handleSlide,
                    onChangeEnd: logic.handleSlideEnd,
                  ),
                ),
              ),
              Text(
                state.pageCount.toString(),
                style: state.readPageTextStyle(),
              ).marginSymmetric(horizontal: 16),
            ],
          ),
        );
      },
    );
  }
}
