import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:telegram/telegram.dart';

import '../setting/archive_bot_setting.dart';
import '../utils/route_util.dart';

class EHArchiveBotSettingDialog extends StatefulWidget {
  final TextEditingController apiAddressController;
  final TextEditingController apiKeyController;
  final bool useProxy;

  const EHArchiveBotSettingDialog({super.key, required this.apiAddressController, required this.apiKeyController, required this.useProxy});

  @override
  State<EHArchiveBotSettingDialog> createState() => _EHArchiveBotSettingDialogState();
}

class _EHArchiveBotSettingDialogState extends State<EHArchiveBotSettingDialog> {
  late TextEditingController _apiAddressController;
  late TextEditingController _apiKeyController;
  late bool _useProxy;

  @override
  void initState() {
    _apiAddressController = widget.apiAddressController;
    _apiKeyController = widget.apiKeyController;
    _useProxy = widget.useProxy;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text('apiSetting'.tr),
          const Expanded(child: SizedBox()),
          IconButton(
            icon: const Icon(Icons.telegram),
            onPressed: () {
              Telegram.joinChannel(inviteLink: 'https://t.me/EH_ArBot');
            },
          )
        ],
      ),
      contentPadding: const EdgeInsets.only(left: 8.0, top: 16.0, right: 0, bottom: 24.0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            minLeadingWidth: 60,
            leading: Text('apiAddress'.tr, style: const TextStyle(fontSize: 14)),
            title: TextField(
              enabled: !_useProxy,
              controller: _apiAddressController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                constraints: const BoxConstraints(minWidth: 400),
                suffixIcon: _apiAddressController.text.isEmpty
                    ? null
                    : MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          child: const Icon(Icons.cancel),
                          onTap: () {
                            setStateSafely(_apiAddressController.clear);
                          },
                        ),
                      ),
              ),
              onChanged: (String value) {
                setStateSafely(() {});
              },
            ),
          ),
          ListTile(
            minLeadingWidth: 60,
            leading: Text('apiKey'.tr, style: const TextStyle(fontSize: 14)),
            title: TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                constraints: const BoxConstraints(minWidth: 400),
                suffixIcon: _apiKeyController.text.isEmpty
                    ? null
                    : MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          child: const Icon(Icons.cancel),
                          onTap: () {
                            setStateSafely(_apiKeyController.clear);
                          },
                        ),
                      ),
              ),
              onChanged: (String value) {
                setStateSafely(() {});
              },
            ),
          ),
          SwitchListTile(
            title: Text('useProxyServer'.tr, style: const TextStyle(fontSize: 14)),
            value: _useProxy,
            onChanged: (bool value) async {
              setStateSafely(() {
                _useProxy = value;
              });
            },
          )
        ],
      ),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            setStateSafely(() {
              archiveBotSetting.saveAllConfig(
                _apiAddressController.text.isBlank! ? null : _apiAddressController.text,
                _apiKeyController.text.isBlank! ? null : _apiKeyController.text,
                _useProxy,
              );
              backRoute(result: true);
            });
          },
          child: Text('OK'.tr),
        ),
      ],
    );
  }
}
