import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/network_setting.dart';

import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';
import '../../../utils/text_input_formatter.dart';
import '../../../utils/toast_util.dart';

class SettingNetworkPage extends StatelessWidget {
  final TextEditingController proxyAddressController = TextEditingController(text: networkSetting.proxyAddress.value);

  SettingNetworkPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('networkSetting'.tr)),
      body: Obx(() => ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              _buildEnableDomainFronting(),
              _buildProxyAddress(),
              _buildPageCacheMaxAge(),
              _buildCacheImageExpireDuration(),
              _buildTimeoutTile(
                context: context,
                title: 'connectTimeout'.tr,
                value: networkSetting.connectTimeout,
                onSave: networkSetting.saveConnectTimeout,
              ),
              _buildTimeoutTile(
                context: context,
                title: 'receiveTimeout'.tr,
                value: networkSetting.receiveTimeout,
                onSave: networkSetting.saveReceiveTimeout,
              ),
            ],
          ).withListTileTheme(context)),
    );
  }

  Widget _buildEnableDomainFronting() {
    return SwitchListTile(
      title: Text('enableDomainFronting'.tr),
      subtitle: Text('bypassSNIBlocking'.tr),
      value: networkSetting.enableDomainFronting.value,
      onChanged: networkSetting.saveEnableDomainFronting,
    );
  }

  Widget _buildProxyAddress() {
    return ListTile(
      title: Text('proxyAddress'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right).marginOnly(right: 4),
      onTap: () => toRoute(Routes.proxy),
    );
  }

  Widget _buildPageCacheMaxAge() {
    return ListTile(
      title: Text('pageCacheMaxAge'.tr),
      subtitle: Text('pageCacheMaxAgeHint'.tr),
      trailing: DropdownButton<Duration>(
        value: networkSetting.pageCacheMaxAge.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (Duration? newValue) => networkSetting.savePageCacheMaxAge(newValue!),
        items: [
          DropdownMenuItem(child: Text('1m'.tr), value: const Duration(minutes: 1)),
          DropdownMenuItem(child: Text('10m'.tr), value: const Duration(minutes: 10)),
          DropdownMenuItem(child: Text('1h'.tr), value: const Duration(hours: 1)),
          DropdownMenuItem(child: Text('1d'.tr), value: const Duration(days: 1)),
          DropdownMenuItem(child: Text('3d'.tr), value: const Duration(days: 3)),
        ],
      ),
    );
  }

  Widget _buildCacheImageExpireDuration() {
    return ListTile(
      title: Text('cacheImageExpireDuration'.tr),
      subtitle: Text('cacheImageExpireDurationHint'.tr),
      trailing: DropdownButton<Duration>(
        value: networkSetting.cacheImageExpireDuration.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (Duration? newValue) => networkSetting.saveCacheImageExpireDuration(newValue!),
        items: [
          DropdownMenuItem(child: Text('1d'.tr), value: const Duration(days: 1)),
          DropdownMenuItem(child: Text('2d'.tr), value: const Duration(days: 2)),
          DropdownMenuItem(child: Text('3d'.tr), value: const Duration(days: 3)),
          DropdownMenuItem(child: Text('5d'.tr), value: const Duration(days: 5)),
          DropdownMenuItem(child: Text('7d'.tr), value: const Duration(days: 7)),
          DropdownMenuItem(child: Text('14d'.tr), value: const Duration(days: 14)),
          DropdownMenuItem(child: Text('30d'.tr), value: const Duration(days: 30)),
        ],
      ),
    );
  }

  Widget _buildTimeoutTile({
    required BuildContext context,
    required String title,
    required RxInt value,
    required Future<void> Function(int) onSave,
  }) {
    return Obx(
      () => ListTile(
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${value.value} ms', style: UIConfig.settingPageListTileTrailingTextStyle(context)),
            const Icon(Icons.keyboard_arrow_right).marginOnly(left: 4),
          ],
        ),
        onTap: () async {
          int? result = await showDialog<int>(
            context: context,
            builder: (context) => _TimeoutSettingDialog(title: title, initialValue: value.value),
          );
          if (result != null) {
            await onSave(result);
            toast('saveSuccess'.tr);
          }
        },
      ),
    );
  }
}

class _TimeoutSettingDialog extends StatefulWidget {
  final String title;
  final int initialValue;

  const _TimeoutSettingDialog({Key? key, required this.title, required this.initialValue}) : super(key: key);

  @override
  State<_TimeoutSettingDialog> createState() => _TimeoutSettingDialogState();
}

class _TimeoutSettingDialogState extends State<_TimeoutSettingDialog> {
  static const int min = 0;
  static const int max = 60000;
  static const int step = 500;

  late int value;
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    value = widget.initialValue.clamp(min, max);
    controller = TextEditingController(text: value.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Text('ms', style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor)),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) ~/ step,
              label: '$value ms',
              onChanged: (double v) => _setValue(v.round()),
            ),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                IntRangeTextInputFormatter(minValue: min, maxValue: max),
              ],
              decoration: InputDecoration(
                isDense: true,
                suffixText: 'ms',
                errorText: _hasError() ? 'invalid'.tr : null,
              ),
              onSubmitted: (String text) => _confirm(),
              onChanged: (String text) {
                int? parsed = _parse();
                if (parsed != null) {
                  setState(() => value = parsed);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(onPressed: _confirm, child: Text('OK'.tr)),
      ],
    );
  }

  int? _parse() {
    int? parsed = int.tryParse(controller.text);
    if (parsed == null || parsed < min || parsed > max) {
      return null;
    }
    return parsed;
  }

  bool _hasError() => controller.text.isNotEmpty && _parse() == null;

  void _setValue(int newValue) {
    setState(() {
      value = newValue;
      controller.text = newValue.toString();
    });
  }

  void _confirm() {
    int? parsed = _parse();
    if (parsed == null) {
      return;
    }
    backRoute(result: parsed);
  }
}
