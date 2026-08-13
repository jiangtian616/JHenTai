import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/widget/eh_apple_settings_list_view.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';

import '../../../config/ui_config.dart';
import '../../../setting/performance_setting.dart';
import '../../../utils/text_input_formatter.dart';
import '../../../utils/toast_util.dart';

class SettingPerformancePage extends StatelessWidget {
  SettingPerformancePage({super.key});

  final TextEditingController maxGalleryNum4AnimationController =
      TextEditingController(
          text: performanceSetting.maxGalleryNum4Animation.value.toString());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('performanceSetting'.tr)),
      body: EHAppleSettingsListView(
        groups: [
          EHAppleSettingsGroup(
            children: [
              _buildMaxGalleryNum4Animation(context),
              _buildCoverDecodeOptimization(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverDecodeOptimization(BuildContext context) {
    return EHAppleSwitchListTile(
      title: Text('enableCoverDecodeOptimization'.tr),
      subtitle: Text('enableCoverDecodeOptimizationHint'.tr),
      value: performanceSetting.enableCoverDecodeOptimization.value,
      onChanged: (value) async {
        await performanceSetting.setEnableCoverDecodeOptimization(value);
        toast('saveSuccess'.tr);
      },
    );
  }

  Widget _buildMaxGalleryNum4Animation(BuildContext context) {
    return ListTile(
      title: Text('maxGalleryNum4Animation'.tr),
      subtitle: Text('maxGalleryNum4AnimationHint'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: EHAppleTextField(
              controller: maxGalleryNum4AnimationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  isDense: true, labelStyle: TextStyle(fontSize: 12)),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                IntRangeTextInputFormatter(minValue: 0),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EHAppleIconButton(
            onPressed: () {
              int? value =
                  int.tryParse(maxGalleryNum4AnimationController.value.text);
              if (value == null) {
                return;
              }
              performanceSetting.setMaxGalleryNum4Animation(value);
              toast('saveSuccess'.tr);
            },
            icon: Icon(Icons.check,
                color: UIConfig.resumePauseButtonColor(context)),
          ),
        ],
      ),
    );
  }
}
