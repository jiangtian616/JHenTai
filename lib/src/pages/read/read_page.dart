import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/mixin/scroll_status_listener.dart';
import 'package:jhentai/src/mixin/scroll_status_listener_state.dart';
import 'package:jhentai/src/mixin/window_widget_mixin.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_page/horizontal_page_layout.dart';
import 'package:jhentai/src/pages/read/read_page_logic.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_mouse_button_listener.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:window_manager/window_manager.dart';

import '../../config/ui_config.dart';
import '../../config/theme_config.dart';
import '../../service/gallery_download_service.dart';
import '../../setting/keyboard_shortcut_setting.dart';
import '../../setting/read_setting.dart';
import '../../utils/route_util.dart';
import '../../utils/screen_size_util.dart';
import '../../widget/eh_image.dart';
import '../../widget/eh_keyboard_listener.dart';
import '../../widget/eh_read_page_stack.dart';
import '../../widget/eh_thumbnail.dart';
import '../../widget/reader_thumbnail_layout.dart';
import '../../widget/eh_wheel_speed_controller_for_read_page.dart';
import '../../widget/reader_floating_translation_ball.dart';
import '../../widget/loading_state_indicator.dart';
import 'layout/horizontal_double_column/horizontal_double_column_layout.dart';
import 'layout/vertical_list/vertical_list_layout.dart';

/// Actions offered by the read-page top-right translate button dropdown.
enum _ImageTranslationMenuAction { start, retranslate, settings, toggleOverlay }

