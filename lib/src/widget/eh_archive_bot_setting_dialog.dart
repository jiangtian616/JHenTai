import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../setting/preference_setting.dart';
import '../utils/route_util.dart';

class EHArchiveBotSettingDialog extends StatefulWidget {
  final ArchiveBotType botType;
  final String? apiAddress;
  final String? apiKey;

  const EHArchiveBotSettingDialog({
    super.key,
    required this.botType,
    required this.apiAddress,
    required this.apiKey,
  });

  @override
  State<EHArchiveBotSettingDialog> createState() => _EHArchiveBotSettingDialogState();
}

class _EHArchiveBotSettingDialogState extends State<EHArchiveBotSettingDialog> {
  late ArchiveBotType _botType;
  late TextEditingController _apiAddressController;
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _botType = widget.botType;
    _apiAddressController = TextEditingController(text: widget.apiAddress ?? widget.botType.defaultServerAddress);
    _apiKeyController = TextEditingController(text: widget.apiKey ?? '');
  }

  @override
  void dispose() {
    _apiAddressController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text('apiSetting'.tr),
          const Expanded(child: SizedBox()),
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: () {
              launchUrlString(
                preferenceSetting.locale.value.languageCode == 'zh'
                    ? 'https://github.com/jiangtian616/JHenTai/wiki/%E5%BD%92%E6%A1%A3%E6%9C%BA%E5%99%A8%E4%BA%BA%E4%BD%BF%E7%94%A8%E6%96%B9%E6%B3%95'
                    : 'https://github.com/jiangtian616/JHenTai/wiki/Archive-Bot-Usage',
              );
            },
          ),
        ],
      ),
      contentPadding: const EdgeInsets.only(left: 8.0, top: 16.0, right: 0, bottom: 24.0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBotTypeSelector(),
          _buildApiAddressField(),
          _buildApiKeyField(),
        ],
      ),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(
          onPressed: _onConfirm,
          child: Text('OK'.tr),
        ),
      ],
    );
  }

  Widget _buildBotTypeSelector() {
    return ListTile(
      minLeadingWidth: 40,
      leading: Text('archiveBotProtocol'.tr, style: const TextStyle(fontSize: 14)),
      title: DropdownButton<ArchiveBotType>(
        isExpanded: true,
        value: _botType,
        items: const [
          DropdownMenuItem(
            value: ArchiveBotType.ehArBot,
            child: Text('EH-ArBot'),
          ),
          DropdownMenuItem(
            value: ArchiveBotType.archiveAtHome,
            child: Text('Archive-at-Home'),
          ),
        ],
        onChanged: (ArchiveBotType? selected) {
          if (selected == null) {
            return;
          }
          setStateSafely(() {
            _botType = selected;
            _apiAddressController.text = _botType.defaultServerAddress;
          });
        },
      ),
    );
  }

  Widget _buildApiAddressField() {
    return ListTile(
      minLeadingWidth: 40,
      leading: Text('apiAddress'.tr, style: const TextStyle(fontSize: 14)),
      title: TextField(
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
    );
  }

  Widget _buildApiKeyField() {
    return ListTile(
      minLeadingWidth: 40,
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
    );
  }

  void _onConfirm() {
    final String? address = _apiAddressController.text.isBlank! ? null : _apiAddressController.text;
    final String? key = _apiKeyController.text.isBlank! ? null : _apiKeyController.text;

    archiveBotSetting.saveConfig(
      type: _botType,
      address: address,
      key: key,
    );
    backRoute(result: true);
  }
}
