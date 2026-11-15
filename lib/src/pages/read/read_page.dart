import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/mixin/scroll_status_listener.dart';
import 'package:jhentai/src/mixin/scroll_status_listener_state.dart';
import 'package:jhentai/src/mixin/window_widget_mixin.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/model/tap_zone_config.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_page/horizontal_page_layout.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/widget/eh_mouse_button_listener.dart';
import 'package:jhentai/src/widget/tap_zone_guide_overlay.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:window_manager/window_manager.dart';

import '../../config/ui_config.dart';
import '../../service/gallery_download/gallery_download_service.dart';
import '../../setting/keyboard_shortcut_setting.dart';
import '../../setting/read_setting.dart';
import '../../utils/route_util.dart';
import '../../utils/screen_size_util.dart';
import '../../widget/eh_image.dart';
import '../../widget/eh_keyboard_listener.dart';
import '../../widget/eh_read_page_stack.dart';
import '../../widget/eh_thumbnail.dart';
import '../../widget/eh_wheel_speed_controller_for_read_page.dart';
import '../../widget/loading_state_indicator.dart';
import 'layout/horizontal_double_column/horizontal_double_column_layout.dart';
import 'layout/vertical_list/vertical_list_layout.dart';

/// Hosts the read page of one gallery, and replaces it with the one of another gallery when user switches to the previous or next
/// gallery, so that the route is kept and there is no page transition.
class ReadPage extends StatefulWidget {
  const ReadPage({super.key});

  @override
  State<ReadPage> createState() => _ReadPageHostState();
}

class _ReadPageHostState extends State<ReadPage> {
  /// Null while switching gallery
  ReadPageInfo? readPageInfo = Get.arguments;

  /// [ReadPageLogic] and layout logics are singletons, so dispose those of the old gallery in one frame, and create new ones in the
  /// next frame.
  void switchGallery(ReadPageInfo newReadPageInfo) {
    setState(() => readPageInfo = null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => readPageInfo = newReadPageInfo);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (readPageInfo == null) {
      return const ColoredBox(color: Colors.black, child: SizedBox.expand());
    }

    return _ReadPageBody(key: ObjectKey(readPageInfo), readPageInfo: readPageInfo!, onSwitchGallery: switchGallery);
  }
}

class _ReadPageBody extends StatefulWidget {
  final ReadPageInfo readPageInfo;
  final ValueChanged<ReadPageInfo> onSwitchGallery;

  const _ReadPageBody({super.key, required this.readPageInfo, required this.onSwitchGallery});

  @override
  State<_ReadPageBody> createState() => _ReadPageBodyState();
}

class _ReadPageBodyState extends State<_ReadPageBody> with ScrollStatusListener, WindowListener, WindowWidgetMixin {
  late final ReadPageLogic logic;
  late final ReadPageState state;
  bool _thumbnailsReady = false;

  @override
  void initState() {
    logic = Get.put<ReadPageLogic>(ReadPageLogic(readPageInfo: widget.readPageInfo));
    logic.switchGalleryHandler = widget.onSwitchGallery;
    state = logic.state;

    super.initState();
  }

  @override
  void dispose() {
    /// Normally [ReadPageLogic] is deleted by GetX when the route is disposed. But the route is kept when switching gallery, delete
    /// it now to make room for the one of the new gallery.
    if (logic.isSwitchingGallery) {
      Get.delete<ReadPageLogic>(force: true);
    }

    super.dispose();
  }

  @override
  ScrollStatusListerState get scrollStatusListerState => state;

  @override
  Brightness? get titleBarBrightness => Brightness.dark;

  @override
  Color? get titleBarColor => Colors.black;

  @override
  double get fullScreenTopPadding => 0;

