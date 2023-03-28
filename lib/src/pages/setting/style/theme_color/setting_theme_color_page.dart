import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/pages/setting/style/theme_color/preview_page/detail_preview_page.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';

class SettingThemeColorPage extends StatefulWidget {
  const SettingThemeColorPage({Key? key}) : super(key: key);

  @override
  State<SettingThemeColorPage> createState() => _SettingThemeColorPageState();
}

class _SettingThemeColorPageState extends State<SettingThemeColorPage> {
  Brightness selectedBrightness = StyleSetting.currentBrightness();

  @override
  Widget build(BuildContext context) {
    ThemeData previewThemeData = selectedBrightness == Brightness.light
        ? ThemeConfig.generateThemeData(StyleSetting.lightThemeColor.value, Brightness.light)
        : ThemeConfig.generateThemeData(StyleSetting.darkThemeColor.value, Brightness.dark);

    return Theme(
      data: previewThemeData,
      child: Scaffold(
        appBar: AppBar(centerTitle: true, title: Text('preview'.tr)),
        body: DetailPreviewPage(),
        bottomNavigationBar: _buildBottomAppBar(),
      ),
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      height: 150,
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(selectedBrightness == Brightness.light ? Icons.sunny : Icons.nightlight),
                  onPressed: () {
                    setState(() => selectedBrightness = selectedBrightness == Brightness.light ? Brightness.dark : Brightness.light);
                  },
                ),
                IconButton(
                  icon: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selectedBrightness == Brightness.light ? StyleSetting.lightThemeColor.value : StyleSetting.darkThemeColor.value,
                    ),
                  ),
                  onPressed: () async {
                    Color? newColor = await Get.dialog(
                      _ColorSettingDialog(
                        initialColor: selectedBrightness == Brightness.light ? StyleSetting.lightThemeColor.value : StyleSetting.darkThemeColor.value,
                        resetColor: selectedBrightness == Brightness.light ? UIConfig.defaultLightThemeColor : UIConfig.defaultDarkThemeColor,
                      ),
                    );

                    if (newColor == null) {
                      return;
                    }

                    if (selectedBrightness == Brightness.light) {
                      StyleSetting.saveLightThemeColor(newColor);
                      Get.rootController.theme = ThemeConfig.generateThemeData(StyleSetting.lightThemeColor.value, Brightness.light);
                    } else {
                      StyleSetting.saveDarkThemeColor(newColor);
                      Get.rootController.darkTheme = ThemeConfig.generateThemeData(StyleSetting.darkThemeColor.value, Brightness.dark);
                    }

                    if (selectedBrightness == StyleSetting.currentBrightness()) {
                      Get.rootController.updateSafely();
                    }

                    setState(() {});
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
  final Color resetColor;

  const _ColorSettingDialog({Key? key, required this.initialColor, required this.resetColor}) : super(key: key);

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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ColorPicker(
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
            colorCodeTextStyle: const TextStyle(fontSize: 18),
            enableOpacity: true,
            width: 36,
            height: 36,
            columnSpacing: 16,
            onColorChanged: (Color color) {
              selectedColor = color;
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              child: Text('cancel'.tr),
              onPressed: backRoute,
            ),
            TextButton(
              child: Text('reset'.tr),
              onPressed: () {
                setState(() => selectedColor = widget.resetColor);
              },
            ),
            TextButton(
              child: Text('OK'.tr),
              onPressed: () {
                backRoute(result: selectedColor);
              },
            ),
          ],
        ),
      ],
    );
  }
}
