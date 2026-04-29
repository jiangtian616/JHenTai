import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/service/aria2_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:throttling/throttling.dart';

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

  bool enableAria2Push = downloadSetting.enableAria2Push.value;
  int timeout = downloadSetting.aria2ConnectTimeout.value;
  bool defaultPushSelected = downloadSetting.aria2DefaultPushSelected.value;
  bool obscureSecret = true;
  LoadingState testConnectionState = LoadingState.idle;
  late final Debouncing saveDebouncing;

  @override
  void initState() {
    super.initState();
    rpcUrlController = TextEditingController(text: downloadSetting.aria2RpcUrl.value);
    secretController = TextEditingController(text: downloadSetting.aria2Secret.value);
    dirController = TextEditingController(text: downloadSetting.aria2DownloadDir.value);
    filenameTemplateController = TextEditingController(text: downloadSetting.aria2FilenameTemplate.value);
    saveDebouncing = Debouncing(duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    rpcUrlController.dispose();
    secretController.dispose();
    dirController.dispose();
    filenameTemplateController.dispose();
    saveDebouncing.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('aria2Settings'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('enableAria2Push'.tr),
            subtitle: Text('enableAria2PushHint'.tr),
            value: enableAria2Push,
            onChanged: (value) async {
              setState(() => enableAria2Push = value);
              await downloadSetting.saveEnableAria2Push(value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('aria2DefaultPushSelected'.tr),
            subtitle: Text('aria2DefaultPushSelectedHint'.tr),
            value: enableAria2Push && defaultPushSelected,
            onChanged: !enableAria2Push
                ? null
                : (value) async {
                    setState(() => defaultPushSelected = value);
                    await downloadSetting.saveAria2DefaultPushSelected(value);
                  },
          ),
          TextField(
            controller: rpcUrlController,
            onChanged: (value) => saveDebouncing.debounce(() => downloadSetting.saveAria2RpcUrl(value.trim())),
            decoration: InputDecoration(
              labelText: 'aria2RpcUrl'.tr,
              hintText: 'aria2RpcUrlHint'.tr,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: secretController,
            obscureText: obscureSecret,
            onChanged: (value) => saveDebouncing.debounce(() => downloadSetting.saveAria2Secret(value.trim())),
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
            onChanged: (value) => saveDebouncing.debounce(() => downloadSetting.saveAria2DownloadDir(value.trim())),
            decoration: InputDecoration(
              labelText: 'aria2DownloadDir'.tr,
              hintText: 'aria2DownloadDirHint'.tr,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: filenameTemplateController,
            onChanged: (value) => saveDebouncing.debounce(() => downloadSetting.saveAria2FilenameTemplate(value.trim())),
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
                setState(() => timeout = value);
                downloadSetting.saveAria2ConnectTimeout(value);
              }
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('testConnection'.tr),
            trailing: _buildTestConnectionTrailing(),
            onTap: _testConnection,
          ),
        ],
      ).withListTileTheme(context),
    );
  }

  Future<void> _testConnection() async {
    if (testConnectionState == LoadingState.loading) {
      return;
    }

    setState(() => testConnectionState = LoadingState.loading);
    await downloadSetting.saveAria2RpcUrl(rpcUrlController.text.trim());
    await downloadSetting.saveAria2Secret(secretController.text.trim());
    await downloadSetting.saveAria2ConnectTimeout(timeout);

    try {
      await aria2Service.testConnection();
      if (!mounted) {
        return;
      }
      setState(() => testConnectionState = LoadingState.success);
      toast('aria2ConnectionSucceeded'.tr, isCenter: false);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => testConnectionState = LoadingState.error);
      snack('aria2ConnectionFailed'.tr, e.message ?? e.toString(), isShort: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => testConnectionState = LoadingState.error);
      snack('aria2ConnectionFailed'.tr, e.toString(), isShort: true);
    }
  }

  Widget _buildTestConnectionTrailing() {
    if (testConnectionState == LoadingState.loading) {
      return const CupertinoActivityIndicator();
    }
    if (testConnectionState == LoadingState.success) {
      return const Icon(Icons.check_circle_outline);
    }
    if (testConnectionState == LoadingState.error) {
      return const Icon(Icons.error_outline);
    }
    return const Icon(Icons.keyboard_arrow_right);
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
