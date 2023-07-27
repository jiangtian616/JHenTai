import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/read_setting.dart';

import '../../../utils/log.dart';

class SettingReadPage extends StatelessWidget {
  const SettingReadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('readSetting'.tr)),
      body: Obx(
        () => SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              _buildEnableImmersiveMode().center(),
              _buildKeepScreenAwake().center(),
              _buildShowThumbnails().center(),
              _buildShowStatusInfo().center(),
              if (GetPlatform.isAndroid) _buildEnablePageTurnByVolumeKeys().center(),
              _buildEnablePageTurnAnime().center(),
              _buildEnableDoubleTapToScaleUp().center(),
              _buildEnableTapDragToScaleUp().center(),
              _buildEnableBottomMenu().center(),
              if (GetPlatform.isDesktop) _buildUseThirdPartyViewer().center(),
              if (GetPlatform.isDesktop) _buildThirdPartyViewerPath().center(),
              if (GetPlatform.isMobile) _buildDeviceDirection().center(),
              _buildReadDirection().center(),
              if (ReadSetting.isInListReadDirection)
                _buildPreloadDistanceInOnlineMode(context).fadeIn(const Key('preloadDistanceInOnlineMode')).center(),
              if (!ReadSetting.isInListReadDirection) _buildPreloadPageCount().fadeIn(const Key('preloadPageCount')).center(),
              if (ReadSetting.isInDoubleColumnReadDirection)
                _buildDisplayFirstPageAlone().fadeIn(const Key('displayFirstPageAloneGlobally')).center(),
              if (ReadSetting.isInListReadDirection) _buildAutoModeStyle().fadeIn(const Key('autoModeStyle')).center(),
              if (ReadSetting.isInListReadDirection) _buildTurnPageMode().fadeIn(const Key('turnPageMode')).center(),
              _buildImageSpace().center(),
            ],
          ).withListTileTheme(context),
        ),
      ),
    );
  }

  Widget _buildEnableImmersiveMode() {
    return ListTile(
      title: Text('enableImmersiveMode'.tr),
      subtitle: Text('enableImmersiveHint'.tr),
      trailing: Switch(value: ReadSetting.enableImmersiveMode.value, onChanged: ReadSetting.saveEnableImmersiveMode),
    );
  }

  Widget _buildKeepScreenAwake() {
    return ListTile(
      title: Text('keepScreenAwakeWhenReading'.tr),
      trailing: Switch(value: ReadSetting.keepScreenAwakeWhenReading.value, onChanged: ReadSetting.saveKeepScreenAwakeWhenReading),
    );
  }

  Widget _buildImageSpace() {
    return ListTile(
      title: Text('spaceBetweenImages'.tr),
      trailing: DropdownButton<int>(
        value: ReadSetting.imageSpace.value,
        elevation: 4,
        onChanged: (int? newValue) {
          ReadSetting.saveImageSpace(newValue!);
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
    );
  }

  Widget _buildShowThumbnails() {
    return ListTile(
      title: Text('showThumbnails'.tr),
      trailing: Switch(value: ReadSetting.showThumbnails.value, onChanged: ReadSetting.saveShowThumbnails),
    );
  }

  Widget _buildShowStatusInfo() {
    return ListTile(
      title: Text('showStatusInfo'.tr),
      trailing: Switch(value: ReadSetting.showStatusInfo.value, onChanged: ReadSetting.saveShowStatusInfo),
    );
  }

  Widget _buildEnablePageTurnByVolumeKeys() {
    return ListTile(
      title: Text('enablePageTurnByVolumeKeys'.tr),
      trailing: Switch(value: ReadSetting.enablePageTurnByVolumeKeys.value, onChanged: ReadSetting.saveEnablePageTurnByVolumeKeys),
    );
  }

  Widget _buildEnablePageTurnAnime() {
    return ListTile(
      title: Text('enablePageTurnAnime'.tr),
      trailing: Switch(value: ReadSetting.enablePageTurnAnime.value, onChanged: ReadSetting.saveEnablePageTurnAnime),
    );
  }

  Widget _buildEnableDoubleTapToScaleUp() {
    return ListTile(
      title: Text('enableDoubleTapToScaleUp'.tr),
      trailing: Switch(value: ReadSetting.enableDoubleTapToScaleUp.value, onChanged: ReadSetting.saveEnableDoubleTapToScaleUp),
    );
  }

  Widget _buildEnableTapDragToScaleUp() {
    return ListTile(
      title: Text('enableTapDragToScaleUp'.tr),
      trailing: Switch(value: ReadSetting.enableTapDragToScaleUp.value, onChanged: ReadSetting.saveEnableTapDragToScaleUp),
    );
  }
  
  Widget _buildEnableBottomMenu(){
    return ListTile(
      title: Text('enableBottomMenu'.tr),
      trailing: Switch(value: ReadSetting.enableBottomMenu.value, onChanged: ReadSetting.saveEnableBottomMenu),
    );
  }

  Widget _buildDeviceDirection() {
    return ListTile(
      title: Text('deviceOrientation'.tr),
      trailing: DropdownButton<DeviceDirection>(
        value: ReadSetting.deviceDirection.value,
        elevation: 4,
        onChanged: (DeviceDirection? newValue) => ReadSetting.saveDeviceDirection(newValue!),
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
        value: ReadSetting.readDirection.value,
        elevation: 4,
        onChanged: (ReadDirection? newValue) => ReadSetting.saveReadDirection(newValue!),
        items: ReadDirection.values.map((e) => DropdownMenuItem(child: Text(e.name.tr), value: e)).toList(),
      ).marginOnly(right: 12),
    );
  }

  Widget _buildUseThirdPartyViewer() {
    return SwitchListTile(
      title: Text('useThirdPartyViewer'.tr),
      value: ReadSetting.useThirdPartyViewer.value,
      onChanged: ReadSetting.saveUseThirdPartyViewer,
    );
  }

  Widget _buildThirdPartyViewerPath() {
    return ListTile(
      title: Text('thirdPartyViewerPath'.tr),
      subtitle: Text(ReadSetting.thirdPartyViewerPath.value ?? ''),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        FilePickerResult? result;
        try {
          result = await FilePicker.platform.pickFiles();
        } on Exception catch (e) {
          Log.error('Pick 3-rd party viewer failed', e);
          Log.upload(e);
        }

        if (result == null || result.files.single.path == null) {
          return;
        }

        ReadSetting.saveThirdPartyViewerPath(result.files.single.path!);
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
            value: ReadSetting.preloadDistance.value,
            elevation: 4,
            onChanged: (int? newValue) {
              ReadSetting.savePreloadDistance(newValue!);
            },
            items: const [
              DropdownMenuItem(
                child: Text('0'),
                value: 0,
              ),
              DropdownMenuItem(
                child: Text('1'),
                value: 1,
              ),
              DropdownMenuItem(
                child: Text('2'),
                value: 2,
              ),
              DropdownMenuItem(
                child: Text('3'),
                value: 3,
              ),
              DropdownMenuItem(
                child: Text('5'),
                value: 5,
              ),
              DropdownMenuItem(
                child: Text('10'),
                value: 10,
              ),
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
        value: ReadSetting.preloadPageCount.value,
        elevation: 4,
        onChanged: (int? newValue) {
          ReadSetting.savePreloadPageCount(newValue!);
        },
        items: const [
          DropdownMenuItem(
            child: Text('0'),
            value: 0,
          ),
          DropdownMenuItem(
            child: Text('1'),
            value: 1,
          ),
          DropdownMenuItem(
            child: Text('2'),
            value: 2,
          ),
          DropdownMenuItem(
            child: Text('3'),
            value: 3,
          ),
          DropdownMenuItem(
            child: Text('5'),
            value: 5,
          ),
          DropdownMenuItem(
            child: Text('10'),
            value: 10,
          ),
        ],
      ).marginOnly(right: 12),
    );
  }

  Widget _buildDisplayFirstPageAlone() {
    return ListTile(
      title: Text('displayFirstPageAloneGlobally'.tr),
      trailing: Switch(value: ReadSetting.displayFirstPageAlone.value, onChanged: ReadSetting.saveDisplayFirstPageAlone),
    );
  }

  Widget _buildAutoModeStyle() {
    return ListTile(
      title: Text('autoModeStyle'.tr),
      trailing: DropdownButton<AutoModeStyle>(
        value: ReadSetting.autoModeStyle.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (AutoModeStyle? newValue) => ReadSetting.saveAutoModeStyle(newValue!),
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
        value: ReadSetting.turnPageMode.value,
        elevation: 4,
        onChanged: (TurnPageMode? newValue) => ReadSetting.saveTurnPageMode(newValue!),
        items: [
          DropdownMenuItem(child: Text('image'.tr), value: TurnPageMode.image),
          DropdownMenuItem(child: Text('screen'.tr), value: TurnPageMode.screen),
          DropdownMenuItem(child: Text('adaptive'.tr), value: TurnPageMode.adaptive),
        ],
      ).marginOnly(right: 12),
    );
  }
}
