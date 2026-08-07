import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/pages/setting/keyboard_shortcuts/setting_keyboard_shortcuts_page.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../../../routes/routes.dart';
import '../../../service/log.dart';
import '../../../utils/route_util.dart';
import '../../../utils/text_input_formatter.dart';
import '../../../utils/toast_util.dart';
import '../../../utils/app_icons.dart';
import '../../../widget/eh_apple_settings_list_view.dart';
import '../../../widget/eh_apple_controls.dart';
import '../../../widget/eh_apple_expandable_switch_list_tile.dart';
import '../../../widget/eh_codex_style_dropdown.dart';
import '../../home_page.dart';

class SettingReadPage extends StatelessWidget {
  final TextEditingController imageRegionWidthRatioController =
      TextEditingController(
          text: readSetting.imageRegionWidthRatio.value.toString());
  final TextEditingController portraitImageRegionWidthRatioController =
      TextEditingController(
          text: readSetting.portraitImageRegionWidthRatio.value.toString());
  final TextEditingController landscapeImageRegionWidthRatioController =
      TextEditingController(
          text: readSetting.landscapeImageRegionWidthRatio.value.toString());
  final TextEditingController gestureRegionWidthRatioController =
      TextEditingController(
          text: readSetting.gestureRegionWidthRatio.value.toString());
  final TextEditingController imageMaxKilobytesController =
      TextEditingController(
          text: readSetting.maxImageKilobyte.value.toString());

  SettingReadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('readSetting'.tr)),
      body: Obx(
        () => EHAppleSettingsListView(
          safeArea: true,
          groups: [
            EHAppleSettingsGroup(
              children: [
                if (GetPlatform.isMobile || GetPlatform.isWindows)
                  _buildEnableImmersiveMode().center(),
                _buildKeepScreenAwake().center(),
                if (GetPlatform.isMobile)
                  EHAppleExpandableSwitchListTile(
                    title: Text('enableCustomReadBrightness'.tr),
                    value: readSetting.enableCustomReadBrightness.value,
                    onChanged: readSetting.saveEnableCustomReadBrightness,
                    children: [_buildCustomReadBrightness()],
                  ).center(),
                _buildShowThumbnails().center(),
                _buildShowScrollBar().center(),
                _buildShowStatusInfo().center(),
                if (GetPlatform.isMobile)
                  _buildEnablePageTurnByVolumeKeys().center(),
                _buildEnablePageTurnAnime().center(),
                _buildEnableDoubleTapToScaleUp().center(),
                _buildEnableTapDragToScaleUp().center(),
                _buildEnableBottomMenu().center(),
                _buildReverseTurnPageDirection().center(),
                _buildDisableTurnPageOnTap().center(),
                EHAppleExpandableSwitchListTile(
                  title: Text('enableImageMaxKilobytes'.tr),
                  value: readSetting.enableMaxImageKilobyte.value,
                  onChanged: readSetting.saveEnableMaxImageKilobyte,
                  children: [_buildImageMaxKilobytes(context)],
                ).center(),
                _buildGestureRegionWidthRatio(context).center(),
                if (GetPlatform.isDesktop)
                  EHAppleExpandableSwitchListTile(
                    title: Text('useThirdPartyViewer'.tr),
                    value: readSetting.useThirdPartyViewer.value,
                    onChanged: readSetting.saveUseThirdPartyViewer,
                    children: [_buildThirdPartyViewerPath()],
                  ).center(),
                if (GetPlatform.isDesktop)
                  _buildKeyboardShortcuts(context).center(),
                if (GetPlatform.isMobile) _buildDeviceDirection().center(),
                if (GetPlatform.isMobile)
                  EHAppleExpandableSwitchListTile(
                    title: Text('enableOrientationSpecificReadDirection'.tr),
                    subtitle:
                        Text('enableOrientationSpecificReadDirectionHint'.tr),
                    value:
                        readSetting.enableOrientationSpecificReadDirection.value,
                    onChanged:
                        readSetting.saveEnableOrientationSpecificReadDirection,
                    children: [
                      _buildPortraitReadDirection(),
                      _buildLandscapeReadDirection(),
                      if (readSetting.portraitReadDirection.value ==
                          ReadDirection.top2bottomList)
                        _buildPortraitImageRegionWidthRatio(context),
                      if (readSetting.landscapeReadDirection.value ==
                          ReadDirection.top2bottomList)
                        _buildLandscapeImageRegionWidthRatio(context),
                    ],
                  ).center(),
                if (!GetPlatform.isMobile ||
                    readSetting.enableOrientationSpecificReadDirection.isFalse)
                  _buildReadDirection().center(),
                if (GetPlatform.isMobile &&
                        readSetting
                            .enableOrientationSpecificReadDirection.isTrue
                    ? (readSetting.portraitReadDirection.value ==
                            ReadDirection.top2bottomList ||
                        readSetting.landscapeReadDirection.value ==
                            ReadDirection.top2bottomList)
                    : readSetting.readDirection.value ==
                        ReadDirection.top2bottomList)
                  _buildNotchOptimization().center(),
                if (!GetPlatform.isMobile ||
                    readSetting.enableOrientationSpecificReadDirection.isFalse)
                  if (readSetting.readDirection.value ==
                      ReadDirection.top2bottomList)
                    _buildImageRegionWidthRatio(context).center(),
                if (readSetting.isInListReadDirection)
                  _buildPreloadDistanceInOnlineMode(context)
                      .fadeIn(const Key('preloadDistanceInOnlineMode'))
                      .center(),
                if (readSetting.isInListReadDirection)
                  _buildPreloadDistanceInLocalMode(context)
                      .fadeIn(const Key('preloadDistanceInLocalMode'))
                      .center(),
                if (!readSetting.isEveryInListReadDirection)
                  _buildPreloadPageCount()
                      .fadeIn(const Key('preloadPageCount'))
                      .center(),
                if (!readSetting.isEveryInListReadDirection)
                  _buildPreloadPageCountInLocalMode()
                      .fadeIn(const Key('preloadPageCountInLocalMode'))
                      .center(),
                _buildFailedImageRetryScope().center(),
                if (GetPlatform.isMobile &&
                    readSetting
                        .enableOrientationSpecificReadDirection.isTrue) ...[
                  if (readSetting.portraitReadDirection.value ==
                          ReadDirection.left2rightDoubleColumn ||
                      readSetting.portraitReadDirection.value ==
                          ReadDirection.right2leftDoubleColumn)
                    _buildPortraitDisplayFirstPageAlone()
                        .fadeIn(const Key('portraitDisplayFirstPageAlone'))
                        .center(),
                  if (readSetting.landscapeReadDirection.value ==
                          ReadDirection.left2rightDoubleColumn ||
                      readSetting.landscapeReadDirection.value ==
                          ReadDirection.right2leftDoubleColumn)
                    _buildLandscapeDisplayFirstPageAlone()
                        .fadeIn(const Key('landscapeDisplayFirstPageAlone'))
                        .center(),
                ],
                if (!GetPlatform.isMobile ||
                    readSetting.enableOrientationSpecificReadDirection.isFalse)
                  if (readSetting.isInDoubleColumnReadDirection)
                    _buildDisplayFirstPageAlone()
                        .fadeIn(const Key('displayFirstPageAloneGlobally'))
                        .center(),
                if (readSetting.isInListReadDirection)
                  _buildAutoModeStyle()
                      .fadeIn(const Key('autoModeStyle'))
                      .center(),
                if (readSetting.isInListReadDirection)
                  _buildTurnPageMode()
                      .fadeIn(const Key('turnPageMode'))
                      .center(),
                _buildImageSpace().center(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableImmersiveMode() {
    return EHAppleSwitchListTile(
      title: Text('enableImmersiveMode'.tr),
      subtitle: GetPlatform.isMobile
          ? Text('enableImmersiveHint'.tr)
          : Text('enableImmersiveHint4Windows'.tr),
      value: readSetting.enableImmersiveMode.value,
      onChanged: readSetting.saveEnableImmersiveMode,
    );
  }

  Widget _buildKeepScreenAwake() {
    return EHAppleSwitchListTile(
      title: Text('keepScreenAwakeWhenReading'.tr),
      value: readSetting.keepScreenAwakeWhenReading.value,
      onChanged: readSetting.saveKeepScreenAwakeWhenReading,
    );
  }

  Widget _buildShowThumbnails() {
    return EHAppleSwitchListTile(
      title: Text('showThumbnails'.tr),
      value: readSetting.showThumbnails.value,
      onChanged: readSetting.saveShowThumbnails,
    );
  }

  Widget _buildShowScrollBar() {
    return EHAppleSwitchListTile(
      title: Text('showScrollBar'.tr),
      value: readSetting.showScrollBar.value,
      onChanged: readSetting.saveShowScrollBar,
    );
  }

  Widget _buildCustomReadBrightness() {
    return Row(
      children: [
        const SizedBox(width: 16),
        const Icon(Icons.brightness_6),
        const SizedBox(width: 16),
        Text(readSetting.customBrightness.value.toString()),
        Expanded(
          child: EHAppleSlider(
            value: readSetting.customBrightness.value.toDouble(),
            onChanged: (double value) =>
                readSetting.saveCustomBrightness(value.toInt()),
            min: 0,
            max: 100,
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildImageSpace() {
    return ListTile(
      title: Text('spaceBetweenImages'.tr),
      trailing: EHCodexStyleDropdown<int>(
        value: readSetting.imageSpace.value,
        elevation: 4,
        onChanged: (int? newValue) {
          readSetting.saveImageSpace(newValue!);
        },
        items: const [
          DropdownMenuItem(
            child: Text('0'),
            value: 0,
          ),
          DropdownMenuItem(
            child: Text('2'),
            value: 2,
          ),
          DropdownMenuItem(
            child: Text('4'),
            value: 4,
          ),
          DropdownMenuItem(
            child: Text('6'),
            value: 6,
          ),
          DropdownMenuItem(
            child: Text('8'),
            value: 7,
          ),
          DropdownMenuItem(
            child: Text('10'),
            value: 10,
          ),
        ],
      ),
    ).marginOnly(right: 12);
  }

  Widget _buildShowStatusInfo() {
    return EHAppleSwitchListTile(
      title: Text('showStatusInfo'.tr),
      value: readSetting.showStatusInfo.value,
      onChanged: readSetting.saveShowStatusInfo,
    );
  }

  Widget _buildEnablePageTurnByVolumeKeys() {
    return EHAppleSwitchListTile(
      title: Text('enablePageTurnByVolumeKeys'.tr),
      subtitle:
          GetPlatform.isIOS ? Text('enablePageTurnByVolumeKeysHint'.tr) : null,
      value: readSetting.enablePageTurnByVolumeKeys.value,
      onChanged: readSetting.saveEnablePageTurnByVolumeKeys,
    );
  }

  Widget _buildEnablePageTurnAnime() {
    return EHAppleSwitchListTile(
      title: Text('enablePageTurnAnime'.tr),
      value: readSetting.enablePageTurnAnime.value,
      onChanged: readSetting.saveEnablePageTurnAnime,
    );
  }

  Widget _buildEnableDoubleTapToScaleUp() {
    return EHAppleSwitchListTile(
      title: Text('enableDoubleTapToScaleUp'.tr),
      value: readSetting.enableDoubleTapToScaleUp.value,
      onChanged: readSetting.saveEnableDoubleTapToScaleUp,
    );
  }

  Widget _buildEnableTapDragToScaleUp() {
    return EHAppleSwitchListTile(
      title: Text('enableTapDragToScaleUp'.tr),
      value: readSetting.enableTapDragToScaleUp.value,
      onChanged: readSetting.saveEnableTapDragToScaleUp,
    );
  }

  Widget _buildEnableBottomMenu() {
    return EHAppleSwitchListTile(
      title: Text('enableBottomMenu'.tr),
      value: readSetting.enableBottomMenu.value,
      onChanged: readSetting.saveEnableBottomMenu,
    );
  }

  Widget _buildReverseTurnPageDirection() {
    return EHAppleSwitchListTile(
      title: Text('reverseTurnPageDirection'.tr),
      value: readSetting.reverseTurnPageDirection.value,
      onChanged: readSetting.saveReverseTurnPageDirection,
    );
  }

  Widget _buildDisableTurnPageOnTap() {
    return EHAppleSwitchListTile(
      title: Text('disablePageTurningOnTap'.tr),
      value: readSetting.disablePageTurningOnTap.value,
      onChanged: readSetting.saveDisablePageTurningOnTap,
    );
  }

  Widget _buildImageMaxKilobytes(BuildContext context) {
    return ListTile(
      title: Text('imageMaxKilobytes'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: EHAppleTextField(
              controller: imageMaxKilobytesController,
              decoration: const InputDecoration(
                  isDense: true, labelStyle: TextStyle(fontSize: 12)),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                IntRangeTextInputFormatter(minValue: 1)
              ],
            ),
          ),
          Text('KB',
              style: UIConfig.settingPageListTileTrailingTextStyle(context)),
          IconButton(
            onPressed: () {
              int? value = int.tryParse(imageMaxKilobytesController.value.text);
              if (value == null) {
                return;
              }
              readSetting.saveMaxImageKilobyte(value);
              toast('saveSuccess'.tr);
            },
            icon: Icon(Icons.check,
                color: UIConfig.resumePauseButtonColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDirection() {
    return ListTile(
      title: Text('deviceOrientation'.tr),
      trailing: EHCodexStyleDropdown<DeviceDirection>(
        value: readSetting.deviceDirection.value,
        elevation: 4,
        onChanged: (DeviceDirection? newValue) =>
            readSetting.saveDeviceDirection(newValue!),
        items: [
          DropdownMenuItem(
              child: Text('followSystem'.tr),
              value: DeviceDirection.followSystem),
          DropdownMenuItem(
              child: Text('landscape'.tr), value: DeviceDirection.landscape),
          DropdownMenuItem(
              child: Text('portrait'.tr), value: DeviceDirection.portrait),
        ],
      ).marginOnly(right: 12),
    );
  }

  Widget _buildPortraitReadDirection() {
    return ListTile(
      title: Text('portraitReadDirection'.tr),
      trailing: EHCodexStyleDropdown<ReadDirection>(
        value: readSetting.portraitReadDirection.value,
        elevation: 4,
        onChanged: (ReadDirection? newValue) =>
            readSetting.savePortraitReadDirection(newValue!),
        items: ReadDirection.values
            .map((e) => DropdownMenuItem(child: Text(e.name.tr), value: e))
            .toList(),
      ).marginOnly(right: 12),
    );
  }

  Widget _buildLandscapeReadDirection() {
    return ListTile(
      title: Text('landscapeReadDirection'.tr),
      trailing: EHCodexStyleDropdown<ReadDirection>(
        value: readSetting.landscapeReadDirection.value,
        elevation: 4,
        onChanged: (ReadDirection? newValue) =>
            readSetting.saveLandscapeReadDirection(newValue!),
        items: ReadDirection.values
            .map((e) => DropdownMenuItem(child: Text(e.name.tr), value: e))
            .toList(),
      ).marginOnly(right: 12),
    );
  }

  Widget _buildReadDirection() {
    return ListTile(
      title: Text('readDirection'.tr),
      trailing: EHCodexStyleDropdown<ReadDirection>(
        value: readSetting.readDirection.value,
        elevation: 4,
        onChanged: (ReadDirection? newValue) =>
            readSetting.saveReadDirection(newValue!),
        items: ReadDirection.values
            .map((e) => DropdownMenuItem(child: Text(e.name.tr), value: e))
            .toList(),
      ).marginOnly(right: 12),
    );
  }

  Widget _buildFailedImageRetryScope() {
    return ListTile(
      title: Text('failedImageRetryScope'.tr),
      subtitle: Text('failedImageRetryScopeHint'.tr),
      trailing: EHCodexStyleDropdown<FailedImageRetryScope>(
        value: readSetting.failedImageRetryScope.value,
        elevation: 4,
        onChanged: (FailedImageRetryScope? newValue) =>
            readSetting.saveFailedImageRetryScope(newValue!),
        items: FailedImageRetryScope.values
            .map((e) => DropdownMenuItem(child: Text(e.name.tr), value: e))
            .toList(),
      ).marginOnly(right: 12),
    );
  }

  Widget _buildNotchOptimization() {
    return ListTile(
      title: Text('notchOptimization'.tr),
      subtitle: Text('notchOptimizationHint'.tr),
      trailing: EHAppleSwitch(
          value: readSetting.notchOptimization.value,
          onChanged: readSetting.saveNotchOptimization),
    );
  }

  Widget _buildImageRegionWidthRatio(BuildContext context) {
    return ListTile(
      title: Text('imageRegionWidthRatio'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: EHAppleTextField(
              controller: imageRegionWidthRatioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  isDense: true, labelStyle: TextStyle(fontSize: 12)),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                IntRangeTextInputFormatter(minValue: 1, maxValue: 100),
              ],
              onSubmitted: (_) {
                _saveImageRegionWidthRatio();
              },
            ),
          ),
          const Text('%'),
          IconButton(
            onPressed: _saveImageRegionWidthRatio,
            icon: Icon(Icons.check,
                color: UIConfig.resumePauseButtonColor(context)),
          ),
        ],
      ),
    ).marginOnly(right: 12);
  }

  void _saveImageRegionWidthRatio() {
    int? value = int.tryParse(imageRegionWidthRatioController.value.text);
    if (value == null) {
      return;
    }
    readSetting.saveImageRegionWidthRatio(value);
    toast('saveSuccess'.tr);
  }

  Widget _buildPortraitImageRegionWidthRatio(BuildContext context) {
    return ListTile(
      title: Text('portraitImageRegionWidthRatio'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: EHAppleTextField(
              controller: portraitImageRegionWidthRatioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  isDense: true, labelStyle: TextStyle(fontSize: 12)),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                IntRangeTextInputFormatter(minValue: 1, maxValue: 100),
              ],
              onSubmitted: (_) => _savePortraitImageRegionWidthRatio(),
            ),
          ),
          const Text('%'),
          IconButton(
            onPressed: _savePortraitImageRegionWidthRatio,
            icon: Icon(Icons.check,
                color: UIConfig.resumePauseButtonColor(context)),
          ),
        ],
      ),
    ).marginOnly(right: 12);
  }

  void _savePortraitImageRegionWidthRatio() {
    int? value =
        int.tryParse(portraitImageRegionWidthRatioController.value.text);
    if (value == null) {
      return;
    }
    readSetting.savePortraitImageRegionWidthRatio(value);
    toast('saveSuccess'.tr);
  }

  Widget _buildLandscapeImageRegionWidthRatio(BuildContext context) {
    return ListTile(
      title: Text('landscapeImageRegionWidthRatio'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: EHAppleTextField(
              controller: landscapeImageRegionWidthRatioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  isDense: true, labelStyle: TextStyle(fontSize: 12)),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                IntRangeTextInputFormatter(minValue: 1, maxValue: 100),
              ],
              onSubmitted: (_) => _saveLandscapeImageRegionWidthRatio(),
            ),
          ),
          const Text('%'),
          IconButton(
            onPressed: _saveLandscapeImageRegionWidthRatio,
            icon: Icon(Icons.check,
                color: UIConfig.resumePauseButtonColor(context)),
          ),
        ],
      ),
    ).marginOnly(right: 12);
  }

  void _saveLandscapeImageRegionWidthRatio() {
    int? value =
        int.tryParse(landscapeImageRegionWidthRatioController.value.text);
    if (value == null) {
      return;
    }
    readSetting.saveLandscapeImageRegionWidthRatio(value);
    toast('saveSuccess'.tr);
  }

  Widget _buildGestureRegionWidthRatio(BuildContext context) {
    return ListTile(
      title: Text('gestureRegionWidthRatio'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: EHAppleTextField(
              controller: gestureRegionWidthRatioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  isDense: true, labelStyle: TextStyle(fontSize: 12)),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                IntRangeTextInputFormatter(minValue: 0, maxValue: 100),
              ],
              onSubmitted: (_) {
                _saveGestureRegionWidthRatio();
              },
            ),
          ),
          const Text('%'),
          IconButton(
            onPressed: _saveGestureRegionWidthRatio,
            icon: Icon(Icons.check,
                color: UIConfig.resumePauseButtonColor(context)),
          ),
        ],
      ),
    ).marginOnly(right: 12);
  }

  void _saveGestureRegionWidthRatio() {
    int? value = int.tryParse(gestureRegionWidthRatioController.value.text);
    if (value == null) {
      return;
    }

    if (value <= 0) {
      value = 1;
    }
    if (value >= 100) {
      value = 99;
    }

    readSetting.saveGestureRegionWidthRatio(value);
    toast('saveSuccess'.tr);
  }

  Widget _buildThirdPartyViewerPath() {
    return ListTile(
      title: Text('thirdPartyViewerPath'.tr),
      subtitle: Text(readSetting.thirdPartyViewerPath.value ?? ''),
      trailing: Icon(AppIcons.chevronRight),
      onTap: () async {
        FilePickerResult? result;
        try {
          result = await FilePicker.platform.pickFiles();
        } on Exception catch (e) {
          log.error('Pick 3-rd party viewer failed', e);
          log.uploadError(e);
        }

        if (result == null || result.files.single.path == null) {
          return;
        }

        readSetting.saveThirdPartyViewerPath(result.files.single.path!);
      },
    );
  }

  Widget _buildKeyboardShortcuts(BuildContext context) {
    return ListTile(
      title: Text('keyboardShortcuts'.tr),
      subtitle: Text('keyboardShortcutsHint'.tr),
      trailing: Icon(AppIcons.chevronRight),
      onTap: () {
        final rootNav = Navigator.of(context, rootNavigator: true);
        final nearestNav = Navigator.of(context);
        if (rootNav != nearestNav &&
            nearestNav.widget.key != Get.keys[left] &&
            nearestNav.widget.key != Get.keys[right] &&
            nearestNav.widget.key != Get.keys[leftV2] &&
            nearestNav.widget.key != Get.keys[rightV2]) {
          nearestNav.push(
            PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const SettingKeyboardShortcutsPage(),
                transitionsBuilder:
                    preferenceSetting.enableSwipeBackGesture.isTrue &&
                            styleSetting.isInMobileLayout
                        ? (context, animation, secondaryAnimation, child) =>
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut,
                              )),
                              child: child,
                            )
                        : (context, animation, secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                transitionDuration:
                    UIConfig.defaultPageRouteTransitionDuration),
          );
        } else {
          toRoute(Routes.settingKeyboardShortcuts);
        }
      },
    );
  }

  Widget _buildPreloadDistanceInOnlineMode(BuildContext context) {
    return ListTile(
      title: Text('preloadDistanceInOnlineMode'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EHCodexStyleDropdown<int>(
            value: readSetting.preloadDistance.value,
            elevation: 4,
            onChanged: (int? newValue) {
              readSetting.savePreloadDistance(newValue!);
            },
            items: const [
              DropdownMenuItem(child: Text('0'), value: 0),
              DropdownMenuItem(child: Text('1'), value: 1),
              DropdownMenuItem(child: Text('2'), value: 2),
              DropdownMenuItem(child: Text('3'), value: 3),
              DropdownMenuItem(child: Text('5'), value: 5),
              DropdownMenuItem(child: Text('8'), value: 8),
              DropdownMenuItem(child: Text('10'), value: 10),
            ],
          ),
          Text('ScreenHeight'.tr,
                  style: UIConfig.settingPageListTileTrailingTextStyle(context))
              .marginSymmetric(horizontal: 12),
        ],
      ),
    );
  }

  Widget _buildPreloadDistanceInLocalMode(BuildContext context) {
    return ListTile(
      title: Text('preloadDistanceInLocalMode'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EHCodexStyleDropdown<int>(
            value: readSetting.preloadDistanceLocal.value,
            elevation: 4,
            onChanged: (int? newValue) {
              readSetting.savePreloadDistanceLocal(newValue!);
            },
            items: const [
              DropdownMenuItem(child: Text('0'), value: 0),
              DropdownMenuItem(child: Text('1'), value: 1),
              DropdownMenuItem(child: Text('2'), value: 2),
              DropdownMenuItem(child: Text('3'), value: 3),
              DropdownMenuItem(child: Text('5'), value: 5),
              DropdownMenuItem(child: Text('8'), value: 8),
              DropdownMenuItem(child: Text('10'), value: 10),
            ],
          ),
          Text('ScreenHeight'.tr,
                  style: UIConfig.settingPageListTileTrailingTextStyle(context))
              .marginSymmetric(horizontal: 12),
        ],
      ),
    );
  }

  Widget _buildPreloadPageCount() {
    return ListTile(
      title: Text('preloadPageCount'.tr),
      trailing: EHCodexStyleDropdown<int>(
        value: readSetting.preloadPageCount.value,
        elevation: 4,
        onChanged: (int? newValue) {
          readSetting.savePreloadPageCount(newValue!);
        },
        items: const [
          DropdownMenuItem(child: Text('0'), value: 0),
          DropdownMenuItem(child: Text('1'), value: 1),
          DropdownMenuItem(child: Text('2'), value: 2),
          DropdownMenuItem(child: Text('3'), value: 3),
          DropdownMenuItem(child: Text('5'), value: 5),
          DropdownMenuItem(child: Text('8'), value: 8),
          DropdownMenuItem(child: Text('10'), value: 10),
        ],
      ).marginOnly(right: 12),
    );
  }

  Widget _buildPreloadPageCountInLocalMode() {
    return ListTile(
      title: Text('preloadPageCountInLocalMode'.tr),
      trailing: EHCodexStyleDropdown<int>(
        value: readSetting.preloadPageCountLocal.value,
        elevation: 4,
        onChanged: (int? newValue) {
          readSetting.savePreloadPageCountLocal(newValue!);
        },
        items: const [
          DropdownMenuItem(child: Text('0'), value: 0),
          DropdownMenuItem(child: Text('1'), value: 1),
          DropdownMenuItem(child: Text('2'), value: 2),
          DropdownMenuItem(child: Text('3'), value: 3),
          DropdownMenuItem(child: Text('5'), value: 5),
          DropdownMenuItem(child: Text('8'), value: 8),
          DropdownMenuItem(child: Text('10'), value: 10),
        ],
      ).marginOnly(right: 12),
    );
  }

  Widget _buildDisplayFirstPageAlone() {
    return EHAppleSwitchListTile(
      title: Text('displayFirstPageAloneGlobally'.tr),
      value: readSetting.displayFirstPageAlone.value,
      onChanged: readSetting.saveDisplayFirstPageAlone,
    );
  }

  Widget _buildPortraitDisplayFirstPageAlone() {
    return EHAppleSwitchListTile(
      title: Text('portraitDisplayFirstPageAlone'.tr),
      value: readSetting.portraitDisplayFirstPageAlone.value,
      onChanged: readSetting.savePortraitDisplayFirstPageAlone,
    );
  }

  Widget _buildLandscapeDisplayFirstPageAlone() {
    return EHAppleSwitchListTile(
      title: Text('landscapeDisplayFirstPageAlone'.tr),
      value: readSetting.landscapeDisplayFirstPageAlone.value,
      onChanged: readSetting.saveLandscapeDisplayFirstPageAlone,
    );
  }

  Widget _buildAutoModeStyle() {
    return ListTile(
      title: Text('autoModeStyle'.tr),
      trailing: EHCodexStyleDropdown<AutoModeStyle>(
        value: readSetting.autoModeStyle.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (AutoModeStyle? newValue) =>
            readSetting.saveAutoModeStyle(newValue!),
        items: [
          DropdownMenuItem(
              child: Text('scroll'.tr), value: AutoModeStyle.scroll),
          DropdownMenuItem(
              child: Text('turnPage'.tr), value: AutoModeStyle.turnPage),
        ],
      ).marginOnly(right: 12),
    );
  }

  Widget _buildTurnPageMode() {
    return ListTile(
      title: Text('turnPageMode'.tr),
      subtitle: Text('turnPageModeHint'.tr),
      trailing: EHCodexStyleDropdown<TurnPageMode>(
        value: readSetting.turnPageMode.value,
        elevation: 4,
        onChanged: (TurnPageMode? newValue) =>
            readSetting.saveTurnPageMode(newValue!),
        items: [
          DropdownMenuItem(child: Text('image'.tr), value: TurnPageMode.image),
          DropdownMenuItem(
              child: Text('screen'.tr), value: TurnPageMode.screen),
          DropdownMenuItem(
              child: Text('adaptive'.tr), value: TurnPageMode.adaptive),
        ],
      ).marginOnly(right: 12),
    );
  }
}
