import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/network_setting.dart';

import '../../../../utils/toast_util.dart';

class HostMappingPage extends StatelessWidget {
  const HostMappingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('hostMapping'.tr),
        actions: [
          IconButton(onPressed: () => toast('hostDataSource'.tr, isShort: false), icon: const Icon(Icons.help)),
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            ListTile(
              title: const Text('e-hentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.eHentaiIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveEHentaiIP(newValue!),
                items: _dropdownMenuItems('e-hentai.org'),
              ),
            ),
            ListTile(
              title: const Text('exhentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.exHentaiIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveEXHentaiIP(newValue!),
                items: _dropdownMenuItems('exhentai.org'),
              ),
            ),
            ListTile(
              title: const Text('upld.e-hentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.upldIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveUpldIP(newValue!),
                items: _dropdownMenuItems('upld.e-hentai.org'),
              ),
            ),
            ListTile(
              title: const Text('api.e-hentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.apiIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveApiIP(newValue!),
                items: _dropdownMenuItems('api.e-hentai.org'),
              ),
            ),
            ListTile(
              title: const Text('forums.e-hentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.forumsIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveForumsIP(newValue!),
                items: _dropdownMenuItems('forums.e-hentai.org'),
              ),
            ),
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  List<DropdownMenuItem<String>> _dropdownMenuItems(String host) {
    return NetworkSetting.host2IPs[host]!
        .map((ip) => DropdownMenuItem(
              child: Text(ip),
              value: ip,
            ))
        .toList();
  }
}
