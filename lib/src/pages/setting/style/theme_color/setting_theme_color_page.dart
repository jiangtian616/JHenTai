import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/setting/style_setting.dart';

class SettingThemeColorPage extends StatefulWidget {
  const SettingThemeColorPage({Key? key}) : super(key: key);

  @override
  State<SettingThemeColorPage> createState() => _SettingThemeColorPageState();
}

class _SettingThemeColorPageState extends State<SettingThemeColorPage> {
  _BodyMode bodyMode = _BodyMode.preview;
  ThemeMode themeMode = StyleSetting.themeMode.value;
  Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('themeColor'.tr)),
      body: bodyMode == _BodyMode.preview ? _buildPreviewBody() : _buildSettingBody(),
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  Widget _buildPreviewBody() {
    return Container();
  }

  Widget _buildSettingBody() {
    return Column(
      children: [
        ColorPicker(
          color: themeMode == ThemeMode.light ? StyleSetting.lightThemeColor.value : StyleSetting.darkThemeColor.value,
          pickersEnabled: const <ColorPickerType, bool>{
            ColorPickerType.both: true,
            ColorPickerType.primary: false,
            ColorPickerType.accent: false,
            ColorPickerType.bw: false,
            ColorPickerType.custom: false,
            ColorPickerType.wheel: true,
          },
          pickerTypeLabels: <ColorPickerType, String>{
            ColorPickerType.both: 'preset'.tr,
            ColorPickerType.wheel: 'custom'.tr,
          },
          enableTonalPalette: true,
          showColorCode: true,
          colorCodeHasColor: true,
          onColorChanged: (Color color) {
            selectedColor = color;
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              child: Text('cancel'.tr),
              onPressed: () {
                setState(() => bodyMode = _BodyMode.preview);
              },
            ),
            TextButton(
              child: Text('OK'.tr),
              onPressed: () {
                if (selectedColor == null) {
                  return;
                }

                if (themeMode == ThemeMode.light) {
                  StyleSetting.saveLightThemeColor(selectedColor!);
                } else {
                  StyleSetting.saveDarkThemeColor(selectedColor!);
                }

                bodyMode = _BodyMode.preview;

                if (themeMode == StyleSetting.themeMode.value) {
                  Get.changeTheme(
                    themeMode == ThemeMode.light
                        ? ThemeConfig.light.copyWith(colorScheme: ThemeConfig.generateColorScheme(selectedColor!, Brightness.light))
                        : ThemeConfig.dark.copyWith(colorScheme: ThemeConfig.generateColorScheme(selectedColor!, Brightness.dark)),
                  );
                } else {
                  setState(() => bodyMode = _BodyMode.preview);
                }
              },
            ),
          ],
        ).marginOnly(top: 24),
      ],
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(themeMode == ThemeMode.light ? Icons.sunny : Icons.nightlight),
            onPressed: () {
              setState(() => themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
            },
          ),
          IconButton(
            icon: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeMode == ThemeMode.light ? StyleSetting.lightThemeColor.value : StyleSetting.darkThemeColor.value,
              ),
            ),
            onPressed: () {
              setState(() => bodyMode = bodyMode == _BodyMode.preview ? _BodyMode.setting : _BodyMode.preview);
            },
          ),
        ],
      ),
    );
  }
}

enum _BodyMode { preview, setting }
