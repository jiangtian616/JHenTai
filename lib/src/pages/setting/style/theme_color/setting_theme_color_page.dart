import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/pages/setting/style/theme_color/preview_page/detail_preview_page.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:carousel_slider/carousel_slider.dart';

class SettingThemeColorPage extends StatefulWidget {
  const SettingThemeColorPage({Key? key}) : super(key: key);

  @override
  State<SettingThemeColorPage> createState() => _SettingThemeColorPageState();
}

class _SettingThemeColorPageState extends State<SettingThemeColorPage> {
  ThemeMode selectedThemeMode = StyleSetting.themeMode.value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('themeColor'.tr)),
      body: _buildPreviewBody(),
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  Widget _buildPreviewBody() {
    ThemeData previewThemeData = selectedThemeMode == ThemeMode.light
        ? ThemeConfig.light.copyWith(colorScheme: ThemeConfig.generateColorScheme(StyleSetting.lightThemeColor.value, Brightness.light))
        : ThemeConfig.dark.copyWith(colorScheme: ThemeConfig.generateColorScheme(StyleSetting.darkThemeColor.value, Brightness.dark));

    return Column(
      children: [
        Expanded(
          child: Theme(
            data: previewThemeData,
            child: CarouselSlider(
              items: [
                DetailPreviewPage(),
              ],
              options: CarouselOptions(height: 400.0, enableInfiniteScroll: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      height: 88,
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(selectedThemeMode == ThemeMode.light ? Icons.sunny : Icons.nightlight),
                  onPressed: () {
                    setState(() => selectedThemeMode = selectedThemeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                IconButton(
                  icon: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selectedThemeMode == ThemeMode.light ? StyleSetting.lightThemeColor.value : StyleSetting.darkThemeColor.value,
                    ),
                  ),
                  onPressed: () async {
                    Color? newColor = await Get.dialog(
                      _ColorSettingDialog(
                        initialColor: selectedThemeMode == ThemeMode.light ? StyleSetting.lightThemeColor.value : StyleSetting.darkThemeColor.value,
                      ),
                    );

                    if (newColor == null) {
                      return;
                    }

                    if (selectedThemeMode == ThemeMode.light) {
                      StyleSetting.saveLightThemeColor(newColor);
                      Get.rootController.theme = ThemeConfig.light.copyWith(colorScheme: ThemeConfig.generateColorScheme(newColor, Brightness.light));
                    } else {
                      StyleSetting.saveDarkThemeColor(newColor);
                      Get.rootController.darkTheme = ThemeConfig.dark.copyWith(colorScheme: ThemeConfig.generateColorScheme(newColor, Brightness.dark));
                    }

                    if (selectedThemeMode == StyleSetting.themeMode.value) {
                      Get.rootController.updateSafely();
                    }

                    toast('success'.tr);
                  },
                ),
              ],
            ),
          ),
          Text('themeColorSettingHint'.tr),
        ],
      ),
    );
  }
}

class _ColorSettingDialog extends StatefulWidget {
  final Color initialColor;

  const _ColorSettingDialog({Key? key, required this.initialColor}) : super(key: key);

  @override
  State<_ColorSettingDialog> createState() => _ColorSettingDialogState();
}

class _ColorSettingDialogState extends State<_ColorSettingDialog> {
  late Color selectedColor;

  @override
  void initState() {
    selectedColor = widget.initialColor;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: [
        ColorPicker(
          color: selectedColor,
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
                backRoute();
              },
            ),
            TextButton(
              child: Text('OK'.tr),
              onPressed: () {
                backRoute(result: selectedColor);
              },
            ),
          ],
        ).marginOnly(top: 24),
      ],
    );
  }
}