class ReadPage extends StatefulWidget {
  const ReadPage({super.key});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage>
    with ScrollStatusListener, WindowListener, WindowWidgetMixin {
  final ReadPageLogic logic = Get.put<ReadPageLogic>(ReadPageLogic());
  final ReadPageState state = Get.find<ReadPageLogic>().state;

  /// Anchors the image-translation dropdown menu below the top-right button.
  final GlobalKey _imageTranslationMenuKey = GlobalKey();

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
                      children: [buildGestureRegion(), buildLayout()],
                    ),
                    buildRightBottomInfo(context),
                    buildTopMenu(context),
                    buildTranslationProgress(context),
                    buildBottomMenu(context),
                    buildFloatingTranslationBall(context),
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
            state.displayRegionSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );

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

    return wrapScrollListener(child);
  }

  /// right-bottom info
  Widget buildRightBottomInfo(BuildContext context) {
    return Positioned(
      bottom: 0,
      right: 0,
      child: Obx(() {
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.only(
              right: 32,
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
      }),
    );
  }

  Widget _buildPageNoInfo() {
    return GetBuilder<ReadPageLogic>(
      id: logic.pageNoId,
      builder: (_) => Text(
        '${state.readPageInfo.currentImageIndex + 1}/${state.readPageInfo.pageCount}',
      ),
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
          flex: (100 - readSetting.gestureRegionWidthRatio.value) ~/ 2,
          child: GestureDetector(
            onTap: logic.tapLeftRegion,
            behavior: HitTestBehavior.opaque,
          ),
        ),

        /// center region
        Expanded(
          flex: readSetting.gestureRegionWidthRatio.value,
          child: GestureDetector(
            onTap: logic.tapCenterRegion,
            behavior: HitTestBehavior.opaque,
          ),
        ),

        /// right region: toRight
        Expanded(
          flex: (100 - readSetting.gestureRegionWidthRatio.value) ~/ 2,
          child: GestureDetector(
            onTap: logic.tapRightRegion,
            behavior: HitTestBehavior.opaque,
          ),
        ),
      ],
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
        final double menuHeight =
            UIConfig.appBarHeight + context.mediaQuery.padding.top;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          top: state.isMenuOpen ? 0 : -menuHeight,
          height: menuHeight,
          width: fullScreenWidth,
          child: AppBar(
            backgroundColor: UIConfig.readPageMenuColor,
            title: Text(
              state.readPageInfo.galleryTitle,
              style: const TextStyle(color: UIConfig.readPageButtonColor),
            ),
            // The AppBar forces the leading slot to exactly `leadingWidth`
            // (56 by default), so on macOS widen it and inset the back button
            // to clear the traffic-light window buttons.
            leadingWidth: GetPlatform.isMacOS && ThemeConfig.isApple
                ? UIConfig.desktopMacOSTrafficLightLeftInset + kToolbarHeight
                : null,
            leading: GetPlatform.isMacOS && ThemeConfig.isApple
                ? const Padding(
                    padding: EdgeInsets.only(
                      left: UIConfig.desktopMacOSTrafficLightLeftInset,
                    ),
                    child: BackButton(color: UIConfig.readPageButtonColor),
                  )
                : const BackButton(color: UIConfig.readPageButtonColor),
            actions: [
              if (GetPlatform.isDesktop &&
                  state.readPageInfo.gid != null &&
                  (state.readPageInfo.mode == ReadMode.downloaded ||
                      state.readPageInfo.mode == ReadMode.archive) &&
                  state.readPageInfo.useSuperResolution)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConfig.readPageTopMenuActionHPadding,
                  ),
                  child: EHAppleTextButton(
                    child: GetBuilder<SuperResolutionService>(
                      id: '${SuperResolutionService.superResolutionId}::${state.readPageInfo.gid}',
                      builder: (_) => Text(
                        'AI' + logic.getSuperResolutionProgress(),
                        style: TextStyle(
                          fontSize: 18,
                          color: state.useSuperResolution
                              ? UIConfig.readPageActiveButtonColor(context)
                              : UIConfig.readPageButtonColor,
                        ),
                      ),
                    ),
                    onPressed: logic.handleTapSuperResolutionButton,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                ),
              Obx(() {
                if (!logic.isInDoubleColumnReadDirection) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConfig.readPageTopMenuActionHPadding,
                  ),
                  child: EHAppleElevatedButton(
                    child: Icon(
                      Icons.looks_one,
                      // ElevatedButton M3 default iconSize (18) shrinks a bare child Icon; pin size explicitly
                      size: 24,
                      color: state.displayFirstPageAlone
                          ? UIConfig.readPageActiveButtonColor(context)
                          : UIConfig.readPageButtonColor,
                    ),
                    onPressed: logic.toggleDisplayFirstPageAlone,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.all(0),
                      surfaceTintColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                );
              }),
              GetBuilder<ReadPageLogic>(
                id: logic.autoModeId,
                builder: (_) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConfig.readPageTopMenuActionHPadding,
                  ),
                  child: EHAppleElevatedButton(
                    child: Icon(
                      Icons.schedule,
                      size: 24,
                      color: state.autoMode
                          ? UIConfig.readPageActiveButtonColor(context)
                          : UIConfig.readPageButtonColor,
                    ),
                    onPressed: logic.toggleAutoMode,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.all(0),
                      surfaceTintColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                ),
              ),
              GetBuilder<ReadPageLogic>(
                id: logic.translationMenuId,
                builder: (_) {
                  final bool overlayVisible = state.showImageTranslationOverlay;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UIConfig.readPageTopMenuActionHPadding,
                    ),
                    child: Tooltip(
                      message: 'imageTextTranslation'.tr,
                      child: ThemeConfig.isApple
                          ? EHGlassMenu(
                              triggerBuilder: (context, toggle) =>
                                  EHAppleElevatedButton(
                                    key: _imageTranslationMenuKey,
                                    child: const Icon(
                                      Icons.translate,
                                      size: 24,
                                      color: UIConfig.readPageButtonColor,
                                    ),
                                    // GlassMenu's own gesture opens the menu.
                                    onPressed: toggle,
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      padding: const EdgeInsets.all(0),
                                      surfaceTintColor: Colors.transparent,
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      minimumSize: const Size(40, 40),
                                    ),
                                  ),
                              items: [
                                GlassMenuItem(
                                  title: 'imageTranslationStart'.tr,
                                  icon: const Icon(Icons.play_arrow),
                                  onTap: () =>
                                      _handleImageTranslationMenuAction(
                                        context,
                                        _ImageTranslationMenuAction.start,
                                      ),
                                ),
                                GlassMenuItem(
                                  title: 'imageTranslationRetranslate'.tr,
                                  icon: const Icon(Icons.refresh),
                                  onTap: () =>
                                      _handleImageTranslationMenuAction(
                                        context,
                                        _ImageTranslationMenuAction.retranslate,
                                      ),
                                ),
                                GlassMenuItem(
                                  title: 'imageTranslationSettings'.tr,
                                  icon: const Icon(Icons.settings),
                                  onTap: () =>
                                      _handleImageTranslationMenuAction(
                                        context,
                                        _ImageTranslationMenuAction.settings,
                                      ),
                                ),
                                GlassMenuItem(
                                  title:
                                      (overlayVisible
                                              ? 'imageTranslationHide'
                                              : 'imageTranslationShow')
                                          .tr,
                                  icon: Icon(
                                    overlayVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onTap: () =>
                                      _handleImageTranslationMenuAction(
                                        context,
                                        _ImageTranslationMenuAction
                                            .toggleOverlay,
                                      ),
                                ),
                              ],
                            )
                          : EHAppleElevatedButton(
                              key: _imageTranslationMenuKey,
                              child: const Icon(
                                Icons.translate,
                                size: 24,
                                color: UIConfig.readPageButtonColor,
                              ),
                              onPressed: () =>
                                  _showImageTranslationMenu(context),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding: const EdgeInsets.all(0),
                                surfaceTintColor: Colors.transparent,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                minimumSize: const Size(40, 40),
                              ),
                            ),
                    ),
                  );
                },
              ),
              if (readSetting.enableBottomMenu.isFalse)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConfig.readPageTopMenuActionHPadding,
                  ),
                  child: EHAppleElevatedButton(
                    child: const Icon(
                      Icons.settings,
                      size: 24,
                      color: UIConfig.readPageButtonColor,
                    ),
                    onPressed: () => logic.openReadSetting(context),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.all(0),
                      surfaceTintColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Single translation entry point: expands a small dropdown menu anchored
  /// under the top-right translate button (same pattern as the settings-page
  /// dropdowns). Rendered by the active theme's popup menu styling — with the
  /// Apple visual style enabled the menu matches the settings-page dropdowns
  /// (solid gray surface, 10dp radius). Uses the root navigator so the menu is
  /// not misplaced when the read page sits in a nested Navigator (desktop
  /// detail panel).
  Future<void> _showImageTranslationMenu(BuildContext context) async {
    final RenderBox buttonBox =
        _imageTranslationMenuKey.currentContext!.findRenderObject()!
            as RenderBox;
    final Rect buttonRect =
        buttonBox.localToGlobal(Offset.zero) & buttonBox.size;
    final bool overlayVisible = state.showImageTranslationOverlay;

    final _ImageTranslationMenuAction? selected =
        await showMenu<_ImageTranslationMenuAction>(
          context: context,
          useRootNavigator: true,
          position: RelativeRect.fromRect(
            buttonRect,
            Offset.zero & MediaQuery.sizeOf(context),
          ),
          items: [
            _translationMenuItem(
              _ImageTranslationMenuAction.start,
              Icons.play_arrow,
              'imageTranslationStart'.tr,
            ),
            _translationMenuItem(
              _ImageTranslationMenuAction.retranslate,
              Icons.refresh,
              'imageTranslationRetranslate'.tr,
            ),
            _translationMenuItem(
              _ImageTranslationMenuAction.settings,
              Icons.settings,
              'imageTranslationSettings'.tr,
            ),
            _translationMenuItem(
              _ImageTranslationMenuAction.toggleOverlay,
              overlayVisible ? Icons.visibility_off : Icons.visibility,
              overlayVisible
                  ? 'imageTranslationHide'.tr
                  : 'imageTranslationShow'.tr,
            ),
          ],
        );
    if (selected == null) {
      return;
    }
    _handleImageTranslationMenuAction(context, selected);
  }

  void _handleImageTranslationMenuAction(
    BuildContext context,
    _ImageTranslationMenuAction action,
  ) {
    switch (action) {
      case _ImageTranslationMenuAction.start:
        logic.startImageTranslation(context);
        break;
      case _ImageTranslationMenuAction.retranslate:
        logic.retranslateCurrentImage(context);
        break;
      case _ImageTranslationMenuAction.settings:
        logic.openImageTranslationConfig(context);
        break;
      case _ImageTranslationMenuAction.toggleOverlay:
        logic.toggleImageTranslationOverlay();
        break;
    }
  }

  PopupMenuItem<_ImageTranslationMenuAction> _translationMenuItem(
    _ImageTranslationMenuAction action,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  /// Floating progress banner shown while batch translation runs.
  Widget buildTranslationProgress(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 0,
      right: 0,
      child: Center(
        child: GetBuilder<ImageTranslationService>(
          id: ImageTranslationService.batchProgressId,
          builder: (_) {
            if (!imageTranslationService.isBatchTranslating) {
              return const SizedBox.shrink();
            }
            return Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: ThemeConfig.isApple
                          ? GlassProgressIndicator.circular(
                              strokeWidth: 2,
                              color: Colors.white,
                            )
                          : const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'translationProgress'.trParams({
                        'current': '${imageTranslationService.batchCompleted}',
                        'total': '${imageTranslationService.batchTotal}',
                        'stage': _translationStageLabel(
                          imageTranslationService.currentStage,
                        ),
                      }),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: imageTranslationService.cancelBatch,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildFloatingTranslationBall(BuildContext context) {
    if (GetPlatform.isDesktop) return const SizedBox.shrink();
    return GetBuilder<ImageTranslationService>(
      id: ImageTranslationService.batchProgressId,
      builder: (_) => ReaderFloatingTranslationBall(
        isTranslating: imageTranslationService.isBatchTranslating,
        positionStore: logic.readerFloatingBallPositionStore,
        onTap: () => logic.toggleFloatingTranslation(context),
      ),
    );
  }

  String _translationStageLabel(ImageTranslationStage stage) {
    switch (stage) {
      case ImageTranslationStage.idle:
        return 'translationStageIdle'.tr;
      case ImageTranslationStage.downloading:
        return 'translationStageIdle'.tr;
      case ImageTranslationStage.recognizing:
        return 'translationStageRecognizing'.tr;
      case ImageTranslationStage.translating:
        return 'translationStageTranslating'.tr;
      case ImageTranslationStage.masking:
        return 'translationStageMasking'.tr;
      case ImageTranslationStage.embedding:
        return 'translationStageEmbedding'.tr;
      case ImageTranslationStage.done:
        return 'translationStageDone'.tr;
    }
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
              : (readSetting.showThumbnails.isTrue
                        ? -UIConfig.readPageBottomThumbnailsRegionHeight
                        : 0) -
                    UIConfig.readPageBottomSliderHeight -
                    (readSetting.enableBottomMenu.isTrue
                        ? UIConfig.readPageBottomActionHeight
                        : 0) -
                    max(
                      MediaQuery.of(context).viewPadding.bottom,
                      UIConfig.readPageBottomSpacingHeight,
                    ),
          child: ColoredBox(
            color: UIConfig.readPageMenuColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (readSetting.showThumbnails.isTrue)
                  Offstage(
                    offstage: !state.isMenuOpen,
                    child: _buildThumbnails(context),
                  ),
                _buildSlider(),
                if (readSetting.enableBottomMenu.isTrue) _buildBottomAction(),
                SizedBox(
                  height: max(
                    MediaQuery.of(context).viewPadding.bottom,
                    UIConfig.readPageBottomSpacingHeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnails(BuildContext context) {
    return SizedBox(
      width: fullScreenWidth,
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
            initialScrollIndex: state.readPageInfo.initialIndex,
            itemCount: state.readPageInfo.pageCount,
            itemScrollController: state.thumbnailsScrollController,
            itemPositionsListener: state.thumbnailPositionsListener,
            scrollOffsetController: state.thumbnailsScrollOffsetController,
            itemBuilder: (_, index) => GetBuilder<ReadPageLogic>(
              id: logic.thumbnailItemId(index),
              builder: (_) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  ReaderThumbnailFrame(
                    height: UIConfig.readPageThumbnailHeight,
                    imageWidth: _thumbnailImageWidth(index),
                    imageHeight: _thumbnailImageHeight(index),
                    image: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => logic.jump2ImageIndex(index),
                      child: state.readPageInfo.mode == ReadMode.online
                          ? _buildThumbnailInOnlineMode(context, index)
                          : _buildThumbnailInLocalMode(context, index),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GetBuilder<ReadPageLogic>(
                    builder: (_) => Center(
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          color: state.readPageInfo.currentImageIndex == index
                              ? UIConfig.readPageBottomCurrentImageHighlightBackgroundColor(
                                  context,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (index + 1).toString(),
                          style: TextStyle(
                            fontSize: 9,
                            color: state.readPageInfo.currentImageIndex == index
                                ? UIConfig.readPageBottomCurrentImageHighlightForegroundColor(
                                    context,
                                  )
                                : null,
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

  double? _thumbnailImageWidth(int index) {
    if (state.readPageInfo.mode == ReadMode.online) {
      return state.thumbnails[index]?.thumbWidth;
    }
    return state.images[index]?.width;
  }

  double? _thumbnailImageHeight(int index) {
    if (state.readPageInfo.mode == ReadMode.online) {
      return state.thumbnails[index]?.thumbHeight;
    }
    return state.images[index]?.height;
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
            maxBytes: 1024 * 50,
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
        width: fullScreenWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              logic.isInRight2LeftDirection
                  ? state.readPageInfo.pageCount.toString()
                  : (state.readPageInfo.currentImageIndex + 1).toString(),
            ).marginOnly(left: 36, right: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeFocus(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool reverse = logic.isInRight2LeftDirection;
                        final double usableWidth = max(
                          1,
                          constraints.maxWidth - 12,
                        );
                        return Stack(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: RotatedBox(
                                quarterTurns: reverse ? 2 : 0,
                                child: EHAppleSlider(
                                  min: 1,
                                  max: state.readPageInfo.pageCount.toDouble(),
                                  value:
                                      state.readPageInfo.currentImageIndex +
                                      1.0,
                                  thumbColor: UIConfig.readPageForeGroundColor,
                                  onChanged: logic.handleSlide,
                                  onChangeEnd: logic.handleSlideEnd,
                                ),
                              ),
                            ),
                            for (final bookmark in state.readerBookmarks)
                              Positioned(
                                left:
                                    (reverse
                                        ? 1 -
                                              bookmark.pageIndex /
                                                  max(
                                                    1,
                                                    state
                                                            .readPageInfo
                                                            .pageCount -
                                                        1,
                                                  )
                                        : bookmark.pageIndex /
                                              max(
                                                1,
                                                state.readPageInfo.pageCount -
                                                    1,
                                              )) *
                                    usableWidth,
                                top: 3,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      logic.jumpToBookmark(bookmark.pageIndex),
                                  child: const SizedBox(
                                    width: 12,
                                    height: 18,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          shape: BoxShape.circle,
                                        ),
                                        child: SizedBox(width: 6, height: 6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Text(
              logic.isInRight2LeftDirection
                  ? (state.readPageInfo.currentImageIndex + 1).toString()
                  : state.readPageInfo.pageCount.toString(),
            ).marginOnly(right: 36, left: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    final ReadDirection effectiveDirection = logic.effectiveReadDirection;

    return SizedBox(
      height: UIConfig.readPageBottomActionHeight,
      width: fullScreenWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GetBuilder<ReadPageLogic>(
            id: logic.readerBookmarkId,
            builder: (_) => IconButton(
              tooltip:
                  logic.isPageBookmarked(state.readPageInfo.currentImageIndex)
                  ? 'Remove bookmark'
                  : 'Add bookmark',
              icon: Icon(
                logic.isPageBookmarked(state.readPageInfo.currentImageIndex)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: UIConfig.readPageButtonColor,
              ),
              onPressed: logic.toggleCurrentPageBookmark,
            ),
          ),
          ThemeConfig.isApple
              ? EHGlassMenu(
                  trigger: const Icon(
                    Icons.height,
                    color: UIConfig.readPageButtonColor,
                  ),
                  items: [
                    for (final e in ReadDirection.values)
                      GlassMenuItem(
                        title: e.name.tr,
                        onTap: () => logic.saveReadDirection(e),
                      ),
                  ],
                )
              : Material(
                  color: Colors.transparent,
                  child: PopupMenuButton<ReadDirection>(
                    initialValue: effectiveDirection,
                    icon: const Icon(
                      Icons.height,
                      color: UIConfig.readPageButtonColor,
                    ),
                    itemBuilder: (_) => ReadDirection.values
                        .map(
                          (e) => PopupMenuItem<ReadDirection>(
                            child: Text(e.name.tr),
                            value: e,
                          ),
                        )
                        .toList(),
                    onSelected: (ReadDirection value) =>
                        logic.saveReadDirection(value),
                  ),
                ),
          ThemeConfig.isApple
              ? EHGlassMenu(
                  trigger: const Icon(
                    Icons.screen_rotation,
                    color: UIConfig.readPageButtonColor,
                  ),
                  items: [
                    for (final e in DeviceDirection.values)
                      GlassMenuItem(
                        title: e.name.tr,
                        onTap: () {
                          readSetting.saveDeviceDirection(e);
                          logic.onEffectiveSettingChanged();
                        },
                      ),
                  ],
                )
              : Material(
                  color: Colors.transparent,
                  child: PopupMenuButton<DeviceDirection>(
                    initialValue: readSetting.deviceDirection.value,
                    icon: const Icon(
                      Icons.screen_rotation,
                      color: UIConfig.readPageButtonColor,
                    ),
                    itemBuilder: (_) => DeviceDirection.values
                        .map(
                          (e) => PopupMenuItem<DeviceDirection>(
                            child: Text(e.name.tr),
                            value: e,
                          ),
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
              child: ThemeConfig.isApple
                  ? EHGlassMenu(
                      trigger: const Icon(
                        Icons.settings,
                        color: UIConfig.readPageButtonColor,
                      ),
                      items: [],
                    )
                  : Material(
                      color: Colors.transparent,
                      child: PopupMenuButton(
                        icon: const Icon(
                          Icons.settings,
                          color: UIConfig.readPageButtonColor,
                        ),
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