  @override
  Widget build(BuildContext context) {
    Widget child = AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Obx(
        () => EHMouseButtonListener(
          mouseHandlers: keyboardShortcutSetting.buildMouseHandlerMap(
            onToNext: logic.toNext,
            onToPrev: logic.toPrev,
            onToLeft: logic.toLeft,
            onToRight: logic.toRight,
            onBack: backRoute,
            onToggleMenu: logic.toggleMenu,
            onToggleFirstPageAlone: logic.handleM,
            onToggleFullScreen: toggleFullScreen,
          ),
          child: EHKeyboardListener(
            focusNode: state.focusNode,
            keyHandlers: {
              LogicalKeyboardKey.escape: backRoute,
              ...keyboardShortcutSetting.buildHandlerMap(
                onToNext: logic.toNext,
                onToPrev: logic.toPrev,
                onToLeft: logic.toLeft,
                onToRight: logic.toRight,
                onBack: backRoute,
                onToggleMenu: logic.toggleMenu,
                onToggleFirstPageAlone: logic.handleM,
                onToggleFullScreen: toggleFullScreen,
              ),
            },
            child: DefaultTextStyle(
              style: DefaultTextStyle.of(context).style.copyWith(
                    color: UIConfig.readPageForeGroundColor,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
              child: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    EHReadPageStack(
                      children: [
                        buildGestureRegion(),
                        buildLayout(),
                        GetBuilder<ReadPageLogic>(
                          id: logic.guideOverlayId,
                          builder: (_) => state.showTapZoneGuide
                              ? TapZoneGuideOverlay(onDismiss: logic.dismissTapZoneGuide)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    buildRightBottomInfo(context),
                    buildSwitchGalleryHint(context),
                    buildTopMenu(context),
                    buildBottomMenu(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return GetBuilder<ReadPageLogic>(
      id: logic.pageId,
      builder: (_) {
        if (readSetting.enableImmersiveMode.isFalse) {
          return buildWindow(child: child);
        }
        return child;
      },
    );
  }

  @override
  Widget buildWindow({required Widget child}) {
    return GetPlatform.isWindows
        ? buildWindowsTitle(child)
        : GetPlatform.isLinux
            ? buildLinuxTitle(child)
            : GetPlatform.isMacOS
                ? buildMaxOSTitle(child)
                : child;
  }

  /// Main region to display images
  Widget buildLayout() {
    Widget child = GetBuilder<ReadPageLogic>(
      id: logic.layoutId,
      builder: (_) {
        return LayoutBuilder(
          builder: (context, constraints) {
            logic.clearImageContainerSized();
            state.displayRegionSize = Size(constraints.maxWidth, constraints.maxHeight);

            if (logic.effectiveReadDirection == ReadDirection.top2bottomList) {
              return VerticalListLayout();
            }
            if (logic.isInListReadDirection) {
              return HorizontalListLayout();
            }
            if (logic.isInDoubleColumnReadDirection) {
              return HorizontalDoubleColumnLayout();
            }
            return HorizontalPageLayout();
          },
        );
      },
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        logic.handleScrollNotification(notification);
        return false;
      },
      child: wrapScrollListener(child),
    );
  }

  /// Tell user which gallery will be opened when turning page beyond the first or last page
  Widget buildSwitchGalleryHint(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: max(MediaQuery.of(context).viewPadding.bottom, UIConfig.readPageBottomSpacingHeight) + 56,
      child: IgnorePointer(
        child: GetBuilder<ReadPageLogic>(
          id: logic.switchGalleryHintId,
          builder: (_) {
            SwitchGalleryHint? hint = state.switchGalleryHint;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: hint == null ? const SizedBox.shrink() : _buildSwitchGalleryHintCard(hint),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSwitchGalleryHintCard(SwitchGalleryHint hint) {
    String boundaryText = hint.next ? 'alreadyLastPage'.tr : 'alreadyFirstPage'.tr;
    String actionText = hint.gallery == null
        ? (hint.next ? 'noNextGallery'.tr : 'noPrevGallery'.tr)
        : (hint.next ? 'turnPageAgainToReadNextGallery'.tr : 'turnPageAgainToReadPrevGallery'.tr);

    return Center(
      key: ValueKey('${hint.next}::${hint.gallery?.title}'),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hint.gallery == null ? Icons.block : (hint.next ? Icons.skip_next : Icons.skip_previous),
              color: UIConfig.readPageForeGroundColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$boundaryText · $actionText', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (hint.gallery != null)
                    Text(
                      hint.gallery!.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ).marginOnly(top: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// right-bottom info
  Widget buildRightBottomInfo(BuildContext context) {
    return Positioned(
      bottom: 0,
      right: 0,
      child: Obx(
        () {
          if (readSetting.showStatusInfo.isFalse) {
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

              /// keep the text out of the right system inset, e.g. the vertical status bar of iPhone Duo's inner screen,
              /// except in immersive mode, where the status bar is hidden
              padding: EdgeInsets.only(
                right: readSetting.enableImmersiveMode.isTrue ? 32 : max(32, MediaQuery.paddingOf(context).right + 8),
                bottom: 1,
                top: 3,
                left: 6,
              ),
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
      builder: (_) => Text('${state.readPageInfo.currentImageIndex + 1}/${state.readPageInfo.pageCount}'),
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
    return GetBuilder<ReadPageLogic>(
      id: logic.tapZoneId,
      builder: (_) {
        TapZoneConfig config = readSetting.tapZoneConfig;
        List<int> columnFlex = [
          config.leftColumnWidthRatio,
          config.middleColumnWidthRatio,
          config.rightColumnWidthRatio,
        ];
        List<int> rowFlex = [
          config.topRowHeightRatio,
          config.middleRowHeightRatio,
          config.bottomRowHeightRatio,
        ];
        Widget buildCell(int index) => Expanded(
              flex: columnFlex[index % 3],
              child: GestureDetector(
                onTap: () => logic.handleTapZone(index),
                behavior: HitTestBehavior.opaque,
              ),
            );

        return Column(
          children: [
            for (int row = 0; row < 3; row++)
              Expanded(
                flex: rowFlex[row],
                child: Row(
                  children: [
                    for (int col = 0; col < 3; col++) buildCell(row * 3 + col),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// top menu
  Widget buildTopMenu(BuildContext context) {
    return GetBuilder<ReadPageLogic>(
      id: logic.topMenuId,
      builder: (_) {
        // Slide the whole app bar (leading/title/actions together) in from the
        // top instead of animating its height. Growing the height only animates
        // the middle/trailing slots; the leading is laid out at full toolbar
        // height and pops in place.
        final double menuHeight = UIConfig.appBarHeight + context.mediaQuery.padding.top;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          top: state.isMenuOpen ? 0 : -menuHeight,
          height: menuHeight,
          width: fullScreenWidth,
          child: AppBar(
            backgroundColor: UIConfig.readPageMenuColor,
            title: Text(state.readPageInfo.galleryTitle, style: const TextStyle(color: UIConfig.readPageButtonColor)),
            leading: const BackButton(color: UIConfig.readPageButtonColor),
            actions: [
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
                if (!logic.isInDoubleColumnReadDirection) {
                  return const SizedBox();
                }
                return ElevatedButton(
                  child: Icon(
                    Icons.looks_one,
                    // ElevatedButton M3 default iconSize (18) shrinks a bare child Icon; pin size explicitly
                    size: 24,
                    color: state.displayFirstPageAlone ? UIConfig.readPageActiveButtonColor(context) : UIConfig.readPageButtonColor,
                  ),
                  onPressed: logic.toggleDisplayFirstPageAlone,
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
                  child: Icon(Icons.schedule, size: 24, color: state.autoMode ? UIConfig.readPageActiveButtonColor(context) : UIConfig.readPageButtonColor),
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
              if (readSetting.enableBottomMenu.isFalse)
                ElevatedButton(
                  child: const Icon(Icons.settings, size: 24, color: UIConfig.readPageButtonColor),
                  onPressed: () => logic.openReadSetting(context),
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
        );
      },
    );
  }

  /// bottom menu
  Widget buildBottomMenu(BuildContext context) {
    return GetBuilder<ReadPageLogic>(
      id: logic.bottomMenuId,
      builder: (_) => Obx(
        () {
          if (state.isMenuOpen) {
            _thumbnailsReady = true;
          }
          return AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          bottom: state.isMenuOpen
              ? 0
              : (readSetting.showThumbnails.isTrue ? -UIConfig.readPageBottomThumbnailsRegionHeight : 0) -
                  UIConfig.readPageBottomSliderHeight -
                  (readSetting.enableBottomMenu.isTrue ? UIConfig.readPageBottomActionHeight : 0) -
                  max(MediaQuery.of(context).viewPadding.bottom, UIConfig.readPageBottomSpacingHeight),
          left: 0,
          right: 0,
          child: ColoredBox(
            color: UIConfig.readPageMenuColor,

            /// menu background stays edge-to-edge, while its content avoids the left and right system insets,
            /// except in immersive mode, where the status bar is hidden and the menu takes the full width
            child: SafeArea(
              top: false,
              bottom: false,
              left: readSetting.enableImmersiveMode.isFalse,
              right: readSetting.enableImmersiveMode.isFalse,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (readSetting.showThumbnails.isTrue && _thumbnailsReady)
                    Offstage(
                      offstage: !state.isMenuOpen,
                      child: _buildThumbnails(context),
                    ),
                  _buildSlider(),
                  if (readSetting.enableBottomMenu.isTrue) _buildBottomAction(),
                  SizedBox(height: max(MediaQuery.of(context).viewPadding.bottom, UIConfig.readPageBottomSpacingHeight)),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _buildThumbnails(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: UIConfig.readPageBottomThumbnailsRegionHeight,
      child: Obx(
        () => EHWheelSpeedControllerForReadPage(
          scrollOffsetController: state.thumbnailsScrollOffsetController,
          stopScrollWhenCtrlPressed: false,
          child: ScrollablePositionedList.separated(
            scrollDirection: Axis.horizontal,
            reverse: logic.isInRight2LeftDirection,
            physics: const ClampingScrollPhysics(),
            minCacheExtent: 1 * fullScreenWidth,
            initialScrollIndex: state.readPageInfo.currentImageIndex,
            itemCount: state.readPageInfo.pageCount,
            itemScrollController: state.thumbnailsScrollController,
            itemPositionsListener: state.thumbnailPositionsListener,
            scrollOffsetController: state.thumbnailsScrollOffsetController,
            itemBuilder: (_, index) => GetBuilder<ReadPageLogic>(
              id: logic.thumbnailNoId,
              builder: (_) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  SizedBox(
                    height: UIConfig.readPageThumbnailHeight,
                    width: UIConfig.readPageThumbnailWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => logic.jump2ImageIndex(index),
                      child:
                          state.readPageInfo.mode == ReadMode.online ? _buildThumbnailInOnlineMode(context, index) : _buildThumbnailInLocalMode(context, index),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GetBuilder<ReadPageLogic>(
                    builder: (_) => Center(
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          color: state.readPageInfo.currentImageIndex == index
                              ? UIConfig.readPageBottomCurrentImageHighlightBackgroundColor(context)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (index + 1).toString(),
                          style: TextStyle(
                            fontSize: 9,
                            color: state.readPageInfo.currentImageIndex == index ? UIConfig.readPageBottomCurrentImageHighlightForegroundColor(context) : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
            separatorBuilder: (_, __) => const SizedBox(width: 6),
          ),
        ).enableMouseDrag(withScrollBar: false),
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
      id: '${galleryDownloadService.downloadImageId}::${state.readPageInfo.gid}::$index',
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
            cacheWidth: displayDecodePixels(constraints.maxWidth, context),
            cacheHeight: displayDecodePixels(constraints.maxHeight, context),
            disableAnimation: true,
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
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(logic.isInRight2LeftDirection ? state.readPageInfo.pageCount.toString() : (state.readPageInfo.currentImageIndex + 1).toString())
                .marginOnly(left: 36, right: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeFocus(
                    child: Material(
                      color: Colors.transparent,
                      child: RotatedBox(
                        quarterTurns: logic.isInRight2LeftDirection ? 2 : 0,
                        child: Slider(
                          min: 1,
                          max: state.readPageInfo.pageCount.toDouble(),
                          value: state.readPageInfo.currentImageIndex + 1.0,
                          thumbColor: UIConfig.readPageForeGroundColor,
                          onChanged: logic.handleSlide,
                          onChangeEnd: logic.handleSlideEnd,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(logic.isInRight2LeftDirection ? (state.readPageInfo.currentImageIndex + 1).toString() : state.readPageInfo.pageCount.toString())
                .marginOnly(right: 36, left: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    final ReadDirection effectiveDirection = logic.effectiveReadDirection;

    return SizedBox(
      height: UIConfig.readPageBottomActionHeight,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Material(
            color: Colors.transparent,
            child: PopupMenuButton<ReadDirection>(
              initialValue: effectiveDirection,
              icon: const Icon(Icons.height, color: UIConfig.readPageButtonColor),
              itemBuilder: (_) => ReadDirection.values
                  .map(
                    (e) => PopupMenuItem<ReadDirection>(child: Text(e.name.tr), value: e),
                  )
                  .toList(),
              onSelected: (ReadDirection value) => logic.saveReadDirection(value),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: PopupMenuButton<DeviceDirection>(
              initialValue: readSetting.deviceDirection.value,
              icon: const Icon(Icons.screen_rotation, color: UIConfig.readPageButtonColor),
              itemBuilder: (_) => DeviceDirection.values
                  .map(
                    (e) => PopupMenuItem<DeviceDirection>(child: Text(e.name.tr), value: e),
                  )
                  .toList(),
              onSelected: (DeviceDirection value) {
                readSetting.saveDeviceDirection(value);
                logic.onEffectiveSettingChanged();
              },
            ),
          ),
          GestureDetector(
            child: AbsorbPointer(
              child: Material(
                color: Colors.transparent,
                child: PopupMenuButton(
                  icon: const Icon(Icons.settings, color: UIConfig.readPageButtonColor),
                  itemBuilder: (_) => [],
                ),
              ),
            ),
            onTap: () => logic.openReadSetting(context),
          ),
        ],
      ),
    );
  }
}
