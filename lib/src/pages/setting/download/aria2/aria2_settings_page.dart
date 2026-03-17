import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';

class Aria2SettingsPage extends StatefulWidget {
  const Aria2SettingsPage({Key? key}) : super(key: key);

  @override
  State<Aria2SettingsPage> createState() => _Aria2SettingsPageState();
}

class _Aria2SettingsPageState extends State<Aria2SettingsPage> {
  late final TextEditingController rpcUrlController;
  late final TextEditingController secretController;
  late final TextEditingController dirController;
  late final TextEditingController filenameTemplateController;

  int timeout = downloadSetting.aria2ConnectTimeout.value;
  bool defaultPushSelected = downloadSetting.aria2DefaultPushSelected.value;
  bool obscureSecret = true;

  @override
  void initState() {
    super.initState();
    rpcUrlController = TextEditingController(text: downloadSetting.aria2RpcUrl.value);
    secretController = TextEditingController(text: downloadSetting.aria2Secret.value);
    dirController = TextEditingController(text: downloadSetting.aria2DownloadDir.value);
    filenameTemplateController = TextEditingController(text: downloadSetting.aria2FilenameTemplate.value);
  }

  @override
  void dispose() {
    rpcUrlController.dispose();
    secretController.dispose();
    dirController.dispose();
    filenameTemplateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('aria2Settings'.tr),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('aria2SaveSettings'.tr),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: rpcUrlController,
            decoration: InputDecoration(
              labelText: 'aria2RpcUrl'.tr,
              hintText: 'aria2RpcUrlHint'.tr,
              border: const OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('aria2DefaultPushSelected'.tr),
            subtitle: Text('aria2DefaultPushSelectedHint'.tr),
            value: defaultPushSelected,
            onChanged: (value) => setState(() => defaultPushSelected = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: secretController,
            obscureText: obscureSecret,
            decoration: InputDecoration(
              labelText: 'aria2Secret'.tr,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscureSecret = !obscureSecret),
                icon: Icon(obscureSecret ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dirController,
            decoration: InputDecoration(
              labelText: 'aria2DownloadDir'.tr,
              hintText: 'aria2DownloadDirHint'.tr,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: filenameTemplateController,
            decoration: InputDecoration(
              labelText: 'aria2FilenameTemplate'.tr,
              hintText: 'aria2FilenameTemplateHint'.tr,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _showAria2FilenameTemplateHelp,
                icon: const Icon(Icons.help_outline),
                tooltip: 'aria2FilenameTemplateHelp'.tr,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: timeout,
            decoration: InputDecoration(
              labelText: 'aria2ConnectTimeout'.tr,
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 3000, child: Text('3000ms')),
              DropdownMenuItem(value: 5000, child: Text('5000ms')),
              DropdownMenuItem(value: 8000, child: Text('8000ms')),
              DropdownMenuItem(value: 12000, child: Text('12000ms')),
              DropdownMenuItem(value: 20000, child: Text('20000ms')),
            ],
            onChanged: (value) {
              if (value != null) {
                timeout = value;
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    await downloadSetting.saveAria2RpcUrl(rpcUrlController.text.trim());
    await downloadSetting.saveAria2Secret(secretController.text.trim());
    await downloadSetting.saveAria2DownloadDir(dirController.text.trim());
    await downloadSetting.saveAria2FilenameTemplate(
      filenameTemplateController.text.trim().isEmpty ? 'ArchiveV2 - {gid} - {title}.zip' : filenameTemplateController.text.trim(),
    );
    await downloadSetting.saveAria2DefaultPushSelected(defaultPushSelected);
    await downloadSetting.saveAria2ConnectTimeout(timeout);
    toast('saveSuccess'.tr);
    Get.back();
  }

  Future<void> _showAria2FilenameTemplateHelp() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('aria2FilenameTemplateHelp'.tr),
        content: Text(
          '${'aria2FilenameTemplateOptionGid'.tr}\n'
          '${'aria2FilenameTemplateOptionTitle'.tr}\n'
          '${'aria2FilenameTemplateOptionUploader'.tr}\n'
          '${'aria2FilenameTemplateOptionCategory'.tr}\n\n'
          '${'aria2FilenameTemplateExample'.tr}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ok'.tr),
          ),
        ],
      ),
    );
  }
}
