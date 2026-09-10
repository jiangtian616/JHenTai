import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/tap_zone_config.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/widget/tap_zone_guide_overlay.dart';

class SettingTapZonePage extends StatefulWidget {
  const SettingTapZonePage({super.key});

  @override
  State<SettingTapZonePage> createState() => _SettingTapZonePageState();
}

class _SettingTapZonePageState extends State<SettingTapZonePage> {
  late TapZoneConfig _config;

  @override
  void initState() {
    super.initState();
    _config = readSetting.tapZoneConfig;
  }

  void _update(TapZoneConfig config) {
    setState(() => _config = config);
    readSetting.saveTapZoneConfig(config);
  }

  void _setCellAction(int index) async {
    TapZoneAction? action = await Get.dialog<TapZoneAction>(
      SimpleDialog(
        title: Text('tapZoneAction'.tr),
        children: [
          for (TapZoneAction action in TapZoneAction.pickerOrder)
            SimpleDialogOption(
              onPressed: () => Get.back(result: action),
              child: Row(
                children: [
                  Icon(
                    _config.actions[index] == action ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: TapZoneGuideOverlay.actionColor(action),
                  ),
                  const SizedBox(width: 12),
                  Text(action.i18nKey.tr),
                ],
              ),
            ),
        ],
      ),
    );
    if (action == null || action == _config.actions[index]) {
      return;
    }
    List<TapZoneAction> actions = List.of(_config.actions);
    actions[index] = action;
    _update(_config.copyWith(actions: actions));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('tapZoneStyle'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          children: [
            _buildSectionTitle('tapZonePreset'.tr),
            const SizedBox(height: 8),
            _buildPresetSelector(context),
            const SizedBox(height: 24),
            _buildSectionTitle('tapZonePreview'.tr),
            const SizedBox(height: 8),
            _buildPreview(context),
            const SizedBox(height: 24),
            _buildSectionTitle('tapZoneRatio'.tr),
            _buildSlider(
              title: 'tapZoneLeftColumnRatio'.tr,
              subtitle: '${'tapZoneRightColumnRatio'.tr}: ${_config.rightColumnWidthRatio}%',
              value: _config.leftColumnWidthRatio,
              max: 98,
              onChanged: (v) => _update(
                _config.copyWith(leftColumnWidthRatio: v, middleColumnWidthRatio: _config.middleColumnWidthRatio.clamp(1, 99 - v)),
              ),
            ),
            _buildSlider(
              title: 'tapZoneMiddleColumnRatio'.tr,
              subtitle: '${'tapZoneRightColumnRatio'.tr}: ${_config.rightColumnWidthRatio}%',
              value: _config.middleColumnWidthRatio,
              max: 99 - _config.leftColumnWidthRatio,
              onChanged: (v) => _update(_config.copyWith(middleColumnWidthRatio: v)),
            ),
            _buildSlider(
              title: 'tapZoneTopRowRatio'.tr,
              subtitle: '${'tapZoneBottomRowRatio'.tr}: ${_config.bottomRowHeightRatio}%',
              value: _config.topRowHeightRatio,
              max: 98,
              onChanged: (v) => _update(
                _config.copyWith(topRowHeightRatio: v, middleRowHeightRatio: _config.middleRowHeightRatio.clamp(1, 99 - v)),
              ),
            ),
            _buildSlider(
              title: 'tapZoneMiddleRowRatio'.tr,
              subtitle: '${'tapZoneBottomRowRatio'.tr}: ${_config.bottomRowHeightRatio}%',
              value: _config.middleRowHeightRatio,
              max: 99 - _config.topRowHeightRatio,
              onChanged: (v) => _update(_config.copyWith(middleRowHeightRatio: v)),
            ),
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPresetSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPresetCard(context, preset: TapZoneConfig.classic(), label: 'tapZonePresetClassic'.tr),
        const SizedBox(width: 24),
        _buildPresetCard(context, preset: TapZoneConfig.vertical(), label: 'tapZonePresetVertical'.tr),
      ],
    );
  }

  Widget _buildPresetCard(BuildContext context, {required TapZoneConfig preset, required String label}) {
    bool selected = _config == preset;
    Color accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _update(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMiniGrid(context, preset),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check_circle, size: 16, color: accent),
                  const SizedBox(width: 4),
                ],
                Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGrid(BuildContext context, TapZoneConfig config) {
    return Container(
      width: 56,
      height: 84,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          for (int row = 0; row < 3; row++)
            Expanded(
              flex: [config.topRowHeightRatio, config.middleRowHeightRatio, config.bottomRowHeightRatio][row],
              child: Row(
                children: [
                  for (int col = 0; col < 3; col++)
                    Expanded(
                      flex: [config.leftColumnWidthRatio, config.middleColumnWidthRatio, config.rightColumnWidthRatio][col],
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: TapZoneGuideOverlay.actionColor(config.actions[row * 3 + col]).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Center(
      child: Container(
        width: 240,
        height: 360,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            for (int row = 0; row < 3; row++)
              Expanded(
                flex: [_config.topRowHeightRatio, _config.middleRowHeightRatio, _config.bottomRowHeightRatio][row],
                child: Row(
                  children: [
                    for (int col = 0; col < 3; col++)
                      Expanded(
                        flex: [_config.leftColumnWidthRatio, _config.middleColumnWidthRatio, _config.rightColumnWidthRatio][col],
                        child: GestureDetector(
                          onTap: () => _setCellAction(row * 3 + col),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: TapZoneGuideOverlay.actionColor(_config.actions[row * 3 + col]).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(2),
                            child: Text(
                              _config.actions[row * 3 + col].i18nKey.tr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String title,
    required String subtitle,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text('$value%'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: max.toDouble(),
          divisions: max > 1 ? max - 1 : null,
          label: '$value%',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
