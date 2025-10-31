import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/service/ml_tts_service.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../service/log.dart';
import '../../../utils/text_input_formatter.dart';
import '../../../utils/toast_util.dart';

class SettingReadPage extends StatelessWidget {
  final TextEditingController imageRegionWidthRatioController = TextEditingController(text: readSetting.imageRegionWidthRatio.value.toString());
  final TextEditingController gestureRegionWidthRatioController = TextEditingController(text: readSetting.gestureRegionWidthRatio.value.toString());
  final TextEditingController imageMaxKilobytesController = TextEditingController(text: readSetting.maxImageKilobyte.value.toString());
  final TextEditingController mlTtsExclusionListController = TextEditingController(text: readSetting.mlTtsExclusionList.value);
  final TextEditingController mlTtsReplaceListController = TextEditingController(text: readSetting.mlTtsReplaceList.value);

  SettingReadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('readSetting'.tr)),
      body: Obx(
        () => SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              if (GetPlatform.isMobile || GetPlatform.isWindows) _buildEnableImmersiveMode().center(),
              _buildKeepScreenAwake().center(),
              if (GetPlatform.isMobile) _buildEnableCustomReadBrightness().center(),
              if (GetPlatform.isMobile) _buildCustomReadBrightness().center(),
              _buildShowThumbnails().center(),
              _buildShowScrollBar().center(),
              _buildShowStatusInfo().center(),
              if (GetPlatform.isAndroid) _buildEnablePageTurnByVolumeKeys().center(),
              _buildEnablePageTurnAnime().center(),
              _buildEnableDoubleTapToScaleUp().center(),
              _buildEnableTapDragToScaleUp().center(),
              _buildEnableBottomMenu().center(),
              _buildReverseTurnPageDirection().center(),
              _buildDisableTurnPageOnTap().center(),
              _buildEnableImageMaxKilobytes().center(),
              if (readSetting.enableMaxImageKilobyte.isTrue) _buildImageMaxKilobytes(context).fadeIn(const Key('imageMaxKilobytes')).center(),
              _buildGestureRegionWidthRatio(context).center(),
              if (GetPlatform.isDesktop) _buildUseThirdPartyViewer().center(),
              if (GetPlatform.isDesktop) _buildThirdPartyViewerPath().center(),
              if (GetPlatform.isMobile) _buildDeviceDirection().center(),
              _buildReadDirection().center(),
              if (GetPlatform.isMobile && readSetting.readDirection.value == ReadDirection.top2bottomList) _buildNotchOptimization().center(),
              if (readSetting.readDirection.value == ReadDirection.top2bottomList) _buildImageRegionWidthRatio(context).center(),
              if (readSetting.isInListReadDirection) _buildPreloadDistanceInOnlineMode(context).fadeIn(const Key('preloadDistanceInOnlineMode')).center(),
              if (readSetting.isInListReadDirection) _buildPreloadDistanceInLocalMode(context).fadeIn(const Key('preloadDistanceInLocalMode')).center(),
              if (!readSetting.isInListReadDirection) _buildPreloadPageCount().fadeIn(const Key('preloadPageCount')).center(),
              if (!readSetting.isInListReadDirection) _buildPreloadPageCountInLocalMode().fadeIn(const Key('preloadPageCountInLocalMode')).center(),
              if (readSetting.isInDoubleColumnReadDirection) _buildDisplayFirstPageAlone().fadeIn(const Key('displayFirstPageAloneGlobally')).center(),
              if (readSetting.isInListReadDirection) _buildAutoModeStyle().fadeIn(const Key('autoModeStyle')).center(),
              if (readSetting.isInListReadDirection) _buildTurnPageMode().fadeIn(const Key('turnPageMode')).center(),
              if (GetPlatform.isMobile) _buildImageSpace().center(),
              if (GetPlatform.isMobile) _buildMlTtsEnable().center(),
              if (GetPlatform.isMobile) _buildMlTtsScript().center(),
              if (GetPlatform.isMobile) _buildMlTtsLanguage().center(),
              if (GetPlatform.isAndroid) _buildMlTtsEngine().center(),
              if (GetPlatform.isMobile) _buildMlTtsVolume(context).center(),
              if (GetPlatform.isMobile) _buildMlTtsRate(context).center(),
              if (GetPlatform.isMobile) _buildMlTtsPitch(context).center(),
              if (GetPlatform.isMobile) _buildMlTtsMinWordLimit(context).center(),
              if (GetPlatform.isMobile) _buildMlTtsExclusionList(context).center(),
              if (GetPlatform.isMobile) _buildMlTtsReplaceList(context).center(),
            ],
          ).withListTileTheme(context),
        ),
      ),
    );
  }

  Widget _buildEnableImmersiveMode() {
    return SwitchListTile(
      title: Text('enableImmersiveMode'.tr),
      subtitle: GetPlatform.isMobile ? Text('enableImmersiveHint'.tr) : Text('enableImmersiveHint4Windows'.tr),
      value: readSetting.enableImmersiveMode.value,
      onChanged: readSetting.saveEnableImmersiveMode,
    );
  }

  Widget _buildKeepScreenAwake() {
    return SwitchListTile(
      title: Text('keepScreenAwakeWhenReading'.tr),
      value: readSetting.keepScreenAwakeWhenReading.value,
      onChanged: readSetting.saveKeepScreenAwakeWhenReading,
    );
  }

  Widget _buildEnableCustomReadBrightness() {
    return SwitchListTile(
      title: Text('enableCustomReadBrightness'.tr),
      value: readSetting.enableCustomReadBrightness.value,
      onChanged: readSetting.saveEnableCustomReadBrightness,
    );
  }

  Widget _buildShowThumbnails() {
    return SwitchListTile(
      title: Text('showThumbnails'.tr),
      value: readSetting.showThumbnails.value,
      onChanged: readSetting.saveShowThumbnails,
    );
  }

  Widget _buildShowScrollBar() {
    return SwitchListTile(
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
          child: Slider(
            value: readSetting.customBrightness.value.toDouble(),
            onChanged: (double value) => readSetting.saveCustomBrightness(value.toInt()),
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
      trailing: DropdownButton<int>(
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
    return SwitchListTile(
      title: Text('showStatusInfo'.tr),
      value: readSetting.showStatusInfo.value,
      onChanged: readSetting.saveShowStatusInfo,
    );
  }

  Widget _buildEnablePageTurnByVolumeKeys() {
    return SwitchListTile(
      title: Text('enablePageTurnByVolumeKeys'.tr),
      value: readSetting.enablePageTurnByVolumeKeys.value,
      onChanged: readSetting.saveEnablePageTurnByVolumeKeys,
    );
  }

  Widget _buildEnablePageTurnAnime() {
    return SwitchListTile(
      title: Text('enablePageTurnAnime'.tr),
      value: readSetting.enablePageTurnAnime.value,
      onChanged: readSetting.saveEnablePageTurnAnime,
    );
  }

  Widget _buildEnableDoubleTapToScaleUp() {
    return SwitchListTile(
      title: Text('enableDoubleTapToScaleUp'.tr),
      value: readSetting.enableDoubleTapToScaleUp.value,
      onChanged: readSetting.saveEnableDoubleTapToScaleUp,
    );
  }

  Widget _buildEnableTapDragToScaleUp() {
    return SwitchListTile(
      title: Text('enableTapDragToScaleUp'.tr),
      value: readSetting.enableTapDragToScaleUp.value,
      onChanged: readSetting.saveEnableTapDragToScaleUp,
    );
  }

  Widget _buildEnableBottomMenu() {
    return SwitchListTile(
      title: Text('enableBottomMenu'.tr),
      value: readSetting.enableBottomMenu.value,
      onChanged: readSetting.saveEnableBottomMenu,
    );
  }

  Widget _buildReverseTurnPageDirection() {
    return SwitchListTile(
      title: Text('reverseTurnPageDirection'.tr),
      value: readSetting.reverseTurnPageDirection.value,
      onChanged: readSetting.saveReverseTurnPageDirection,
    );
  }

  Widget _buildDisableTurnPageOnTap() {
    return SwitchListTile(
      title: Text('disablePageTurningOnTap'.tr),
      value: readSetting.disablePageTurningOnTap.value,
      onChanged: readSetting.saveDisablePageTurningOnTap,
    );
  }

  Widget _buildEnableImageMaxKilobytes() {
    return SwitchListTile(
      title: Text('enableImageMaxKilobytes'.tr),
      value: readSetting.enableMaxImageKilobyte.value,
      onChanged: readSetting.saveEnableMaxImageKilobyte,
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
            child: TextField(
              controller: imageMaxKilobytesController,
              decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, IntRangeTextInputFormatter(minValue: 1)],
            ),
          ),
          Text('KB', style: UIConfig.settingPageListTileTrailingTextStyle(context)),
          IconButton(
            onPressed: () {
              int? value = int.tryParse(imageMaxKilobytesController.value.text);
              if (value == null) {
                return;
              }
              readSetting.saveMaxImageKilobyte(value);
              toast('saveSuccess'.tr);
            },
            icon: Icon(Icons.check, color: UIConfig.resumePauseButtonColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDirection() {
    return ListTile(
      title: Text('deviceOrientation'.tr),
      trailing: DropdownButton<DeviceDirection>(
        value: readSetting.deviceDirection.value,
        elevation: 4,
        onChanged: (DeviceDirection? newValue) => readSetting.saveDeviceDirection(newValue!),
        items: [
          DropdownMenuItem(child: Text('followSystem'.tr), value: DeviceDirection.followSystem),
          DropdownMenuItem(child: Text('landscape'.tr), value: DeviceDirection.landscape),
          DropdownMenuItem(child: Text('portrait'.tr), value: DeviceDirection.portrait),
        ],
      ).marginOnly(right: 12),
    );
  }

  Widget _buildReadDirection() {
    return ListTile(
      title: Text('readDirection'.tr),
      trailing: DropdownButton<ReadDirection>(
        value: readSetting.readDirection.value,
        elevation: 4,
        onChanged: (ReadDirection? newValue) => readSetting.saveReadDirection(newValue!),
        items: ReadDirection.values.map((e) => DropdownMenuItem(child: Text(e.name.tr), value: e)).toList(),
      ).marginOnly(right: 12),
    );
  }

  Widget _buildMlTtsEnable() {
    return SwitchListTile(
      title: Text('mlTtsEnable'.tr),
      value: readSetting.mlTtsEnable.value,
      onChanged: readSetting.saveMlTtsEnable,
    );
  }

  Widget _buildMlTtsScript() {
    return ListTile(
      enabled: readSetting.mlTtsEnable.value,
      title: Text('mlTtsScript'.tr),
      trailing: DropdownButton<TextRecognitionScript>(
        value: readSetting.mlTtsScript.value,
        disabledHint: Text(readSetting.mlTtsScript.value.name),
        elevation: 4,
        onChanged: (TextRecognitionScript? newValue) => readSetting.saveMlTtsScript(newValue!),
        items: readSetting.mlTtsEnable.value ? TextRecognitionScript.values.map((e) => DropdownMenuItem(child: Text(e.name.tr), value: e)).toList() : null,
      ).marginOnly(right: 12),
    );
  }

  Widget _buildMlTtsLanguage() {
    return ListTile(
      enabled: readSetting.mlTtsEnable.value,
      title: Text('mlTtsLanguage'.tr),
      trailing: DropdownButton<String>(
        value: readSetting.mlTtsLanguage.value,
        disabledHint: Text(readSetting.mlTtsLanguage.value ?? ''),
        elevation: 4,
        onChanged: (String? newValue) => readSetting.saveMlTtsLanguage(newValue!),
        items: readSetting.mlTtsEnable.value ? mlTtsService.languages.map(((e) => DropdownMenuItem(child: Text(e), value: e))).toList() : null,
      ).marginOnly(right: 12),
    );
  }

  Widget _buildMlTtsEngine() {
    return ListTile(
      enabled: readSetting.mlTtsEnable.value,
      title: Text('mlTtsEngine'.tr),
      trailing: DropdownButton<String>(
        value: readSetting.mlTtsEngine.value,
        disabledHint: Text(readSetting.mlTtsEngine.value ?? ''),
        elevation: 4,
        onChanged: (String? newValue) => readSetting.saveMlTtsEngine(newValue!),
        items: readSetting.mlTtsEnable.value ? mlTtsService.engines.map(((e) => DropdownMenuItem(child: Text(e.tr), value: e))).toList() : null,
      ).marginOnly(right: 12),
    );
  }

  Widget _buildMlTtsVolume(BuildContext context) {
    return ListTile(
      enabled: readSetting.mlTtsEnable.value,
      title: Text('mlTtsVolume'.tr),
      trailing: Obx(() {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(showValueIndicator: ShowValueIndicator.always),
              child: Slider(
                min: 0.0,
                max: 1.0,
                label: readSetting.mlTtsVolume.value.toString(),
                value: readSetting.mlTtsVolume.value,
                onChangeEnd: (value) => readSetting.saveMlTtsVolume(double.parse(value.toStringAsFixed(2))), 
                onChanged: readSetting.mlTtsEnable.value ? (value) => readSetting.mlTtsVolume.value = double.parse(value.toStringAsFixed(2)) : null,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMlTtsPitch(BuildContext context) {
    return ListTile(
      enabled: readSetting.mlTtsEnable.value,
      title: Text('mlTtsPitch'.tr),
      trailing: Obx(() {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(showValueIndicator: ShowValueIndicator.always),
              child: Slider(
                min: 0.5,
                max: 2.0,
                label: readSetting.mlTtsPitch.value.toString(),
                value: readSetting.mlTtsPitch.value,
                onChangeEnd: (value) => readSetting.saveMlTtsPitch(double.parse(value.toStringAsFixed(2))), 
                onChanged: readSetting.mlTtsEnable.value ? (value) => readSetting.mlTtsPitch.value = double.parse(value.toStringAsFixed(2)) : null,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMlTtsRate(BuildContext context) {
    return ListTile(
      enabled: readSetting.mlTtsEnable.value,
      title: Text('mlTtsRate'.tr),
      trailing: Obx(() {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(showValueIndicator: ShowValueIndicator.always),
              child: Slider(
                min: 0.0,
                max: 1.0,
                label: readSetting.mlTtsRate.value.toString(),
                value: readSetting.mlTtsRate.value,
                onChangeEnd: (value) => readSetting.saveMlTtsRate(double.parse(value.toStringAsFixed(2))), 
                onChanged: readSetting.mlTtsEnable.value ? (value) => readSetting.mlTtsRate.value = double.parse(value.toStringAsFixed(2)) : null,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMlTtsExclusionList(BuildContext context) {
    void _onEditingComplete() {
      FocusScope.of(context).unfocus();
      _saveMlTtsExclusionList();
    }
    return ListTile(
      enabled: readSetting.mlTtsEnable.value,
      title: Text('mlTtsExclusionList'.tr),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          enabled: readSetting.mlTtsEnable.value,
          controller: mlTtsExclusionListController,
          decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
          textAlign: TextAlign.left,
          textInputAction: TextInputAction.done,
          onEditingComplete: _onEditingComplete,
        ),
      ),
    );
  }

  Widget _buildMlTtsReplaceList(BuildContext context) {
    void _onEditingComplete() {
      FocusScope.of(context).unfocus();
      _saveMlTtsReplaceList();
    }
    return ListTile(
      enabled: readSetting.mlTtsEnable.value,
      title: Text('mlTtsReplaceList'.tr),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          enabled: readSetting.mlTtsEnable.value,
          controller: mlTtsReplaceListController,
          decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
          textAlign: TextAlign.left,
          textInputAction: TextInputAction.done,
          onEditingComplete: _onEditingComplete,
        ),
      ),
    );
  }

  Widget _buildMlTtsMinWordLimit(BuildContext context) {
    return ListTile(
      enabled: readSetting.mlTtsEnable.value,
      title: Text('mlTtsMinWordLimit'.tr),
      trailing: Obx(() {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(showValueIndicator: ShowValueIndicator.always),
              child: Slider(
                min: 0,
                max: 10,
                label: readSetting.mlTtsMinWordLimit.value.toString(),
                value: readSetting.mlTtsMinWordLimit.value.toDouble(),
                onChangeEnd: (value) => readSetting.saveMlTtsMinWordLimit(value.toInt()), 
                onChanged: readSetting.mlTtsEnable.value ? (value) => readSetting.mlTtsMinWordLimit.value = value.toInt() : null,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildNotchOptimization() {
    return ListTile(
      title: Text('notchOptimization'.tr),
      subtitle: Text('notchOptimizationHint'.tr),
      trailing: Switch(value: readSetting.notchOptimization.value, onChanged: readSetting.saveNotchOptimization),
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
            child: TextField(
              controller: imageRegionWidthRatioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
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
            icon: Icon(Icons.check, color: UIConfig.resumePauseButtonColor(context)),
          ),
        ],
      ),
    ).marginOnly(right: 12);
  }

  void _saveMlTtsExclusionList() {
    var value = mlTtsExclusionListController.value.text;
    readSetting.saveMlTtsExclusionList(value);
  }

  void _saveMlTtsReplaceList() {
    var value = mlTtsReplaceListController.value.text;
    readSetting.saveMlTtsReplaceList(value);
  }

  void _saveImageRegionWidthRatio() {
    int? value = int.tryParse(imageRegionWidthRatioController.value.text);
    if (value == null) {
      return;
    }
    readSetting.saveImageRegionWidthRatio(value);
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
            child: TextField(
              controller: gestureRegionWidthRatioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
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
            icon: Icon(Icons.check, color: UIConfig.resumePauseButtonColor(context)),
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

  Widget _buildUseThirdPartyViewer() {
    return SwitchListTile(
      title: Text('useThirdPartyViewer'.tr),
      value: readSetting.useThirdPartyViewer.value,
      onChanged: readSetting.saveUseThirdPartyViewer,
    );
  }

  Widget _buildThirdPartyViewerPath() {
    return ListTile(
      title: Text('thirdPartyViewerPath'.tr),
      subtitle: Text(readSetting.thirdPartyViewerPath.value ?? ''),
      trailing: const Icon(Icons.keyboard_arrow_right),
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

  Widget _buildPreloadDistanceInOnlineMode(BuildContext context) {
    return ListTile(
      title: Text('preloadDistanceInOnlineMode'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<int>(
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
          Text('ScreenHeight'.tr, style: UIConfig.settingPageListTileTrailingTextStyle(context)).marginSymmetric(horizontal: 12),
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
          DropdownButton<int>(
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
          Text('ScreenHeight'.tr, style: UIConfig.settingPageListTileTrailingTextStyle(context)).marginSymmetric(horizontal: 12),
        ],
      ),
    );
  }

  Widget _buildPreloadPageCount() {
    return ListTile(
      title: Text('preloadPageCount'.tr),
      trailing: DropdownButton<int>(
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
      trailing: DropdownButton<int>(
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
    return SwitchListTile(
      title: Text('displayFirstPageAloneGlobally'.tr),
      value: readSetting.displayFirstPageAlone.value,
      onChanged: readSetting.saveDisplayFirstPageAlone,
    );
  }

  Widget _buildAutoModeStyle() {
    return ListTile(
      title: Text('autoModeStyle'.tr),
      trailing: DropdownButton<AutoModeStyle>(
        value: readSetting.autoModeStyle.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (AutoModeStyle? newValue) => readSetting.saveAutoModeStyle(newValue!),
        items: [
          DropdownMenuItem(child: Text('scroll'.tr), value: AutoModeStyle.scroll),
          DropdownMenuItem(child: Text('turnPage'.tr), value: AutoModeStyle.turnPage),
        ],
      ).marginOnly(right: 12),
    );
  }

  Widget _buildTurnPageMode() {
    return ListTile(
      title: Text('turnPageMode'.tr),
      subtitle: Text('turnPageModeHint'.tr),
      trailing: DropdownButton<TurnPageMode>(
        value: readSetting.turnPageMode.value,
        elevation: 4,
        onChanged: (TurnPageMode? newValue) => readSetting.saveTurnPageMode(newValue!),
        items: [
          DropdownMenuItem(child: Text('image'.tr), value: TurnPageMode.image),
          DropdownMenuItem(child: Text('screen'.tr), value: TurnPageMode.screen),
          DropdownMenuItem(child: Text('adaptive'.tr), value: TurnPageMode.adaptive),
        ],
      ).marginOnly(right: 12),
    );
  }
}
